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

-- Load kanji semantic color categories from separate file
local kanji_semantic_colors = dofile(PLUGIN_DIR .. '/kanji-semantic-colors.lua')

-- Pre-build keyword lookup table for O(1) semantic color matching
local kanji_color_exact = {}   -- exact word match: keyword → {color, alpha}
local kanji_color_patterns = {} -- for substring/pattern matching fallback
for _, category in ipairs(kanji_semantic_colors) do
    for _, keyword in ipairs(category.keywords) do
        local kw = keyword:lower()
        kanji_color_exact[kw] = { color = category.color, alpha = category.alpha }
    end
end

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

-- ─── Server health monitoring ─────────────────────────────────────────────────
-- Periodically check if the server is still alive. If it's down, attempt re-launch.
local server_health_timer = nil
local server_was_up = false
local server_reconnect_attempts = 0

local function start_health_monitor()
    if server_health_timer then return end
    server_health_timer = mp.add_periodic_timer(30, function()
        server_ping(function(up)
            if up then
                if not server_was_up then
                    dlog('[jpdb] Server recovered')
                    mp.osd_message('[jpdb] Server reconnected ✓', 2)
                    register_with_server()
                    server_reconnect_attempts = 0
                end
                server_was_up = true
            else
                if server_was_up then
                    dlog('[jpdb] Server connection lost — attempting restart')
                    mp.osd_message('[jpdb] Server lost — restarting…', 3)
                end
                server_was_up = false
                if server_reconnect_attempts < 3 then
                    server_reconnect_attempts = server_reconnect_attempts + 1
                    launch_server_then_register()
                end
            end
        end)
    end)
end

-- Start health monitoring after initial connection
mp.add_timeout(5, function()
    server_was_up = true
    start_health_monitor()
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
local current_px_map    = nil  -- server-measured byte→pixel map (from font metrics)
local last_parsed_text  = nil
local hovered_token     = nil
local hover_x           = 0
local hover_y           = 0
local subtitle_regions  = {}
local subtitle_line_data = {}  -- per-line data for byte-offset hit detection
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
local resize_timer = nil

-- OSD canvas
local osd_w = 1280
local osd_h = 720

-- Screen (window) dimensions for coordinate scaling.
-- mouse-pos returns raw window pixels; subtitle regions live in OSD space.
local screen_w = 0
local screen_h = 0

-- Convert raw window pixel coords → OSD resolution coords.
-- When screen size is unknown, falls back to identity (assumes 1:1).
local function screen_to_osd(sx, sy)
    if screen_w > 0 and screen_h > 0 then
        return sx * osd_w / screen_w, sy * osd_h / screen_h
    end
    return sx, sy
end

-- Subtitle ASS cache
local cached_sub_ass      = nil
local cached_sub_token_id = nil
local cached_sub_regions  = nil
local cached_sub_line_data = nil

-- compute_bounds cache: keyed on (text, font_size, osd_w, osd_h)
local bounds_cache = {}
local kanji_extract_cache = {}
local last_popup_render_key = nil

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

local function url_encode(str)
    if not str then return '' end
    str = string.gsub(str, "\n", "\r\n")
    str = string.gsub(str, "([^%w _%%%-%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    str = string.gsub(str, " ", "+")
    return str
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ─── UTF-8 / Unicode Width ────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Glyph widths auto-scaled from font_size.
-- Base ratios calibrated for Yu Gothic UI; override with width_scale in config.

local SUB_CONF = conf.SUBTITLE_OVERLAY
local LINE_H    = SUB_CONF.line_h
local BORD_W    = SUB_CONF.bord_w or 2

-- Auto-scale character widths: base values are for font_size=60.
-- When font_size changes, widths scale proportionally.
local _font_scale  = SUB_CONF.font_size / 60
local _width_scale = (SUB_CONF.width_scale or 1.0) * _font_scale
local PX_FULL   = (SUB_CONF.px_full or 60)   * _width_scale
local PX_HALF   = (SUB_CONF.px_half or 32)   * _width_scale
local PX_NARROW = (SUB_CONF.px_narrow or 18) * _width_scale

-- Returns (pixel_width, next_byte_index) for the UTF-8 character at byte i.
-- Refined classification vs v2:
--   · Halfwidth Katakana (U+FF65..U+FF9F) → half  [3-byte, lead E0..EF range check]
--   · Fullwidth Latin (U+FF01..U+FF60)    → full
--   · CJK Compat Ideographs (U+F900..U+FAFF) → full
local function char_px(s, i)
    local b = s:byte(i)
    if b < 0x80 then
        -- Refined ASCII width: letters/digits = half, punctuation/space = narrow
        if b == 0x20 then return PX_NARROW, i + 1 end  -- space
        if (b >= 0x41 and b <= 0x5A) or (b >= 0x61 and b <= 0x7A) then return PX_HALF, i + 1 end  -- A-Z, a-z
        if b >= 0x30 and b <= 0x39 then return PX_HALF, i + 1 end  -- 0-9
        return PX_NARROW, i + 1  -- punctuation: .,!?;:'"()-/ etc.
    end
    if b < 0xE0 then return PX_HALF, i + 2 end  -- 2-byte (Latin, Greek, etc.)
    if b < 0xF0 then
        -- 3-byte: decode first 2 bytes to get codepoint block
        local b2 = s:byte(i + 1) or 0x80
        -- U+3000..U+FFFF  → lead E3..EF is full-width
        -- BUT U+FF65..U+FF9F (halfwidth Katakana) lead=EF, b2=BD
        if b >= 0xE3 then
            if b == 0xEF then
                if b2 == 0xBD then
                    -- U+FF40..U+FF7F — halfwidth Katakana starts at 0xEF 0xBD 0xA5
                    local b3 = s:byte(i + 2) or 0x80
                    if b3 >= 0xA5 then return PX_HALF, i + 3 end
                elseif b2 == 0xBE then
                    -- U+FF80..U+FF9F — more halfwidth Katakana
                    local b3 = s:byte(i + 2) or 0x80
                    if b3 >= 0x80 and b3 <= 0x9F then return PX_HALF, i + 3 end
                end
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
--
-- If server-measured px_map is available (from font metrics), uses it for
-- ─── ASS helpers ──────────────────────────────────────────────────────────────

local function esc(s)
    if not s then return '' end
    return (s:gsub('\\','\\\\'):gsub('{','\\{'):gsub('}','\\}'):gsub('\n','\\N'))
end

-- Build byte→pixel cumulative map for one line of text (RAW metric space).
-- map[k] = px offset of the character whose first byte is at 1-indexed position k.
-- map[#text+1] = total pixel width (sentinel).
--
-- Returns raw server font metrics without any scaling — the caller applies
-- compute_bounds calibration (cal_scale) to convert to screen space.
local function build_px_map(text, line_byte_start)
    -- Try server-measured pixel map first (line_byte_start is 0-indexed global offset)
    if current_px_map and line_byte_start then
        local map = {}
        local len = #text
        local first_px = nil
        local i = 1
        while i <= len do
            local global_byte = line_byte_start + i  -- 1-indexed in server map
            local px_val = current_px_map[global_byte]
            if px_val then
                if not first_px then first_px = px_val end
                map[i] = px_val - first_px
            end
            -- Advance to next character
            local b = text:byte(i)
            if     b < 0x80 then i = i + 1
            elseif b < 0xE0 then i = i + 2
            elseif b < 0xF0 then i = i + 3
            else                 i = i + 4 end
        end
        -- Sentinel
        local end_byte = line_byte_start + len + 1
        local end_px = current_px_map[end_byte]
        if first_px and end_px then
            local total = end_px - first_px
            map[len + 1] = total
            return map, total
        end
        -- Fall through to estimated model if server map was incomplete
    end

    -- Fallback: estimated character width model
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

-- Measure the actual rendered width of a line using mpv's compute_bounds.
-- Returns {x0, x1, width} or nil if unavailable.
-- Uses \an2 centered positioning to match actual rendering, but strips
-- border/shadow so we get pure text advance width.
local MEASURE_OSD_ID = 99
local compute_bounds_available = nil  -- nil = untested, true/false = tested

local function measure_line_bounds(text, font_size)
    -- Skip if compute_bounds was already found unavailable
    if compute_bounds_available == false then return nil end

    local key = text .. '@@' .. font_size .. '@@' .. osd_w .. '@@' .. osd_h
    if bounds_cache[key] then return bounds_cache[key] end

    local sub_x = math.floor(osd_w / 2)
    local styled = '{\\an2\\pos(' .. sub_x .. ',360)\\fn' .. FONT_FAMILY
                 .. '\\fsp0\\bord0\\shad0\\fs' .. font_size .. '}' .. esc(text)

    local ok, res = pcall(mp.command_native, {
        name = 'osd-overlay',
        id = MEASURE_OSD_ID,
        format = 'ass-events',
        data = styled,
        res_x = osd_w,
        res_y = osd_h,
        compute_bounds = true,
    })
    -- Remove measurement overlay immediately so it's never visible
    pcall(mp.command_native, {
        name = 'osd-overlay',
        id = MEASURE_OSD_ID,
        format = 'ass-events',
        data = '',
        res_x = osd_w,
        res_y = osd_h,
    })

    if ok and res and type(res) == 'table' and res.x0 and res.x1 and res.x1 > res.x0 then
        compute_bounds_available = true
        local result = { x0 = res.x0, x1 = res.x1, width = res.x1 - res.x0 }
        bounds_cache[key] = result
        dlog('[measure_line_bounds] "' .. text:sub(1, 20) .. '…" → x0='
             .. string.format('%.1f', result.x0) .. ' x1='
             .. string.format('%.1f', result.x1) .. ' width='
             .. string.format('%.1f', result.width))
        return result
    end

    if compute_bounds_available == nil then
        compute_bounds_available = false
        dlog('[measure_line_bounds] compute_bounds not available in this mpv version, using fallback')
    end
    return nil
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

-- ─── Pitch Accent Helpers ─────────────────────────────────────────────────────

-- Split a hiragana/katakana reading string into morae.
-- Handles digraphs (e.g. き+ゃ = きゃ, シ+ョ = ショ) and lone characters.
local DIGRAPH_SMALL = {
    -- small hiragana
    ['ぁ']=true,['ぃ']=true,['ぅ']=true,['ぇ']=true,['ぉ']=true,
    ['ゃ']=true,['ゅ']=true,['ょ']=true,['ゎ']=true,
    -- small katakana
    ['ァ']=true,['ィ']=true,['ゥ']=true,['ェ']=true,['ォ']=true,
    ['ャ']=true,['ュ']=true,['ョ']=true,['ヮ']=true,
}

local function split_morae(reading)
    local morae = {}
    -- Guard: only accept actual strings
    if type(reading) ~= 'string' or reading == '' then return morae end
    local i, len = 1, #reading
    while i <= len do
        local b = reading:byte(i)
        local clen
        if b < 0x80 then clen = 1
        elseif b < 0xE0 then clen = 2
        elseif b < 0xF0 then clen = 3
        else clen = 4 end
        local ch = reading:sub(i, i + clen - 1)
        i = i + clen
        -- peek at next char — if it is a small kana it merges with current
        if i <= len then
            local nb = reading:byte(i)
            local nlen
            if nb < 0x80 then nlen = 1
            elseif nb < 0xE0 then nlen = 2
            elseif nb < 0xF0 then nlen = 3
            else nlen = 4 end
            local nch = reading:sub(i, i + nlen - 1)
            if DIGRAPH_SMALL[nch] then
                morae[#morae+1] = ch .. nch
                i = i + nlen
            else
                morae[#morae+1] = ch
            end
        else
            morae[#morae+1] = ch
        end
    end
    return morae
end

-- Parse JPDB's pitch_accent field.
-- JPDB returns: an array of strings like ["LHH"] or ["LHHL"]
-- where L=low mora, H=high mora.
-- We use the first pattern in the array.
-- Returns: (pattern_string, label_string) or (nil, nil)
-- e.g. "LHH" -> ('LHH', '平')  "HLL" -> ('HLL', '頭')
local function parse_pitch_accent(pa)
    if not pa then return nil, nil end
    -- Handle: array of strings
    if type(pa) == 'table' and #pa > 0 then
        local first = pa[1]
        if type(first) == 'string' and #first > 0 then
            -- Classify pattern for label
            local pat = first:upper()
            local label
            if pat:match('^LH*$') then
                label = '平'   -- heiban: starts low, all rest high (LHHH...)
            elseif pat:match('^H') then
                label = '頭'   -- atamadaka: starts high
            elseif pat:match('H+L') then
                label = '中'   -- nakadaka: rises then drops in middle
            else
                label = '平'   -- default to heiban
            end
            return pat, label
        end
    end
    -- Handle: single string (shouldn't happen but be safe)
    if type(pa) == 'string' and #pa > 0 then
        return pa:upper(), '?'
    end
    return nil, nil
end

-- Pitch accent layout constants (JPDB line-style)
-- Row contains: 3px top line space + kana text + 3px bottom line space + gap
local PA_KANA_FS  = 18    -- font size for mora kana in the pitch bar
local PA_KANA_H   = 22    -- pixel height of the kana line
local PA_LINE_T   = 2     -- thickness of over/underline
local PA_VERT_T   = 2     -- thickness of vertical connector
local PA_TOP_PAD  = 4     -- space above kana for the overline
local PA_BOT_PAD  = 4     -- space below kana for the underline
local PA_MORA_W   = 22    -- fixed width per mora cell
local PA_GAP      = 2     -- horizontal gap between mora cells (for vertical line)
local PA_ROW_H    = PA_TOP_PAD + PA_KANA_H + PA_BOT_PAD + PA_LINE_T + 6

-- Extract individual kanji characters from a string
local function extract_kanji(text)
    if kanji_extract_cache[text] then return kanji_extract_cache[text] end
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
        if kanji_meanings_map[char] then
            kanji_list[#kanji_list + 1] = {
                kanji = char,
                meaning = kanji_meanings_map[char]
            }
        end
        i = i + char_len
    end
    kanji_extract_cache[text] = kanji_list
    return kanji_list
end


-- ══════════════════════════════════════════════════════════════════════════════
-- ─── Subtitle Overlay ─────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

-- Build ASS inline tags for ONE subtitle line (not the full text).
-- line_start / line_end are 0-indexed byte offsets into raw_text.
-- Hovered token → full colour + underline
-- Other tokens  → dim colour (focus contrast)
-- Gaps          → white
local function build_line_subtitle_ass(tokens, raw_text, line_start, line_end)
    -- Filter and sort tokens that fall within this line
    local sorted = {}
    for _, t in ipairs(tokens) do
        if t.start >= line_start and t['end'] <= line_end then
            sorted[#sorted+1] = t
        end
    end
    if #sorted == 0 then
        -- No tokens on this line — render as plain white text
        local has_hovered = (hovered_token ~= nil)
        local gap_al = has_hovered and '&H22&' or '&H00&'
        return '{\\c&HFFFFFF&\\1a' .. gap_al .. '\\u0}' .. esc(raw_text:sub(line_start + 1, line_end))
    end
    table.sort(sorted, function(a, b)
        if a.start ~= b.start then return a.start < b.start end
        return (a['end'] - a.start) < (b['end'] - b.start)
    end)

    local parts = {}
    local last  = line_start
    local has_hovered = (hovered_token ~= nil)

    for _, tok in ipairs(sorted) do
        if tok.start >= last then
            if tok.start > last then
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

    if last < line_end then
        local gap_al = has_hovered and '&H22&' or '&H00&'
        parts[#parts+1] = '{\\c&HFFFFFF&\\1a' .. gap_al .. '\\u0}'
        parts[#parts+1] = esc(raw_text:sub(last + 1, line_end))
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
    subtitle_line_data = {}

    dlog('[render_subtitles] tokens=' .. #current_tokens .. ' hovered=' .. tostring(hovered_token ~= nil))

    if #current_tokens == 0 then
        if sub_osd.data ~= '' then sub_osd.data = ''; sub_osd:update() end
        return
    end

    -- Cache key includes osd_w because line_left depends on it
    local tok_id = #current_tokens .. ':' .. tostring(hovered_token) .. ':' .. osd_w

    -- Fast path: if nothing changed, restore cached ASS + hit data
    if cached_sub_token_id == tok_id and cached_sub_ass and cached_sub_regions then
        subtitle_regions = cached_sub_regions
        subtitle_line_data = cached_sub_line_data or {}
        if sub_osd.data ~= cached_sub_ass then
            sub_osd.data = cached_sub_ass
            sub_osd:update()
        end
        return
    end

    local layout = subtitle_layout()
    local sub_x  = math.floor(osd_w / 2)
    -- ASS tag: explicit font + zero letter spacing for predictable glyph widths
    local tag_prefix = '\\fn' .. FONT_FAMILY .. '\\fsp0\\bord2\\shad1\\b0'

    local line_parts = {}

    for li, ln in ipairs(layout.lines) do
        local from_bottom = layout.n - li
        local line_bottom = layout.sub_y - from_bottom * LINE_H

        -- Vertical hit region calibrated to font metrics + border
        local ascent  = SUB_CONF.ascent_ratio or 0.88
        local descent = SUB_CONF.descent_ratio or 0.15
        local vpad    = SUB_CONF.vert_pad or 4
        local y1 = line_bottom - math.floor(SUB_CONF.font_size * ascent) - BORD_W - vpad
        local y2 = line_bottom + math.floor(SUB_CONF.font_size * descent) + BORD_W + vpad

        local lbs = ln.byte_start
        local lbe = lbs + #ln.text

        local px_map, raw_total = build_px_map(ln.text, lbs)

        -- Use compute_bounds to get ACTUAL rendered width from libass.
        local bounds = measure_line_bounds(ln.text, SUB_CONF.font_size)
        local actual_total, actual_x0, cal_scale
        if bounds and raw_total > 0 then
            actual_total = bounds.width
            actual_x0    = bounds.x0
            cal_scale    = actual_total / raw_total
        else
            actual_total = raw_total
            actual_x0    = osd_w / 2 - raw_total / 2
            cal_scale    = 1.0
        end

        -- Build ASS for this line
        local line_ass = build_line_subtitle_ass(current_tokens, current_text, lbs, lbe)
        if line_ass then
            line_parts[#line_parts+1] = line_ass
        end

        -- Collect tokens on this line, sorted shortest-span first (for overlaps)
        local line_toks = {}
        for _, tok in ipairs(current_tokens) do
            if tok.start >= lbs and tok['end'] <= lbe then
                line_toks[#line_toks+1] = tok
            end
        end
        table.sort(line_toks, function(a, b)
            return (a['end'] - a.start) < (b['end'] - b.start)
        end)

        -- Measure token boundary positions using compute_bounds on text prefixes.
        -- This gives us EXACT pixel positions for each token edge as rendered
        -- by libass, instead of relying on scaled font-metric approximations.
        local boundary_px = { [0] = 0, [#ln.text] = actual_total }
        if compute_bounds_available ~= false then
            -- Collect unique boundary byte positions
            local boundary_set = {}
            for _, tok in ipairs(line_toks) do
                local ls = tok.start - lbs
                local le = tok['end'] - lbs
                if ls > 0 and ls < #ln.text then boundary_set[ls] = true end
                if le > 0 and le < #ln.text then boundary_set[le] = true end
            end
            -- Measure prefix width for each boundary
            for pos in pairs(boundary_set) do
                local prefix = ln.text:sub(1, pos)
                local pb = measure_line_bounds(prefix, SUB_CONF.font_size)
                if pb then
                    boundary_px[pos] = pb.width
                else
                    -- Fallback: scaled font metrics
                    boundary_px[pos] = (px_map[pos + 1] or 0) * cal_scale
                end
            end
        end

        -- Build token hit regions with measured pixel boundaries
        local token_regions = {}
        for _, tok in ipairs(line_toks) do
            local ls = tok.start - lbs
            local le = tok['end'] - lbs
            local px0 = boundary_px[ls]
            local px1 = boundary_px[le]
            if not px0 then px0 = (px_map[ls + 1] or 0) * cal_scale end
            if not px1 then px1 = (px_map[le + 1] or raw_total) * cal_scale end
            local raw_w = px1 - px0
            local pad_x = (raw_w < 30) and math.floor((30 - raw_w) / 2) or 0
            token_regions[#token_regions+1] = {
                px0 = px0, px1 = px1, tok = tok,
            }
            subtitle_regions[#subtitle_regions+1] = {
                x1    = actual_x0 + px0 - pad_x - BORD_W,
                x2    = actual_x0 + px1 + pad_x + BORD_W,
                y1    = y1,
                y2    = y2,
                token = tok,
                span  = le - ls,
            }
        end

        -- Store per-line hit data
        subtitle_line_data[#subtitle_line_data+1] = {
            y1 = y1, y2 = y2,
            actual_total = actual_total,
            actual_x0    = actual_x0,
            token_regions = token_regions,
            text = ln.text,
            byte_start = lbs,
            byte_end = lbe,
        }
    end

    -- \an2 rendering: libass handles centering using actual font metrics.
    -- Hit detection uses our px_map (server font metrics) for byte mapping.
    local a = assdraw.ass_new()
    a:new_event()
    a:append('{\\an2\\pos(' .. sub_x .. ',' .. layout.sub_y .. ')\\fs'
          .. SUB_CONF.font_size .. tag_prefix .. '}')
    a:append(table.concat(line_parts, '\\N'))

    -- Debug: visualize hit regions as semi-transparent rectangles
    if conf.DEBUG_LOG then
        for _, r in ipairs(subtitle_regions) do
            a:new_event()
            a:append('{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H00FFFF&\\1a&HCC&\\p1}')
            a:append('m ' .. math.floor(r.x1) .. ' ' .. math.floor(r.y1)
                  .. ' l ' .. math.floor(r.x2) .. ' ' .. math.floor(r.y1)
                  .. ' l ' .. math.floor(r.x2) .. ' ' .. math.floor(r.y2)
                  .. ' l ' .. math.floor(r.x1) .. ' ' .. math.floor(r.y2))
        end
    end

    local new_data = a.text
    if sub_osd.data ~= new_data then
        sub_osd.data = new_data
        sub_osd:update()
    end
    cached_sub_ass       = new_data
    cached_sub_token_id  = tok_id
    cached_sub_regions   = subtitle_regions
    cached_sub_line_data = subtitle_line_data
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

    local render_key = string.format('%s:%s:%s:%s:%s',
        tostring(popup_token and popup_token.card and popup_token.card.vid),
        tostring(popup_token and popup_token.card and popup_token.card.sid),
        tostring(hovered_button),
        tostring(popup_toast_text),
        tostring(popup_rect and popup_rect.x1))
    if render_key == last_popup_render_key then return end

    local card    = popup_token.card
    local state   = get_primary_state(card.state)
    local s_color = STATE_COLORS[state] or '&HFFFFFF&'

    local W   = DS.width
    local LB  = DS.lbar_w
    local PAD = DS.pad_h
    local cx0 = LB + PAD  -- content x offset from popup left

    -- ── Height measurement pass ──────────────────────────────────────────────
    -- Pre-parse pitch accent so measure_h and render both use it
    -- Use pcall to make absolutely sure a bad PA value can't crash the popup
    local pa_raw     = card.pitchAccent
    local pa_reading  = type(card.reading) == 'string' and card.reading or ''
    local pa_morae    = split_morae(pa_reading)
    local pa_pat, pa_label = parse_pitch_accent(pa_raw)
    local pa_pat_len  = pa_pat and #pa_pat or 0
    local has_pitch   = (pa_pat ~= nil and pa_pat_len > 0 and #pa_morae > 0)

    local function measure_h()
        local h = DS.pad_v + DS.lh_kanji
        if card.spelling ~= card.reading then h = h + DS.lh_reading end
        h = h + DS.lh_badge + DS.unit           -- state badges row
        h = h + DS.divider_h + DS.unit           -- first divider
        
        -- Kanji breakdown section - BEYOND THE IMPOSSIBLE
        local kanji_list = extract_kanji(card.spelling)
        if #kanji_list > 0 and #kanji_list <= 4 then
            -- GIGA DRILL BREAKER: Maximum impact mode
            h = h + DS.lh_kanji + DS.lh_gloss + 16 + DS.unit
            h = h + DS.divider_h + DS.unit
        elseif #kanji_list > 4 and #kanji_list <= 8 then
            -- ARC-GURREN LAGANN: Adaptive grid
            local cols = (#kanji_list <= 6) and 3 or 4
            local rows = math.ceil(#kanji_list / cols)
            h = h + rows * (DS.lh_kanji + DS.lh_gloss + 10 + 4) + DS.unit
            h = h + DS.divider_h + DS.unit
        elseif #kanji_list > 8 then
            -- SUPER TENGEN TOPPA: Cosmic ribbon
            h = h + DS.lh_gloss + 8 + DS.unit
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
        -- Always allocate space for toast so the popup never changes size
        h = h + DS.unit + DS.lh_toast
        h = h + DS.unit * 2 + DS.divider_h + DS.unit
        -- Only one button row now
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

    -- ── Pitch Accent Visualization — RIGHT SIDE of header (JPDB style) ───────
    -- Floats to the right of the kanji/reading, vertically centred in header.
    -- Red overline = HIGH, Blue underline = LOW, Red vertical = transition.
    if has_pitch then
        local ok, err_pa = pcall(function()
            local n = #pa_morae
            if n == 0 or not pa_pat then return end

            -- is_high(i): read directly from LH string, clamp at end
            local function is_high(mi)
                local idx = math.min(mi, pa_pat_len)
                return pa_pat:sub(idx, idx) == 'H'
            end

            -- ASS colors (BGR format)
            local COL_HIGH  = '&H4343E0&'   -- red   #E04343
            local COL_LOW   = '&HE16941&'   -- blue  #4169E1
            local COL_CONN  = '&H4343E0&'   -- vertical connector = red
            local COL_LABEL = '&HC0A880&'   -- warm-gray label
            local AL_SOLID  = '&H00&'

            -- Right-side anchor: right-aligned inside popup
            local right_edge = px + W - PAD        -- right margin
            -- Mora cell sizing: fit up to 10 moras, clamp between 18-26px wide
            local max_bar_w  = math.min(W - LB - PAD * 2 - 10, 160)  -- max bar takes right portion
            local mora_w = math.min(26, math.max(18,
                math.floor((max_bar_w - n * PA_GAP) / n)))
            local total_w = n * mora_w + (n - 1) * PA_GAP

            -- Horizontal: right-align the bar
            local bar_right = right_edge
            local bar_x     = bar_right - total_w

            -- Vertical: center within the kanji+reading text zone
            local hdr_text_h = DS.lh_kanji + (card.spelling ~= card.reading and DS.lh_reading or 0)
            local center_y   = py + DS.pad_v + hdr_text_h / 2
            local over_y     = math.floor(center_y - PA_KANA_H / 2 - PA_TOP_PAD)
            local kana_y     = over_y + PA_TOP_PAD
            local under_y    = kana_y + PA_KANA_H + 2

            local cur_x = bar_x
            for mi = 1, n do
                local high     = is_high(mi)
                local cell_x   = cur_x
                local cell_end = cell_x + mora_w

                -- Horizontal line: RED overline (H) or BLUE underline (L)
                if high then
                    rect(bg, cell_x, over_y, mora_w, PA_LINE_T, COL_HIGH, AL_SOLID)
                else
                    rect(bg, cell_x, under_y, mora_w, PA_LINE_T, COL_LOW, AL_SOLID)
                end

                -- Kana text centred in cell
                textc(fg, cell_x + mora_w / 2, kana_y + PA_KANA_H / 2,
                    FONT_FAMILY, PA_KANA_FS - 2, false,
                    '&HFAF8F2&', AL_SOLID, tostring(pa_morae[mi]))

                -- Red vertical connector at pitch transitions
                if mi > 1 and is_high(mi - 1) ~= high then
                    local vx  = cell_x - PA_GAP
                    local vy1 = over_y
                    local vy2 = under_y + PA_LINE_T
                    rect(bg, vx, vy1, PA_VERT_T, vy2 - vy1, COL_CONN, AL_SOLID)
                end

                -- Odaka trailing drop after last mora
                if mi == n and high and pa_label == '尾' then
                    rect(bg, cell_end, over_y, PA_VERT_T,
                        under_y - over_y + PA_LINE_T, COL_CONN, AL_SOLID)
                end

                cur_x = cur_x + mora_w + PA_GAP
            end

            -- Pattern label to the LEFT of the bar — larger, bold, easy to read
            textc(fg, bar_x - 14, kana_y + PA_KANA_H / 2,
                FONT_FAMILY, 20, true, '&HEED8B0&', AL_SOLID, pa_label or '?')
        end)
        if not ok then dlog('[pitch_accent] render error: ' .. tostring(err_pa)) end
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

    -- ══════════════════════════════════════════════════════════════════════════
    -- ── KANJI BREAKDOWN: SUPER GALAXY DAI-GURREN MODE ─────────────────────────
    -- ══════════════════════════════════════════════════════════════════════════
    -- WHO THE HELL DO YOU THINK WE ARE?!
    local kanji_list = extract_kanji(card.spelling)
    
    -- Color coding by semantic category for MAXIMUM INFORMATION DENSITY
    -- Based on comprehensive linguistic analysis of kanji meanings
    -- Configuration loaded from kanji-semantic-colors.lua
    local function get_kanji_color(meaning)
        local m = meaning:lower()
        -- O(1) exact word check against all keywords
        for word in m:gmatch('%a+') do
            local entry = kanji_color_exact[word]
            if entry then return entry.color, entry.alpha end
        end
        -- Default = State color
        return s_color, '&H00&'
    end
    
    if #kanji_list > 0 and #kanji_list <= 4 then
        -- ═══════════════════════════════════════════════════════════════════
        -- GIGA DRILL BREAKER MODE: Maximum visual impact per kanji
        -- ═══════════════════════════════════════════════════════════════════
        local kanji_count = #kanji_list
        local box_width = math.floor((W - LB - PAD*2 - (kanji_count-1)*6) / kanji_count)
        local box_height = DS.lh_kanji + DS.lh_gloss + 16
        local start_x = px + cx0
        
        for i, k in ipairs(kanji_list) do
            local bx = start_x + (i-1) * (box_width + 6)
            local k_color, k_alpha = get_kanji_color(k.meaning)
            
            -- SPIRAL ENERGY CORE: Multi-layer depth system
            -- Layer 4: Outer glow (furthest)
            rect(bg, bx-5, cy+4, box_width+2, box_height, '&H000000&', '&HF0&')
            -- Layer 3: Deep shadow
            rect(bg, bx-3, cy+3, box_width, box_height, '&H000000&', '&HD0&')
            -- Layer 2: Mid shadow with color tint
            rect(bg, bx-2, cy+2, box_width, box_height, k_color, '&HF8&')
            -- Layer 1: Light shadow
            rect(bg, bx-1, cy+1, box_width, box_height, '&H000000&', '&HA0&')
            
            -- MAIN CARD: Gradient simulation with multiple strips
            rect(bg, bx-4, cy-2, box_width, box_height, DS.bg_header, '&H00&')
            -- Top energy bar (KAMINA'S SPIRIT)
            rect(bg, bx-4, cy-2, box_width, 3, k_color, '&H80&')
            rect(bg, bx-4, cy-2, box_width, 1, k_color, '&H40&')
            -- Side accent lines (SPIRAL POWER FLOW)
            rect(bg, bx-4, cy-2, 2, box_height, k_color, '&HC0&')
            rect(bg, bx+box_width-6, cy-2, 2, box_height, k_color, '&HC0&')
            -- Bottom power gauge
            rect(bg, bx-4, cy+box_height-4, box_width, 3, k_color, '&HA0&')
            
            -- CORNER ACCENTS: Like mecha panel lines
            rect(bg, bx-4, cy-2, 8, 1, k_color, '&H60&')  -- Top-left
            rect(bg, bx+box_width-12, cy-2, 8, 1, k_color, '&H60&')  -- Top-right
            
            -- KANJI: Triple-layer rendering for MAXIMUM DEPTH
            -- Shadow layer (offset)
            textc(fg, bx + box_width/2 + 2, cy + DS.lh_kanji/2 + 4, 
                FONT_FAMILY, DS.fs_kanji-2, true, '&H000000&', '&HC0&', k.kanji)
            -- Glow layer (colored)
            textc(fg, bx + box_width/2 + 1, cy + DS.lh_kanji/2 + 3, 
                FONT_FAMILY, DS.fs_kanji-2, true, k_color, '&H60&', k.kanji)
            -- Main layer (crisp)
            textc(fg, bx + box_width/2, cy + DS.lh_kanji/2 + 2, 
                FONT_FAMILY, DS.fs_kanji-2, true, k_color, '&H00&', k.kanji)
            
            -- MEANING: Dual-layer with background for readability
            local meaning_y = cy + DS.lh_kanji + DS.lh_gloss/2 + 4
            -- Background pill for contrast
            local meaning_width = utf8_len(k.meaning) * 7 + 8
            rect(bg, bx + box_width/2 - meaning_width/2, meaning_y - DS.lh_gloss/2 + 2,
                meaning_width, DS.lh_gloss - 2, k_color, '&HE8&')
            -- Glow text
            textc(fg, bx + box_width/2 + 1, meaning_y + 1,
                FONT_FAMILY, DS.fs_gloss-1, true, k_color, '&HD0&', k.meaning)
            -- Main text
            textc(fg, bx + box_width/2, meaning_y,
                FONT_FAMILY, DS.fs_gloss-1, true, DS.col_primary, '&H00&', k.meaning)
            
            -- COMBINATION ARROW: Showing the fusion sequence
            if i < kanji_count then
                local arrow_x = bx + box_width + 3
                local arrow_y = cy + box_height/2
                -- Arrow glow
                textc(fg, arrow_x + 1, arrow_y + 1,
                    FONT_FAMILY, DS.fs_gloss + 2, true, k_color, '&HC0&', '⟩')
                -- Arrow main
                textc(fg, arrow_x, arrow_y,
                    FONT_FAMILY, DS.fs_gloss + 2, true, k_color, '&H40&', '⟩')
            end
            
            -- POWER LEVEL INDICATOR: Tiny dots showing position
            for dot = 1, kanji_count do
                local dot_x = bx + (dot-1) * 4 + 2
                local dot_y = cy + box_height - 2
                local dot_color = (dot == i) and k_color or '&H808080&'
                local dot_alpha = (dot == i) and '&H40&' or '&HC0&'
                rect(bg, dot_x, dot_y, 2, 2, dot_color, dot_alpha)
            end
        end
        
        cy = cy + box_height + DS.unit
        divider(fg, px+LB+2, cy, W-LB-4)
        cy = cy + DS.divider_h + DS.unit
        
    elseif #kanji_list > 4 and #kanji_list <= 8 then
        -- ═══════════════════════════════════════════════════════════════════
        -- ARC-GURREN LAGANN MODE: Compact grid with color coding
        -- ═══════════════════════════════════════════════════════════════════
        local cols = (#kanji_list <= 6) and 3 or 4
        local box_width = math.floor((W - LB - PAD*2 - (cols-1)*5) / cols)
        local box_height = DS.lh_kanji + DS.lh_gloss + 10
        local start_x = px + cx0
        
        for i, k in ipairs(kanji_list) do
            local row = math.floor((i-1) / cols)
            local col = (i-1) % cols
            local bx = start_x + col * (box_width + 5)
            local by = cy + row * (box_height + 4)
            local k_color, k_alpha = get_kanji_color(k.meaning)
            
            -- Compact card with energy
            rect(bg, bx-2, by+1, box_width, box_height, '&H000000&', '&HC0&')  -- Shadow
            rect(bg, bx-3, by-1, box_width, box_height, DS.bg_header, '&H00&')  -- Main
            rect(bg, bx-3, by-1, box_width, 2, k_color, '&H80&')  -- Top bar
            rect(bg, bx-3, by-1, 1, box_height, k_color, '&HC0&')  -- Left line
            
            -- Kanji with glow
            textc(fg, bx + box_width/2 + 1, by + DS.lh_kanji/2 + 1,
                FONT_FAMILY, DS.fs_kanji-8, true, k_color, '&HC0&', k.kanji)
            textc(fg, bx + box_width/2, by + DS.lh_kanji/2,
                FONT_FAMILY, DS.fs_kanji-8, true, k_color, '&H00&', k.kanji)
            
            -- Meaning with background
            local meaning_y = by + DS.lh_kanji + DS.lh_gloss/2
            textc(fg, bx + box_width/2, meaning_y,
                FONT_FAMILY, DS.fs_gloss-2, false, DS.col_tertiary, '&H00&', k.meaning)
        end
        
        local rows = math.ceil(#kanji_list / cols)
        cy = cy + rows * (box_height + 4) + DS.unit
        divider(fg, px+LB+2, cy, W-LB-4)
        cy = cy + DS.divider_h + DS.unit
        
    elseif #kanji_list > 8 then
        -- ═══════════════════════════════════════════════════════════════════
        -- SUPER TENGEN TOPPA GURREN LAGANN MODE: Galaxy-scale display
        -- ═══════════════════════════════════════════════════════════════════
        local ribbon_height = DS.lh_gloss + 8
        
        -- COSMIC BACKGROUND: Multi-layer energy field
        rect(bg, cx-8, cy+2, W-LB-PAD*2+16, ribbon_height, '&H000000&', '&HE0&')  -- Outer glow
        rect(bg, cx-7, cy-4, W-LB-PAD*2+14, ribbon_height, DS.bg_header, '&H00&')  -- Main field
        
        -- RAINBOW ENERGY STRIPS: Multiple colored accent lines
        local strip_colors = {'&H3333FF&', '&HFF33FF&', '&H33FF33&', '&H3399FF&', '&HFFFF33&'}
        for i, strip_color in ipairs(strip_colors) do
            rect(bg, cx-7, cy-4 + (i-1)*2, W-LB-PAD*2+14, 1, strip_color, '&HB0&')
        end
        
        -- KANJI STREAM: Ultra-dense with color coding
        local parts = {}
        for i, k in ipairs(kanji_list) do
            local k_color = get_kanji_color(k.meaning)
            local short_meaning = k.meaning:sub(1,3)
            parts[#parts + 1] = k.kanji .. '·' .. short_meaning
        end
        local cosmic_line = table.concat(parts, ' ')
        
        -- Triple-layer text for COSMIC DEPTH
        text(fg, cx+2, cy+2, FONT_FAMILY, DS.fs_gloss, false, '&H000000&', '&HE0&', cosmic_line)  -- Deep shadow
        text(fg, cx+1, cy+1, FONT_FAMILY, DS.fs_gloss, false, s_color, '&H80&', cosmic_line)  -- Glow
        text(fg, cx, cy, FONT_FAMILY, DS.fs_gloss, true, DS.col_primary, '&H00&', cosmic_line)  -- Main
        
        cy = cy + ribbon_height + DS.unit
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
    -- Always advance `cy` so button position doesn't shift, but only draw text if visible
    cy = cy + DS.unit
    if popup_toast_text then
        local tcol = popup_toast_ok and DS.col_toast_ok or DS.col_toast_err
        textc(fg, px + W/2, cy + DS.lh_toast/2,
            FONT_FAMILY, DS.fs_toast, true, tcol, '&H00&', popup_toast_text)
    end
    cy = cy + DS.lh_toast

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

    -- ── Action row - Replay | Never Forget | Audio ───────────────────────────
    local never_forgot = false
    for _, s in ipairs(card.state) do
        if s == 'never-forget' then never_forgot = true end
    end

    -- Symmetrical layout: Never Forget (50%) | gap | Replay (25%) | gap | Audio (25%)
    local total_w = W - LB - PAD * 2
    local gap = 6
    local side_w = math.floor((total_w - gap * 2) * 0.25)
    local center_w = total_w - (side_w * 2 + gap * 2)

    local bx = px + cx0
    btn(never_forgot and '★ Remove' or '★ Never Forget',
        'never-forget', 'set-flag', { flag='never-forget', state=not never_forgot }, 
        bx, cy, center_w, DS.bh_action)
    bx = bx + center_w + gap
    btn('⟲ Replay', 'replay', 'replay-scene', {}, bx, cy, side_w, DS.bh_action, DS.fs_btn_act - 2)
    bx = bx + side_w + gap
    btn('🔊 Audio', 'audio', 'play-audio', {}, bx, cy, side_w, DS.bh_action, DS.fs_btn_act - 2)
    cy = cy + DS.bh_action + gap

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
    last_popup_render_key = render_key
end


-- ─── Hit testing──────────────────────────────────────────────────────────────

local function find_hovered_token(mx, my)
    -- Primary: direct token-boundary matching using compute_bounds measurements.
    -- Each token's pixel boundaries were measured by libass itself, so matching
    -- is exact — no font-metric approximation or scale conversion needed.
    for _, ld in ipairs(subtitle_line_data) do
        if my >= ld.y1 and my <= ld.y2 then
            local line_left  = ld.actual_x0 or (osd_w / 2 - (ld.actual_total or 0) / 2)
            local line_width = ld.actual_total or 0

            -- Mouse offset from line start (screen space)
            local px_offset = mx - line_left
            if px_offset < -(BORD_W + 10) or px_offset > line_width + BORD_W + 10 then
                -- Outside this line — try next
            else
                px_offset = math.max(0, math.min(px_offset, line_width))

                if ld.token_regions and #ld.token_regions > 0 then
                    -- Exact match: check measured token pixel ranges
                    local best, best_span = nil, math.huge
                    for _, tr in ipairs(ld.token_regions) do
                        if px_offset >= tr.px0 and px_offset < tr.px1 then
                            local span = tr.tok['end'] - tr.tok.start
                            if span < best_span then
                                best = tr.tok; best_span = span
                            end
                        end
                    end
                    if best then return best end

                    -- Gap fallback: snap to nearest token by pixel distance
                    local nearest, nearest_dist = nil, math.huge
                    for _, tr in ipairs(ld.token_regions) do
                        local center = (tr.px0 + tr.px1) / 2
                        local dist = math.abs(px_offset - center)
                        if dist < nearest_dist then
                            nearest_dist = dist; nearest = tr.tok
                        end
                    end
                    if nearest and nearest_dist < 40 then return nearest end
                end
            end
        end
    end

    -- Fallback: region-based proximity search for edge cases
    -- (e.g., mouse slightly outside computed line bounds)
    local best_fb, best_fb_dist = nil, math.huge
    for _, r in ipairs(subtitle_regions) do
        if my >= r.y1 - 6 and my <= r.y2 + 6 then
            local cx = (r.x1 + r.x2) / 2
            local cy = (r.y1 + r.y2) / 2
            local dx = math.abs(mx - cx)
            local dy = math.abs(my - cy)
            -- Only consider tokens reasonably close (within 40px horizontally)
            if dx <= 40 then
                local dist = dx + dy * 2  -- weight Y distance higher
                if dist < best_fb_dist then
                    best_fb_dist = dist; best_fb = r.token
                end
            end
        end
    end
    return best_fb
end

local function find_hovered_button(mx, my)
    for _, b in ipairs(popup_buttons) do
        if mx >= b.x1 and mx <= b.x2 and my >= b.y1 and my <= b.y2 then
            return b
        end
    end
end


-- Extract server-measured pixel map from parse response.
-- The px_map comes as an array of [byte_pos, cumulative_px] pairs.
-- We convert it to a Lua table keyed by byte_pos for O(1) lookup.
local function extract_px_map(res)
    if not res or not res.px_map then
        dlog('[extract_px_map] No px_map in server response — using estimated widths')
        return nil
    end
    local map = {}
    local count = 0
    for _, entry in ipairs(res.px_map) do
        local byte_pos = math.floor(entry[1])
        local px_val   = entry[2]
        map[byte_pos] = px_val
        count = count + 1
    end
    local last = res.px_map[count]
    dlog('[extract_px_map] Got ' .. count .. ' entries, total_px=' ..
         string.format('%.1f', last and last[2] or 0))
    return map
end

-- ─── Actions ──────────────────────────────────────────────────────────────────

local function refresh_after_action()
    dlog('[refresh_after_action] Starting refresh...')
    http_request_async('POST', '/parse',
        { text = current_text, font_size = SUB_CONF.font_size },
        function(res, err)
        if err or not (res and res.tokens) then 
            dlog('[refresh_after_action] Error or no tokens')
            return 
        end
        dlog('[refresh_after_action] Got ' .. #res.tokens .. ' tokens')
        current_tokens      = res.tokens
        current_px_map      = extract_px_map(res)
        cached_sub_ass      = nil
        cached_sub_token_id = nil
        cached_sub_regions  = nil
        cached_sub_line_data = nil
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

local last_audio_time = 0

local function do_play_audio(card)
    local now = mp.get_time()
    if now - last_audio_time < 1.0 then return end
    last_audio_time = now

    local vid, sid = card.vid, card.sid
    if vid and sid then
        local sp = url_encode(card.spelling or '')
        local rd = url_encode(card.reading or '')
        local url = SERVER_URL .. '/word-audio?vid=' .. tostring(vid) .. '&spelling=' .. sp .. '&reading=' .. rd
        mp.command_native_async({
            name = 'subprocess',
            args = {'mpv', '--no-video', '--really-quiet', '--volume=70', url},
            detach = true,
            playback_only = false
        }, function() end)
        show_popup_toast('🔊 Playing audio: ' .. card.reading, true)
    else
        show_popup_toast('✕ No audio available', false)
    end
end

local function do_replay_scene()
    local start_time = mp.get_property_number('sub-start')
    local end_time = mp.get_property_number('sub-end')
    
    if start_time and end_time then
        -- Seek back with 0.3s lead-in
        mp.commandv('seek', math.max(0, start_time - 0.3), 'absolute+exact')
        mp.set_property_bool('pause', false)
        
        -- Timeout must account for the whole duration + lead-in + extra padding at end to let trailing audio finish
        local wait_time = (end_time - start_time) + 0.3 + 0.8
        mp.add_timeout(math.max(0.1, wait_time), function()
            -- Pause, then warp back slightly before the sub ends to remain locked onto the current subtitle
            mp.set_property_bool('pause', true)
            mp.commandv('seek', math.max(0, end_time - 0.1), 'absolute+exact')
        end)
        show_popup_toast('⟲ Replaying scene', true)
    else
        show_popup_toast('✕ Subtitle timing not found', false)
    end
end

local function dispatch_button(b)
    if not popup_token then return end
    local card = popup_token.card
    if     b.action == 'review'       then do_review(card, b.args.rating)
    elseif b.action == 'mine'         then do_mine(card, current_text)
    elseif b.action == 'set-flag'     then do_set_flag(card, b.args.flag, b.args.state)
    elseif b.action == 'play-audio'   then do_play_audio(card)
    elseif b.action == 'replay-scene' then do_replay_scene()
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
    subtitle_line_data  = {}
    cached_sub_ass      = nil
    cached_sub_token_id = nil
    cached_sub_regions  = nil
    cached_sub_line_data = nil
    bounds_cache        = {}
    kanji_extract_cache = {}
    last_popup_render_key = nil
    render_popup()

    if not new_text or new_text == '' then
        current_text = ''; current_tokens = {}; current_px_map = nil
        render_subtitles(); return
    end

    current_text = new_text
    if parse_timer then parse_timer:kill() end
    parse_timer = mp.add_timeout(0.08, function()
        parse_timer = nil
        if current_text ~= new_text then return end
        http_request_async('POST', '/parse',
            { text = new_text, font_size = SUB_CONF.font_size },
            function(res, err)
            if current_text ~= new_text or err then return end
            if res and res.tokens then
                current_tokens      = res.tokens
                current_px_map      = extract_px_map(res)
                cached_sub_ass      = nil
                cached_sub_token_id = nil
                cached_sub_regions  = nil
                cached_sub_line_data = nil
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
    last_popup_render_key = nil
    if popup_toast_timer then popup_toast_timer:kill(); popup_toast_timer = nil end
    if hover_debounce_timer then hover_debounce_timer:kill(); hover_debounce_timer = nil end
    hover_pending_token = nil
    cached_sub_ass      = nil
    cached_sub_token_id = nil
    cached_sub_regions  = nil
    cached_sub_line_data = nil
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
        -- Transform raw window pixels → OSD coordinate space
        local mx, my = screen_to_osd(hover_x, hover_y)

        -- 1. Popup safe-zone ──────────────────────────────────────────────────
        if popup_visible and popup_rect then
            local pad_x, pad_y = 14, 12
            if mx >= popup_rect.x1 - pad_x and mx <= popup_rect.x2 + pad_x and
               my >= popup_rect.y1 - pad_y and my <= popup_rect.y2 + pad_y then
                if hover_debounce_timer then
                    hover_debounce_timer:kill(); hover_debounce_timer = nil
                end
                hover_pending_token = nil
                -- Keep hovered_token set to popup_token so subtitle stays visible
                if popup_token and hovered_token ~= popup_token then
                    hovered_token = popup_token
                    cached_sub_ass = nil
                    cached_sub_token_id = nil
                    cached_sub_regions = nil
                    cached_sub_line_data = nil
                    render_subtitles()
                end
                local hit = find_hovered_button(mx, my)
                local nk  = hit and hit.key or nil
                if nk ~= hovered_button then
                    hovered_button = nk; render_popup()
                end
                return
            end

            -- 1b. Bridge corridor: if popup is above subtitles, create a
            -- vertical corridor between popup bottom and subtitle top so
            -- the cursor can travel between them without triggering close.
            local layout_bridge = subtitle_layout()
            local sub_top = layout_bridge.sub_text_top
            if popup_rect.y2 < sub_top and
               my >= popup_rect.y2 and my <= sub_top + 10 and
               mx >= popup_rect.x1 - 20 and mx <= popup_rect.x2 + 20 then
                -- In the bridge: don't close, don't change anything
                return
            end
        end

        -- 2. Subtitle interaction zone guard ──────────────────────────────────
        -- Tighter zone: only the popup height above the subtitle top, plus
        -- a modest buffer below for descenders.
        local layout  = subtitle_layout()
        local popup_h = (popup_rect and (popup_rect.y2 - popup_rect.y1)) or 0
        local zone_y1 = math.max(0, layout.sub_text_top - popup_h - 40)
        local zone_y2 = layout.sub_y + 30
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
                    cached_sub_regions  = nil
                    cached_sub_line_data = nil
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
        local cmx, cmy = screen_to_osd(hover_x, hover_y)
        local b = find_hovered_button(cmx, cmy)
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
                cached_sub_regions = nil
                cached_sub_line_data = nil
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


-- ─── Width scale calibration ──────────────────────────────────────────────────
-- Press Ctrl+= / Ctrl+- to adjust width_scale in real-time.
-- This compensates for the difference between our font metrics and libass's.
-- Once you find a value that makes hover accurate, set it in jpdb-config.lua.

local function adjust_width_scale(delta)
    SUB_CONF.width_scale = math.max(0.80, math.min(1.20,
        (SUB_CONF.width_scale or 1.0) + delta))
    -- Clear caches to force re-render with new scale
    cached_sub_ass = nil
    cached_sub_token_id = nil
    cached_sub_regions = nil
    cached_sub_line_data = nil
    render_subtitles()
    mp.osd_message(string.format('width_scale = %.3f', SUB_CONF.width_scale), 2)
end

mp.add_key_binding('ctrl+=', 'jpdb-scale-up',   function() adjust_width_scale(0.005) end)
mp.add_key_binding('ctrl+-', 'jpdb-scale-down', function() adjust_width_scale(-0.005) end)


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

local function debounced_resize_render()
    if resize_timer then resize_timer:kill() end
    resize_timer = mp.add_timeout(0.05, function()
        resize_timer = nil
        cached_sub_ass = nil
        cached_sub_token_id = nil
        cached_sub_regions = nil
        cached_sub_line_data = nil
        bounds_cache = {}
        last_popup_render_key = nil
        render_subtitles()
        render_popup()
    end)
end

mp.observe_property('osd-width', 'number', function(_, w)
    if w and w > 0 then osd_w = w end
    if sub_osd   then sub_osd.res_x   = osd_w end
    if popup_osd then popup_osd.res_x = osd_w end
    debounced_resize_render()
end)

mp.observe_property('osd-height', 'number', function(_, h)
    if h and h > 0 then osd_h = h end
    if sub_osd   then sub_osd.res_y   = osd_h end
    if popup_osd then popup_osd.res_y = osd_h end
    debounced_resize_render()
end)

-- Track actual window dimensions for mouse coordinate scaling.
-- osd-dimensions gives the real pixel size of the OSD area;
-- mouse-pos returns coordinates in this space.
mp.observe_property('osd-dimensions', 'native', function(_, dim)
    if dim then
        if dim.w and dim.w > 0 then screen_w = dim.w end
        if dim.h and dim.h > 0 then screen_h = dim.h end
        dlog('[osd-dimensions] screen=' .. screen_w .. 'x' .. screen_h
             .. ' osd=' .. osd_w .. 'x' .. osd_h)
    end
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