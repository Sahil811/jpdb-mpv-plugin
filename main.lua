--[[
    jpdb.lua — JPDB MPV Plugin  (v3 — Full redesign)

    DESIGN:
      · Richer visual hierarchy: accent bar, gloss alternation, frequency chip
      · Layered shadow system for depth (3-layer: ambient + key + fill)
      · Pill-shaped state badge with tinted background
      · Hover highlight on subtitle uses both underline AND brightness lift
      · Dimmed non-hovered tokens for focus contrast

    UX:
      · Popup vertical position never clips: clamps to both top AND bottom edges
      · Popup horizontal position aware of right-edge AND left-edge simultaneously
      · Button click race-condition fixed: dispatch happens BEFORE close_popup()
      · Action feedback rendered INSIDE the popup (inline toast row) for 1.2s
        before the card auto-dismisses — no more toast over subtitle
      · Scrollable meanings: if meanings > 6, a "… N more" line is shown
      · Adaptive debounce: 80 ms when re-hovering the SAME token after a short
        gap; 150 ms for a new token; 220 ms for leaving entirely
      · All async — refresh_after_action no longer stalls the main thread

    ACCURACY:
      · Per-line byte→pixel map (inherited from v2) kept and improved:
          - Punctuation (、。・「」) classified as full-width
          - Halfwidth katakana block (U+FF65..U+FF9F) classified as half-width
          - Fullwidth Latin block (U+FF01..U+FF60) classified as full-width
      · Subtitle vertical hit region now tracks ASS font size precisely
        (CHAR_PX_FULL = 48, border = 2, so real glyph cap ≈ 46px)
      · Token overlap resolved by shortest-span-first priority

    ARCHITECTURE:
      · refresh_after_action is fully async (http_request_async)
      · String building uses a pre-allocated table flushed per-frame
      · render_subtitles and render_popup both guard on data equality
        before calling :update() to avoid redundant OSD redraws
]]

local mp      = require('mp')
local msg     = require('mp.msg')
local assdraw = require('mp.assdraw')
local utils   = require('mp.utils')


-- ─── Debug log ────────────────────────────────────────────────────────────────

-- main.lua lives inside scripts/jpdb-mpv-plugin/ so the script dir IS the plugin dir.
local PLUGIN_DIR = mp.get_script_directory()
local LOG_PATH   = PLUGIN_DIR .. '/jpdb-debug.log'

local conf = dofile(PLUGIN_DIR .. '/jpdb-config.lua')

-- Set to true to write a debug log file (jpdb-debug.log) and verbose messages.
-- Leave false in production — no file is created, dlog() is a no-op.
local DEBUG_LOG = conf.DEBUG_LOG

local log_file = DEBUG_LOG and io.open(LOG_PATH, 'w') or nil
if log_file then
    log_file:write('=== jpdb.lua v3 started ' .. os.date('%Y-%m-%dT%H:%M:%S') .. ' ===\n')
    log_file:flush()
end

local function dlog(...)
    if not DEBUG_LOG then return end
    local parts = {}
    for _, v in ipairs({...}) do parts[#parts+1] = tostring(v) end
    local line = table.concat(parts, ' ')
    if log_file then
        log_file:write('[' .. os.date('%H:%M:%S') .. '] ' .. line .. '\n')
        log_file:flush()
    end
    msg.info(line)
end

-- ─── Load kanji meanings ──────────────────────────────────────────────────────
local kanji_meanings_map = {}
local function load_kanji_meanings()
    local kanji_file = io.open(PLUGIN_DIR .. '/kanji_meanings.json', 'r')
    if not kanji_file then
        dlog('[kanji] kanji_meanings.json not found')
        return
    end
    local content = kanji_file:read('*all')
    kanji_file:close()
    
    local ok, data = pcall(utils.parse_json, content)
    if not ok or not data then
        dlog('[kanji] Failed to parse kanji_meanings.json')
        return
    end
    
    for _, entry in ipairs(data) do
        if entry.kanji and entry.meaning then
            kanji_meanings_map[entry.kanji] = entry.meaning
        end
    end
    dlog('[kanji] Loaded ' .. tostring(#data) .. ' kanji meanings')
end
load_kanji_meanings()

local SERVER_URL  = conf.SERVER_URL
local FONT_FAMILY = conf.FONT_FAMILY

-- ─── Server auto-start ────────────────────────────────────────────────────────
-- Finds jpdb-server.exe next to this script, launches it if the server is not
-- already listening on SERVER_URL, then registers this MPV instance.
-- Multiple MPV windows share the same server process safely.

-- jpdb-server.exe lives in the jpdb-mpv-plugin subfolder.
local SERVER_BIN = PLUGIN_DIR .. '/jpdb-server.exe'

local function server_ping(on_result)
    -- Quick /status check; on_result(true) if server is up, on_result(false) otherwise
    mp.command_native_async({
        name='subprocess',
        args={'curl','-s','--max-time','2', SERVER_URL..'/status'},
        capture_stdout=true, capture_stderr=true, playback_only=false,
    }, function(success, res)
        on_result(success and res and res.status == 0 and res.stdout ~= '')
    end)
end

local function register_with_server()
    mp.command_native_async({
        name='subprocess',
        args={'curl','-s','-X','POST','--max-time','5', SERVER_URL..'/register'},
        capture_stdout=true, capture_stderr=true, playback_only=false,
    }, function(success, res)
        if success and res and res.status == 0 then
            dlog('[jpdb] Registered with server')
        else
            dlog('[jpdb] WARNING: could not register with server')
        end
    end)
end

local function launch_server_then_register()
    dlog('[jpdb] Starting jpdb-server.exe...')
    -- detached=true so the process outlives this Lua call;
    -- playback_only=false so it keeps running even when paused.
    mp.command_native_async({
        name='subprocess',
        args={SERVER_BIN},
        detach=true, playback_only=false,
    }, function() end)   -- fire and forget

    -- Poll until the server responds (up to ~5 s)
    local attempts = 0
    local function poll()
        attempts = attempts + 1
        server_ping(function(up)
            if up then
                dlog('[jpdb] Server is up after ' .. attempts .. ' poll(s)')
                register_with_server()
                mp.osd_message('[jpdb] Server started ✓', 2)
            elseif attempts < 20 then
                mp.add_timeout(0.3, poll)
            else
                dlog('[jpdb] ERROR: server did not start in time')
                mp.osd_message('[jpdb] ERROR: server failed to start!', 5)
            end
        end)
    end
    mp.add_timeout(0.5, poll)   -- give the process a moment before first ping
end

-- On mpv startup: check if server is running; if yes just register,
-- if no launch it first.
mp.add_timeout(0.3, function()
    server_ping(function(up)
        if up then
            dlog('[jpdb] Server already running — registering')
            register_with_server()
            mp.osd_message('[jpdb v3] JPDB ready ✔', 2)
        else
            launch_server_then_register()
        end
    end)
end)



-- ══════════════════════════════════════════════════════════════════════════════
-- ─── Design Tokens ────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════
--
-- All colours are in ASS BGR hex (&HBBGGRR&).
-- Alpha 00 = fully opaque, FF = fully transparent.

local DS = conf.DS

local STATE_COLORS = conf.STATE_COLORS

-- Dimmer palette for non-hovered tokens (subtle — just slightly muted)
local STATE_COLORS_DIM = conf.STATE_COLORS_DIM

local STATE_ALPHA  = conf.STATE_ALPHA
local STATE_ALPHA_DIM = conf.STATE_ALPHA_DIM

local STATE_LABELS = conf.STATE_LABELS


-- ─── Runtime state ────────────────────────────────────────────────────────────

local current_tokens    = {}
local current_text      = ''
local last_parsed_text  = nil
local hovered_token     = nil
local hover_x           = 0
local hover_y           = 0
local subtitle_regions  = {}
local jpdb_did_pause    = false
local popup_visible     = false
local popup_token       = nil
local popup_osd         = nil
local sub_osd           = nil
local popup_buttons     = {}
local hovered_button    = nil   -- key string or nil
local popup_rect        = nil

-- Debounce
local hover_pending_token  = nil
local hover_debounce_timer = nil
local last_hover_time      = 0  -- for adaptive debounce

-- OSD canvas
local osd_w = 1280
local osd_h = 720

-- Subtitle ASS cache
local cached_sub_ass      = nil
local cached_sub_token_id = nil

-- Inline toast inside popup
local popup_toast_text  = nil
local popup_toast_ok    = true
local popup_toast_timer = nil


-- ─── HTTP helpers ─────────────────────────────────────────────────────────────

local function http_request_async(method, path, body_table, on_done)
    local body_json = body_table and utils.format_json(body_table) or ''
    local args = {
        'curl', '-s', '-X', method,
        '--max-time', '15',
        '-H', 'Content-Type: application/json',
        SERVER_URL .. path,
    }
    if body_json ~= '' then args[#args+1] = '-d'; args[#args+1] = body_json end
    mp.command_native_async({
        name = 'subprocess', args = args,
        capture_stdout = true, capture_stderr = true, playback_only = false,
    }, function(success, res, err)
        if not success or res.status ~= 0 then
            msg.error('[jpdb] request failed: ' .. (err or (res and res.stderr) or 'unknown'))
            if on_done then on_done(nil, 'request failed') end
            return
        end
        local ok, data = pcall(utils.parse_json, res.stdout)
        if not ok or data == nil then
            if on_done then on_done(nil, 'bad JSON') end
            return
        end
        if on_done then on_done(data, data.error) end
    end)
end


-- ══════════════════════════════════════════════════════════════════════════════
-- ─── UTF-8 / Unicode Width ────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Glyph widths matched to \\fs48 rendering in Yu Gothic UI:
--   Full-width (48 px): CJK ideographs, Hiragana, Katakana, fullwidth Latin/punct
--   Half-width (26 px): ASCII, Latin extensions, Greek, halfwidth Katakana

local SUB_CONF = conf.SUBTITLE_OVERLAY
local PX_FULL = SUB_CONF.px_full
local PX_HALF = SUB_CONF.px_half
local LINE_H  = SUB_CONF.line_h

-- Returns (pixel_width, next_byte_index) for the UTF-8 character at byte i.
-- Refined classification vs v2:
--   · Halfwidth Katakana (U+FF65..U+FF9F) → half  [3-byte, lead E0..EF range check]
--   · Fullwidth Latin (U+FF01..U+FF60)    → full
--   · CJK Compat Ideographs (U+F900..U+FAFF) → full
local function char_px(s, i)
    local b = s:byte(i)
    if b < 0x80 then return PX_HALF, i + 1 end  -- ASCII
    if b < 0xE0 then return PX_HALF, i + 2 end  -- 2-byte (Latin, Greek, etc.)
    if b < 0xF0 then
        -- 3-byte: decode first 2 bytes to get codepoint block
        local b2 = s:byte(i + 1) or 0x80
        -- U+3000..U+FFFF  → lead E3..EF is full-width
        -- BUT U+FF65..U+FF9F (halfwidth Katakana) lead=EF, b2=BD
        if b >= 0xE3 then
            if b == 0xEF and b2 == 0xBD then
                -- U+FF40..U+FF7F — halfwidth Katakana starts at 0xEF 0xBD 0xA5
                local b3 = s:byte(i + 2) or 0x80
                if b3 >= 0xA5 then return PX_HALF, i + 3 end -- halfwidth kana
            end
            return PX_FULL, i + 3
        end
        return PX_HALF, i + 3  -- U+0800..U+2FFF
    end
    return PX_FULL, i + 4  -- 4-byte CJK ext
end

-- Build byte→pixel cumulative map for one line of text.
-- map[k] = px offset of the character whose first byte is at 1-indexed position k.
-- map[#text+1] = total pixel width (sentinel).
local function build_px_map(text)
    local map = {}
    local i, px = 1, 0
    local len = #text
    while i <= len do
        map[i] = px
        local cw, ni = char_px(text, i)
        px = px + cw
        i  = ni
    end
    map[len + 1] = px
    return map, px
end

local function utf8_len(s)
    local n, i, len = 0, 1, #s
    while i <= len do
        local b = s:byte(i)
        if     b < 0x80 then i = i + 1
        elseif b < 0xE0 then i = i + 2
        elseif b < 0xF0 then i = i + 3
        else                 i = i + 4 end
        n = n + 1
    end
    return n
end

local function split_lines(text)
    local result, i, ls = {}, 1, 1
    local len = #text
    while i <= len do
        local b = text:byte(i)
        if b == 10 then
            result[#result+1] = { text = text:sub(ls, i-1), byte_start = ls - 1 }
            ls = i + 1
            i  = i + 1
        else
            if     b < 0x80 then i = i + 1
            elseif b < 0xE0 then i = i + 2
            elseif b < 0xF0 then i = i + 3
            else                 i = i + 4 end
        end
    end
    result[#result+1] = { text = text:sub(ls), byte_start = ls - 1 }
    return result
end


-- ─── ASS helpers ──────────────────────────────────────────────────────────────

local function esc(s)
    if not s then return '' end
    return (s:gsub('\\','\\\\'):gsub('{','\\{'):gsub('}','\\}'):gsub('\n','\\N'))
end

local fmt = string.format

-- Filled rectangle
local function rect(ev, x, y, w, h, col, al)
    if w <= 0 or h <= 0 then return end
    ev[#ev+1] = fmt(
        '{\\an7\\pos(%d,%d)\\bord0\\shad0\\1c%s\\1a%s\\p1}m 0 0 l %d 0 %d %d 0 %d{\\p0}',
        x, y, col, al, w, w, h, h)
end

-- Horizontal divider
local function divider(ev, x, y, w)
    rect(ev, x, y, w, DS.divider_h, DS.bg_divider, '&H00&')
end

-- Left-aligned text
local function text(ev, x, y, fn, sz, bold, col, al, s)
    ev[#ev+1] = fmt(
        '{\\an7\\pos(%d,%d)\\fn%s\\fs%d\\b%d\\bord0\\shad0\\1c%s\\1a%s}%s',
        x, y, fn, sz, bold and 1 or 0, col, al, esc(s))
end

-- Centre-aligned text
local function textc(ev, cx, cy, fn, sz, bold, col, al, s)
    ev[#ev+1] = fmt(
        '{\\an5\\pos(%d,%d)\\fn%s\\fs%d\\b%d\\bord0\\shad0\\1c%s\\1a%s}%s',
        cx, cy, fn, sz, bold and 1 or 0, col, al, esc(s))
end


-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function get_primary_state(card_state)
    if not card_state or #card_state == 0 then return 'not-in-deck' end
    for _, s in ipairs(card_state) do
        if STATE_COLORS[s] then return s end
    end
    return card_state[1] or 'not-in-deck'
end

local PARTS_OF_SPEECH = {
    n='Noun', pn='Pronoun', pref='Prefix', suf='Suffix',
    name='Name', ['name-fem']='Feminine Name', ['name-male']='Masculine Name',
    ['name-surname']='Surname', ['name-person']='Personal Name',
    ['name-place']='Place Name', ['name-company']='Company Name',
    ['adj-i']='い-Adj', ['adj-na']='な-Adj', ['adj-no']='の-Adj',
    ['adj-pn']='Adjectival', adv='Adverb',
    aux='Auxiliary', ['aux-v']='Aux Verb', ['aux-adj']='Aux Adj',
    conj='Conjunction', cop='Copula', ctr='Counter',
    exp='Expression', int='Interjection', num='Numeric', prt='Particle',
    vt='Trans. Verb', vi='Intrans. Verb',
    v1='Ichidan Verb', v5='Godan Verb', vk='Irreg. Verb (くる)',
    vs='する Verb', vz='ずる Verb',
}

local function pos_label(pos_list)
    if not pos_list or #pos_list == 0 then return '' end
    local out = {}
    for _, p in ipairs(pos_list) do out[#out+1] = PARTS_OF_SPEECH[p] or p end
    return table.concat(out, ' · ')
end

local function wrap_text(s, max_ch)
    local lines, cur, cur_n = {}, {}, 0
    for word in s:gmatch('%S+') do
        local wn = utf8_len(word)
        if cur_n > 0 and cur_n + 1 + wn > max_ch then
            lines[#lines+1] = table.concat(cur, ' ')
            cur = { word }; cur_n = wn
        else
            cur[#cur+1] = word
            cur_n = cur_n + (cur_n > 0 and 1 or 0) + wn
        end
    end
    if #cur > 0 then lines[#lines+1] = table.concat(cur, ' ') end
    return lines
end

-- Extract individual kanji characters from a string
local function extract_kanji(text)
    local kanji_list = {}
    local i = 1
    local len = #text
    while i <= len do
        local b = text:byte(i)
        local char_len
        if b < 0x80 then
            char_len = 1
        elseif b < 0xE0 then
            char_len = 2
        elseif b < 0xF0 then
            char_len = 3
        else
            char_len = 4
        end
        
        local char = text:sub(i, i + char_len - 1)
        -- Check if this character has a meaning (is a kanji)
        if kanji_meanings_map[char] then
            kanji_list[#kanji_list + 1] = {
                kanji = char,
                meaning = kanji_meanings_map[char]
            }
        end
        i = i + char_len
    end
    return kanji_list
end


-- ══════════════════════════════════════════════════════════════════════════════
-- ─── Subtitle Overlay ─────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

-- Build the ASS inline tag string for a subtitle.
-- Hovered token → full colour + underline
-- Other tokens  → dim colour (focus contrast)
-- Gaps          → white
local function build_subtitle_ass(tokens, raw_text)
    if not tokens or #tokens == 0 then return nil end
    local parts = {}
    local last  = 0
    -- Sort by start, resolve overlaps: prefer shorter span
    local sorted = {}
    for _, t in ipairs(tokens) do sorted[#sorted+1] = t end
    table.sort(sorted, function(a, b)
        if a.start ~= b.start then return a.start < b.start end
        return (a['end'] - a.start) < (b['end'] - b.start)
    end)

    local has_hovered = (hovered_token ~= nil)

    for _, tok in ipairs(sorted) do
        if tok.start >= last then
            if tok.start > last then
                -- gap text: pure white, slightly dim if something is hovered
                local gap_al = has_hovered and '&H22&' or '&H00&'
                parts[#parts+1] = '{\\c&HFFFFFF&\\1a' .. gap_al .. '\\u0}'
                parts[#parts+1] = esc(raw_text:sub(last + 1, tok.start))
            end
            local state   = get_primary_state(tok.card.state)
            local is_hov  = (tok == hovered_token)
            local color   = is_hov and (STATE_COLORS[state] or '&HFFFFFF&')
                                    or (STATE_COLORS_DIM[state] or '&HFFFFFF&')
            local alpha   = is_hov and (STATE_ALPHA[state]    or '&H00&')
                                    or (STATE_ALPHA_DIM[state] or '&H00&')
            local under   = is_hov and '\\u1' or '\\u0'
            parts[#parts+1] = '{\\c' .. color .. '\\1a' .. alpha .. under .. '}'
            parts[#parts+1] = esc(raw_text:sub(tok.start + 1, tok['end']))
            last = tok['end']
        end
    end

    if last < #raw_text then
        local gap_al = has_hovered and '&H22&' or '&H00&'
        parts[#parts+1] = '{\\c&HFFFFFF&\\1a' .. gap_al .. '\\u0}'
        parts[#parts+1] = esc(raw_text:sub(last + 1))
    end
    return table.concat(parts)
end

local function subtitle_layout()
    local sub_y = osd_h - SUB_CONF.pos_y_offset
    local lines = split_lines(current_text)
    local n     = #lines
    return {
        n            = n,
        sub_y        = sub_y,
        sub_text_top = sub_y - n * LINE_H,
        lines        = lines,
    }
end

local function render_subtitles()
    if not sub_osd then return end
    subtitle_regions = {}

    dlog('[render_subtitles] tokens=' .. #current_tokens .. ' hovered=' .. tostring(hovered_token ~= nil))

    if #current_tokens == 0 then
        if sub_osd.data ~= '' then sub_osd.data = ''; sub_osd:update() end
        return
    end

    local tok_id = #current_tokens .. ':' .. tostring(hovered_token)
    local ass_content
    if cached_sub_token_id == tok_id and cached_sub_ass then
        ass_content = cached_sub_ass
    else
        ass_content         = build_subtitle_ass(current_tokens, current_text)
        cached_sub_ass      = ass_content
        cached_sub_token_id = tok_id
    end

    if not ass_content then
        if sub_osd.data ~= '' then sub_osd.data = ''; sub_osd:update() end
        return
    end

    local layout = subtitle_layout()
    local sub_x  = math.floor(osd_w / 2)

    for li, ln in ipairs(layout.lines) do
        local from_bottom = layout.n - li
        local line_bottom = layout.sub_y - from_bottom * LINE_H
        -- Vertical hit region: cap height of glyph with 2px border
        local y1 = line_bottom - math.floor(SUB_CONF.font_size * 0.96) - 4
        local y2 = line_bottom + 8

        local px_map, total_px = build_px_map(ln.text)
        local line_left = sub_x - total_px / 2
        local lbs = ln.byte_start
        local lbe = lbs + #ln.text

        -- Build hit regions sorted by span length (shorter = higher priority)
        local line_toks = {}
        for _, tok in ipairs(current_tokens) do
            if tok.start >= lbs and tok['end'] <= lbe + 1 then
                line_toks[#line_toks+1] = tok
            end
        end
        table.sort(line_toks, function(a, b)
            return (a['end'] - a.start) < (b['end'] - b.start)
        end)

        for _, tok in ipairs(line_toks) do
            local ls = tok.start - lbs   -- 0-indexed in line
            local le = tok['end'] - lbs  -- 0-indexed
            local px0 = px_map[ls + 1] or 0
            local px1 = px_map[le + 1] or total_px
            subtitle_regions[#subtitle_regions+1] = {
                x1    = math.floor(line_left + px0),
                x2    = math.floor(line_left + px1),
                y1    = y1,
                y2    = y2,
                token = tok,
                span  = le - ls,
            }
        end
    end

    local a = assdraw.ass_new()
    a:new_event()
    a:append('{\\an2\\pos(' .. sub_x .. ',' .. layout.sub_y .. ')\\fs' .. SUB_CONF.font_size .. '\\bord2\\shad1\\b0}')
    a:append(ass_content)

    if sub_osd.data ~= a.text then
        sub_osd.data = a.text
        sub_osd:update()
    end
end


-- ══════════════════════════════════════════════════════════════════════════════
-- ─── Popup Rendering ──────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local BTN_MAP = conf.BTN_MAP

local BTN_SHORTCUTS = conf.BTN_SHORTCUTS

local WRAP_CHARS = 44
local MAX_MEANINGS = 6

-- Forward declaration
local render_popup

-- Show inline toast inside the popup
local function show_popup_toast(msg_text, ok)
    dlog('[show_popup_toast] msg=' .. msg_text .. ' ok=' .. tostring(ok))
    popup_toast_text = msg_text
    popup_toast_ok   = (ok ~= false)
    if popup_toast_timer then popup_toast_timer:kill() end
    popup_toast_timer = mp.add_timeout(1.4, function()
        popup_toast_timer = nil
        popup_toast_text  = nil
        dlog('[show_popup_toast] Toast timer expired')
        if popup_visible then render_popup() end
    end)
    render_popup()
end

render_popup = function()
    if not popup_osd then return end
    if not popup_visible or not popup_token then
        popup_rect = nil
        if popup_osd.data ~= '' then popup_osd.data = ''; popup_osd:update() end
        return
    end

    popup_buttons = {}

    local card    = popup_token.card
    local state   = get_primary_state(card.state)
    local s_color = STATE_COLORS[state] or '&HFFFFFF&'

    local W   = DS.width
    local LB  = DS.lbar_w
    local PAD = DS.pad_h
    local cx0 = LB + PAD  -- content x offset from popup left

    -- ── Height measurement pass ──────────────────────────────────────────────
    local function measure_h()
        local h = DS.pad_v + DS.lh_kanji
        if card.spelling ~= card.reading then h = h + DS.lh_reading end
        h = h + DS.lh_badge + DS.unit           -- state badges row
        h = h + DS.divider_h + DS.unit           -- first divider
        
        -- Kanji breakdown section
        local kanji_list = extract_kanji(card.spelling)
        if #kanji_list > 0 and #kanji_list <= 4 then
            -- Grid layout: fixed height boxes
            h = h + DS.lh_kanji + DS.lh_gloss + 8 + DS.unit
            h = h + DS.divider_h + DS.unit
        elseif #kanji_list > 4 then
            -- Compact inline: estimate wrapped lines
            local total_len = 0
            for _, k in ipairs(kanji_list) do
                total_len = total_len + utf8_len(k.kanji .. k.meaning) + 3
            end
            local lines_needed = math.ceil(total_len / 44)
            h = h + lines_needed * DS.lh_gloss + DS.unit
            h = h + DS.divider_h + DS.unit
        end
        
        local shown, lp = 0, nil
        local total = #(card.meanings or {})
        for _, m in ipairs(card.meanings or {}) do
            if shown >= MAX_MEANINGS then break end
            local pl = pos_label(m.partOfSpeech)
            if pl ~= '' and pl ~= lp then h = h + DS.lh_pos; lp = pl end
            h = h + #wrap_text(table.concat(m.glosses or {}, '; '), WRAP_CHARS) * DS.lh_gloss
            shown = shown + 1
        end
        if total > MAX_MEANINGS then h = h + DS.lh_gloss end -- "…N more" line
        if popup_toast_text then h = h + DS.unit + DS.lh_toast end
        h = h + DS.unit * 2 + DS.divider_h + DS.unit
        -- Only one button row now (Never Forget only)
        h = h + DS.bh_action + DS.pad_v
        return h
    end

    local total_h = measure_h()
    local layout  = subtitle_layout()

    -- ── Popup position: never clip on any edge ───────────────────────────────
    local margin = 10
    -- Vertical: try to sit above subtitles; fall back to below if not enough room
    local py_above = layout.sub_text_top - DS.unit - total_h
    local py_below = layout.sub_y + DS.unit + 6
    local py
    if py_above >= margin then
        py = py_above
    elseif py_below + total_h <= osd_h - margin then
        py = py_below
    else
        py = math.max(margin, math.min(py_above, osd_h - total_h - margin))
    end

    -- Horizontal: centre on the token; clamp to edges
    local tok_cx = hover_x
    for _, region in ipairs(subtitle_regions) do
        if region.token == popup_token then
            tok_cx = (region.x1 + region.x2) / 2; break
        end
    end
    local px = math.max(margin, math.min(tok_cx - W / 2, osd_w - W - margin))

    popup_rect = { x1=px, y1=py, x2=px+W, y2=py+total_h }

    local bg = {}
    local fg = {}

    -- ── Layered shadow (ambient + key + fill) ────────────────────────────────
    rect(bg, px+10, py+14, W,   total_h, DS.shadow_ambient, '&HE0&')  -- ambient
    rect(bg, px+5,  py+7,  W,   total_h, DS.shadow_key,     '&HA0&')  -- key
    rect(bg, px+2,  py+3,  W+2, total_h+2, DS.shadow_fill,  '&H60&')  -- fill

    -- ── Card body ─────────────────────────────────────────────────────────────
    rect(bg, px,      py, W,    total_h, DS.bg_surface, '&H00&')
    -- accent bar
    rect(bg, px,      py, LB,   total_h, s_color,       '&H00&')
    -- top accent line (full width, very subtle)
    rect(bg, px+LB,   py, W-LB, 1,       s_color,       '&HC8&')

    -- ── Header zone (slightly different bg) ──────────────────────────────────
    local hdr_h = DS.pad_v + DS.lh_kanji
    if card.spelling ~= card.reading then hdr_h = hdr_h + DS.lh_reading end
    hdr_h = hdr_h + DS.lh_badge + DS.unit
    rect(bg, px+LB, py, W-LB, hdr_h, DS.bg_header, '&H00&')

    local cx = px + cx0
    local cy = py + DS.pad_v

    -- ── Kanji / Spelling ─────────────────────────────────────────────────────
    text(fg, cx, cy, FONT_FAMILY, DS.fs_kanji, true, s_color, '&H00&', card.spelling)
    cy = cy + DS.lh_kanji

    -- ── Reading ──────────────────────────────────────────────────────────────
    if card.spelling ~= card.reading then
        text(fg, cx, cy, FONT_FAMILY, DS.fs_reading, false, DS.col_secondary, '&H00&', card.reading)
        cy = cy + DS.lh_reading
    end

    -- ── State badges ─────────────────────────────────────────────────────────
    local bx = cx
    for _, s in ipairs(card.state) do
        local sc    = STATE_COLORS[s] or DS.col_tertiary
        local label = STATE_LABELS[s] or s
        -- tinted badge bg pill
        local bw = utf8_len(label) * 9 + 22
        rect(bg, bx - 4, cy - 1, bw, DS.lh_badge, sc, DS.badge_alpha)
        text(fg, bx, cy, FONT_FAMILY, DS.fs_badge, true, sc, '&H00&', label)
        bx = bx + bw + 6
    end
    if card.frequencyRank then
        text(fg, bx, cy, FONT_FAMILY, DS.fs_badge, false, DS.col_freq, '&H00&',
            '  ·  ＃' .. tostring(card.frequencyRank))
    end
    cy = cy + DS.lh_badge + DS.unit

    -- ── Divider ──────────────────────────────────────────────────────────────
    divider(fg, px+LB+2, cy, W-LB-4)
    cy = cy + DS.divider_h + DS.unit

    -- ── Kanji Breakdown ──────────────────────────────────────────────────────
    local kanji_list = extract_kanji(card.spelling)
    if #kanji_list > 0 and #kanji_list <= 4 then
        -- Grid layout: each kanji in a subtle box with meaning below
        local kanji_count = #kanji_list
        local box_width = math.floor((W - LB - PAD*2 - (kanji_count-1)*8) / kanji_count)
        local box_height = DS.lh_kanji + DS.lh_gloss + 8
        local start_x = px + cx0
        
        for i, k in ipairs(kanji_list) do
            local bx = start_x + (i-1) * (box_width + 8)
            
            -- Subtle background box
            rect(bg, bx-4, cy-2, box_width, box_height, DS.bg_header, '&H00&')
            
            -- Large kanji character
            textc(fg, bx + box_width/2, cy + DS.lh_kanji/2, 
                FONT_FAMILY, DS.fs_kanji-4, true, s_color, '&H00&', k.kanji)
            
            -- Small meaning below
            textc(fg, bx + box_width/2, cy + DS.lh_kanji + DS.lh_gloss/2 - 2,
                FONT_FAMILY, DS.fs_gloss-2, false, DS.col_tertiary, '&H00&', k.meaning)
        end
        
        cy = cy + box_height + DS.unit
        divider(fg, px+LB+2, cy, W-LB-4)
        cy = cy + DS.divider_h + DS.unit
    elseif #kanji_list > 4 then
        -- Compact inline for many kanji: 人person 気spirit 持have
        local parts = {}
        for _, k in ipairs(kanji_list) do
            parts[#parts + 1] = k.kanji .. k.meaning:sub(1, 1):upper() .. k.meaning:sub(2)
        end
        local compact_line = table.concat(parts, '  ·  ')
        
        -- Wrap if needed
        local wrapped = wrap_text(compact_line, 44)
        for _, line in ipairs(wrapped) do
            text(fg, cx, cy, FONT_FAMILY, DS.fs_gloss, false, DS.col_tertiary, '&H00&', line)
            cy = cy + DS.lh_gloss
        end
        
        cy = cy + DS.unit
        divider(fg, px+LB+2, cy, W-LB-4)
        cy = cy + DS.divider_h + DS.unit
    end

    -- ── Meanings ─────────────────────────────────────────────────────────────
    local shown, last_pl = 0, nil
    local total_meanings = #(card.meanings or {})
    for i, m in ipairs(card.meanings or {}) do
        if shown >= MAX_MEANINGS then break end
        local pl = pos_label(m.partOfSpeech)
        if pl ~= '' and pl ~= last_pl then
            text(fg, cx, cy, FONT_FAMILY, DS.fs_pos, false, DS.col_pos, '&H00&', '▸ ' .. pl)
            cy = cy + DS.lh_pos
            last_pl = pl
        end
        local gloss  = table.concat(m.glosses or {}, '; ')
        local wlines = wrap_text(gloss, WRAP_CHARS)
        for li, wl in ipairs(wlines) do
            local prefix  = (li == 1) and (tostring(i) .. '.  ') or '     '
            local tcol    = (i % 2 == 0) and DS.col_gloss_even or DS.col_gloss_odd
            text(fg, cx, cy, FONT_FAMILY, DS.fs_gloss, false, tcol, '&H00&', prefix .. wl)
            cy = cy + DS.lh_gloss
        end
        shown = shown + 1
    end
    if total_meanings > MAX_MEANINGS then
        text(fg, cx, cy, FONT_FAMILY, DS.fs_pos, false, DS.col_tertiary, '&H00&',
            '  … ' .. (total_meanings - MAX_MEANINGS) .. ' more meaning(s)')
        cy = cy + DS.lh_gloss
    end

    -- ── Inline toast (action feedback) ───────────────────────────────────────
    if popup_toast_text then
        cy = cy + DS.unit
        local tcol = popup_toast_ok and DS.col_toast_ok or DS.col_toast_err
        textc(fg, px + W/2, cy + DS.lh_toast/2,
            FONT_FAMILY, DS.fs_toast, true, tcol, '&H00&', popup_toast_text)
        cy = cy + DS.lh_toast
    end

    -- ── Divider ──────────────────────────────────────────────────────────────
    cy = cy + DS.unit * 2
    divider(fg, px+LB+2, cy, W-LB-4)
    cy = cy + DS.divider_h + DS.unit

    -- ── Button helper ─────────────────────────────────────────────────────────
    local function btn(label, key, action, args, bx2, by, bw, bh, fs)
        local is_hov  = (hovered_button == key)
        local pal     = BTN_MAP[key] or DS.btn_neutral
        local bg_col  = is_hov and pal.hov or pal.bg
        rect(bg, bx2, by, bw, bh, bg_col, '&H00&')
        -- top highlight line on hover
        if is_hov then rect(bg, bx2, by, bw, 1, '&HFFFFFF&', '&HCC&') end
        local sc = BTN_SHORTCUTS[key]
        if sc then
            text(fg, bx2+bw-13, by+3, FONT_FAMILY, DS.fs_shortcut,
                false, DS.col_shortcut, '&H00&', sc)
        end
        textc(fg, bx2+bw/2, by+bh/2, FONT_FAMILY, fs or DS.fs_btn_act,
            false, DS.col_primary, '&H00&', label)
        popup_buttons[#popup_buttons+1] =
            { x1=bx2, y1=by, x2=bx2+bw, y2=by+bh, key=key, action=action, args=args }
    end

    -- ── Action row - Only Never Forget button ────────────────────────────────
    local never_forgot = false
    for _, s in ipairs(card.state) do
        if s == 'never-forget' then never_forgot = true end
    end

    -- Single centered button
    local btn_width = math.floor((W - LB - PAD*2) * 0.6)  -- 60% of available width
    local btn_x = px + cx0 + math.floor(((W - LB - PAD*2) - btn_width) / 2)  -- Center it
    btn(never_forgot and '★ Remove Never Forget' or '★ Never Forget',
        'never-forget', 'set-flag', { flag='never-forget', state=not never_forgot }, 
        btn_x, cy, btn_width, DS.bh_action)
    cy = cy + DS.bh_action + DS.btn_gap

    --[[ DISABLED: Add and Blacklist buttons
    local aw   = math.floor((W - LB - PAD*2 - DS.btn_gap*2) / 3)
    local abx  = px + cx0
    btn('＋ Add',  'add', 'mine', {}, abx, cy, aw, DS.bh_action)
    abx = abx + aw + DS.btn_gap
    btn(blacklisted  and '✕ Un-Blacklist' or '⊘ Blacklist',
        'blacklist', 'set-flag', { flag='blacklist',    state=not blacklisted  }, abx, cy, aw, DS.bh_action)
    --]]

    --[[ DISABLED: Review buttons
    -- ── Review row ────────────────────────────────────────────────────────────
    local rev_btns = {
        { '✕ Nothing',   'nothing',   'nothing'   },
        { '△ Something', 'something', 'something' },
        { '▲ Hard',      'hard',      'hard'      },
        { '✓ Good',      'good',      'good'      },
        { '★ Easy',      'easy',      'easy'      },
    }
    local rw  = math.floor((W - LB - PAD*2 - DS.btn_gap*4) / 5)
    local rbx = px + cx0
    for _, b in ipairs(rev_btns) do
        btn(b[1], b[2], 'review', { rating=b[3] }, rbx, cy, rw, DS.bh_review, DS.fs_btn_rev)
        rbx = rbx + rw + DS.btn_gap
    end
    --]]

    -- ── Compose & diff ────────────────────────────────────────────────────────
    local all = {}
    for i = 1, #bg do all[i]        = bg[i] end
    for i = 1, #fg do all[#bg + i]  = fg[i] end
    local new_data = table.concat(all, '\n')
    if popup_osd.data ~= new_data then
        popup_osd.data = new_data
        popup_osd:update()
    end
end


-- ─── Hit testing ──────────────────────────────────────────────────────────────

local function find_hovered_token(mx, my)
    -- Pass 1: exact hit; prefer shorter spans (resolved during region build)
    local best, best_span = nil, math.huge
    for _, r in ipairs(subtitle_regions) do
        if my >= r.y1 and my <= r.y2 and mx >= r.x1 and mx <= r.x2 then
            if r.span < best_span then best = r.token; best_span = r.span end
        end
    end
    if best then return best end
    -- Pass 2: 10 px proximity fallback
    local best2, best_dist = nil, math.huge
    for _, r in ipairs(subtitle_regions) do
        if my >= r.y1 and my <= r.y2 and mx >= r.x1-10 and mx <= r.x2+10 then
            local d = math.abs(mx - (r.x1+r.x2)*0.5)
            if d < best_dist then best_dist = d; best2 = r.token end
        end
    end
    return best2
end

local function find_hovered_button(mx, my)
    for _, b in ipairs(popup_buttons) do
        if mx >= b.x1 and mx <= b.x2 and my >= b.y1 and my <= b.y2 then
            return b
        end
    end
end


-- ─── Actions ──────────────────────────────────────────────────────────────────

local function refresh_after_action()
    dlog('[refresh_after_action] Starting refresh...')
    http_request_async('POST', '/parse', { text = current_text }, function(res, err)
        if err or not (res and res.tokens) then 
            dlog('[refresh_after_action] Error or no tokens')
            return 
        end
        dlog('[refresh_after_action] Got ' .. #res.tokens .. ' tokens')
        current_tokens      = res.tokens
        cached_sub_ass      = nil
        cached_sub_token_id = nil
        if popup_visible and popup_token then
            dlog('[refresh_after_action] Popup visible, updating tokens')
            for _, tok in ipairs(current_tokens) do
                if tok.card.vid == popup_token.card.vid and
                   tok.card.sid == popup_token.card.sid then
                    popup_token = tok
                    hovered_token = tok  -- Keep hovered_token in sync!
                    dlog('[refresh_after_action] Updated popup_token and hovered_token')
                    break
                end
            end
            render_popup()
        end
        render_subtitles()
    end)
end

local function do_review(card, rating)
    show_popup_toast('Reviewing…', true)
    http_request_async('POST', '/review',
        { vid=card.vid, sid=card.sid, rating=rating },
        function(_, err)
            if err then show_popup_toast('✕ Review failed', false)
            else show_popup_toast('✓ Reviewed: ' .. rating, true)
                 mp.add_timeout(1.5, refresh_after_action) end
        end)
end

local function do_mine(card, sentence)
    show_popup_toast('Adding to deck…', true)
    http_request_async('POST', '/mine',
        { vid=card.vid, sid=card.sid, sentence=sentence or current_text },
        function(_, err)
            if err then show_popup_toast('✕ Add failed', false)
            else show_popup_toast('✓ Added: ' .. card.spelling, true)
                 mp.add_timeout(1.5, refresh_after_action) end
        end)
end

local function do_set_flag(card, flag, state)
    local verb = state and 'Setting' or 'Removing'
    show_popup_toast(verb .. ' ' .. flag .. '…', true)
    http_request_async('POST', '/set-flag',
        { vid=card.vid, sid=card.sid, flag=flag, state=state },
        function(_, err)
            if err then show_popup_toast('✕ Flag failed', false)
            else
                local done = state and '✓ Added ' or '✓ Removed '
                show_popup_toast(done .. flag, true)
                mp.add_timeout(1.5, refresh_after_action)
            end
        end)
end

local function dispatch_button(b)
    if not popup_token then return end
    local card = popup_token.card
    if     b.action == 'review'   then do_review(card, b.args.rating)
    elseif b.action == 'mine'     then do_mine(card, current_text)
    elseif b.action == 'set-flag' then do_set_flag(card, b.args.flag, b.args.state)
    end
end


-- ─── Subtitle observation ─────────────────────────────────────────────────────

local parse_timer = nil

local function on_subtitle_change(_, new_text)
    dlog('[on_subtitle_change] new_text=' .. tostring(new_text) .. ' last=' .. tostring(last_parsed_text))
    if new_text == last_parsed_text then return end
    last_parsed_text = new_text

    dlog('[on_subtitle_change] Subtitle changed, clearing state')
    if hover_debounce_timer then hover_debounce_timer:kill(); hover_debounce_timer = nil end
    hover_pending_token = nil
    hovered_token  = nil
    popup_visible  = false
    popup_token    = nil
    popup_buttons  = {}
    popup_rect     = nil
    popup_toast_text = nil
    subtitle_regions    = {}
    cached_sub_ass      = nil
    cached_sub_token_id = nil
    render_popup()

    if not new_text or new_text == '' then
        current_text = ''; current_tokens = {}
        render_subtitles(); return
    end

    current_text = new_text
    if parse_timer then parse_timer:kill() end
    parse_timer = mp.add_timeout(0.08, function()
        parse_timer = nil
        if current_text ~= new_text then return end
        http_request_async('POST', '/parse', { text = new_text }, function(res, err)
            if current_text ~= new_text or err then return end
            if res and res.tokens then
                current_tokens      = res.tokens
                cached_sub_ass      = nil
                cached_sub_token_id = nil
                render_subtitles()
            end
        end)
    end)
end

mp.observe_property('sub-text', 'string', on_subtitle_change)
mp.set_property('sub-visibility', 'no')
mp.set_property('secondary-sub-visibility', 'no')


-- ─── Pause helpers ────────────────────────────────────────────────────────────

local function jpdb_pause()
    if not jpdb_did_pause and not mp.get_property_bool('pause') then
        mp.set_property_bool('pause', true); jpdb_did_pause = true
    end
end

local function jpdb_resume()
    if jpdb_did_pause then
        mp.set_property_bool('pause', false); jpdb_did_pause = false
    end
end

local toggle_click_bindings  -- forward declaration

local function close_popup()
    popup_visible    = false
    popup_token      = nil
    popup_buttons    = {}
    popup_rect       = nil
    hovered_button   = nil
    hovered_token    = nil
    popup_toast_text = nil
    if popup_toast_timer then popup_toast_timer:kill(); popup_toast_timer = nil end
    if hover_debounce_timer then hover_debounce_timer:kill(); hover_debounce_timer = nil end
    hover_pending_token = nil
    cached_sub_ass      = nil
    cached_sub_token_id = nil
    render_popup()
    render_subtitles()
    jpdb_resume()
    if toggle_click_bindings then toggle_click_bindings(false) end
end


-- ─── Mouse tracking ───────────────────────────────────────────────────────────

local mouse_timer = nil

mp.observe_property('mouse-pos', 'native', function(_, pos)
    if not pos then return end
    hover_x = pos.x; hover_y = pos.y
    if mouse_timer then return end
    mouse_timer = mp.add_timeout(0.016, function()
        mouse_timer = nil
        local mx, my = hover_x, hover_y

        -- 1. Popup safe-zone ──────────────────────────────────────────────────
        if popup_visible and popup_rect then
            local pad = 18
            if mx >= popup_rect.x1-pad and mx <= popup_rect.x2+pad and
               my >= popup_rect.y1-pad and my <= popup_rect.y2+pad then
                if hover_debounce_timer then
                    hover_debounce_timer:kill(); hover_debounce_timer = nil
                end
                hover_pending_token = nil
                -- Keep hovered_token set to popup_token so subtitle stays visible
                if popup_token and hovered_token ~= popup_token then
                    hovered_token = popup_token
                    cached_sub_ass = nil
                    cached_sub_token_id = nil
                    render_subtitles()
                end
                local hit = find_hovered_button(mx, my)
                local nk  = hit and hit.key or nil
                if nk ~= hovered_button then
                    hovered_button = nk; render_popup()
                end
                return
            end
        end

        -- 2. Subtitle interaction zone guard ──────────────────────────────────
        local layout  = subtitle_layout()
        local zone_y1 = math.max(0, layout.sub_text_top - 500)
        local zone_y2 = layout.sub_y + 50
        if my < zone_y1 or my > zone_y2 then
            if popup_visible or hovered_token then close_popup() end
            return
        end

        -- 3. Token hit-test with adaptive debounce ────────────────────────────
        local new_token = find_hovered_token(mx, my)

        if new_token ~= hovered_token then
            if new_token ~= hover_pending_token then
                hover_pending_token = new_token
                if hover_debounce_timer then hover_debounce_timer:kill() end

                -- Adaptive: re-entering same token = fast (80ms),
                --           new token = normal (150ms), leaving = slow (220ms)
                local delay
                if not new_token then
                    delay = 0.22
                elseif new_token == popup_token then
                    delay = 0.08
                else
                    delay = 0.15
                end

                hover_debounce_timer = mp.add_timeout(delay, function()
                    hover_debounce_timer = nil
                    hovered_token       = hover_pending_token
                    cached_sub_ass      = nil
                    cached_sub_token_id = nil
                    render_subtitles()
                    if hovered_token then
                        jpdb_pause()
                        popup_token    = hovered_token
                        popup_visible  = true
                        hovered_button = nil
                        popup_toast_text = nil
                        render_popup()
                        toggle_click_bindings(true)
                    elseif not popup_visible then
                        close_popup()
                    end
                end)
            end
        else
            if hover_debounce_timer then hover_debounce_timer:kill(); hover_debounce_timer = nil end
            hover_pending_token = nil
            if popup_visible and hovered_button ~= nil then
                hovered_button = nil; render_popup()
            end
        end
    end)
end)


-- ─── Mouse clicks ─────────────────────────────────────────────────────────────

local clicks_bound = false

local function handle_left_click(event)
    if event and event.event ~= 'down' then return end
    dlog('[handle_left_click] popup_visible=' .. tostring(popup_visible))
    if popup_visible then
        -- FIX: dispatch BEFORE close so button action fires correctly
        local b = find_hovered_button(hover_x, hover_y)
        dlog('[handle_left_click] button found=' .. tostring(b ~= nil))
        if b then
            dlog('[handle_left_click] Button clicked: ' .. b.key)
            dlog('[handle_left_click] popup_token=' .. tostring(popup_token))
            dlog('[handle_left_click] About to dispatch button')
            
            local ok, err = pcall(function()
                dispatch_button(b)
            end)
            if not ok then
                dlog('[handle_left_click] ERROR in dispatch_button: ' .. tostring(err))
            end
            
            dlog('[handle_left_click] After dispatch_button')
            -- Keep hovered_token set so subtitle stays visible during toast
            if popup_token then
                dlog('[handle_left_click] Setting hovered_token to popup_token')
                hovered_token = popup_token
                cached_sub_ass = nil
                cached_sub_token_id = nil
                dlog('[handle_left_click] About to render_subtitles')
                render_subtitles()
                dlog('[handle_left_click] After render_subtitles')
            else
                dlog('[handle_left_click] ERROR: popup_token is nil!')
            end
            -- Don't close immediately — let the inline toast show for 1.4s
        else
            close_popup()
        end
    end
end

local function handle_left_dbl_click()
    if not popup_visible then mp.command('cycle fullscreen') end
end

toggle_click_bindings = function(enable)
    if enable and not clicks_bound then
        mp.add_forced_key_binding('MBTN_LEFT',     'jpdb-click',     handle_left_click, { complex=true })
        mp.add_forced_key_binding('MBTN_LEFT_DBL', 'jpdb-dbl-click', handle_left_dbl_click)
        clicks_bound = true
    elseif not enable and clicks_bound then
        mp.remove_key_binding('jpdb-click')
        mp.remove_key_binding('jpdb-dbl-click')
        clicks_bound = false
    end
end

mp.add_forced_key_binding('MBTN_RIGHT', 'jpdb-close', function()
    if popup_visible then close_popup() end
end)

mp.add_key_binding('ESC', 'jpdb-esc', function()
    if popup_visible then close_popup() end
end)

mp.add_key_binding('shift', 'jpdb-show-popup', function()
    if hovered_token and not popup_visible then
        popup_token = hovered_token; popup_visible = true
        hovered_button = nil; popup_toast_text = nil
        render_popup(); toggle_click_bindings(true)
    elseif popup_visible then
        close_popup()
    end
end)

mp.add_key_binding('a', 'jpdb-add', function()
    local tok = popup_token or hovered_token
    if tok then do_mine(tok.card, current_text) end
end)

local function review_hotkey(r)
    return function()
        local tok = popup_token or hovered_token
        if tok then do_review(tok.card, r) end
    end
end
mp.add_key_binding('1', 'jpdb-nothing',   review_hotkey('nothing'))
mp.add_key_binding('2', 'jpdb-something', review_hotkey('something'))
mp.add_key_binding('3', 'jpdb-hard',      review_hotkey('hard'))
mp.add_key_binding('4', 'jpdb-good',      review_hotkey('good'))
mp.add_key_binding('5', 'jpdb-easy',      review_hotkey('easy'))

mp.add_key_binding('b', 'jpdb-blacklist', function()
    local tok = popup_token or hovered_token; if not tok then return end
    local is_bl = false
    for _, s in ipairs(tok.card.state) do if s=='blacklisted' then is_bl=true end end
    do_set_flag(tok.card, 'blacklist', not is_bl)
end)

mp.add_key_binding('n', 'jpdb-never-forget', function()
    local tok = popup_token or hovered_token; if not tok then return end
    local is_nf = false
    for _, s in ipairs(tok.card.state) do if s=='never-forget' then is_nf=true end end
    do_set_flag(tok.card, 'never-forget', not is_nf)
end)


-- ─── Overlay init & resize ────────────────────────────────────────────────────

local function init_overlays()
    if not sub_osd then
        sub_osd = mp.create_osd_overlay('ass-events'); sub_osd.z = 0
    end
    if not popup_osd then
        popup_osd = mp.create_osd_overlay('ass-events'); popup_osd.z = 1
    end
    sub_osd.res_x = osd_w;   sub_osd.res_y = osd_h
    popup_osd.res_x = osd_w; popup_osd.res_y = osd_h
end

init_overlays()

mp.register_event('file-loaded', function()
    local w = mp.get_property_number('osd-width')  or osd_w
    local h = mp.get_property_number('osd-height') or osd_h
    if w > 0 then osd_w = w end
    if h > 0 then osd_h = h end
    init_overlays()
    if #current_tokens > 0 then render_subtitles() end
end)

mp.observe_property('osd-width', 'number', function(_, w)
    if w and w > 0 then osd_w = w end
    if sub_osd   then sub_osd.res_x   = osd_w end
    if popup_osd then popup_osd.res_x = osd_w end
    render_subtitles(); render_popup()
end)

mp.observe_property('osd-height', 'number', function(_, h)
    if h and h > 0 then osd_h = h end
    if sub_osd   then sub_osd.res_y   = osd_h end
    if popup_osd then popup_osd.res_y = osd_h end
    render_subtitles(); render_popup()
end)

mp.register_event('shutdown', function()
    -- Unregister this MPV instance; server shuts itself down when count → 0
    mp.command_native({
        name='subprocess',
        args={'curl','-s','-X','POST','--max-time','3', SERVER_URL..'/unregister'},
        capture_stdout=false, capture_stderr=false, playback_only=false,
    })
    if sub_osd   then sub_osd:remove()   end
    if popup_osd then popup_osd:remove() end
    if log_file  then log_file:close()   end
end)