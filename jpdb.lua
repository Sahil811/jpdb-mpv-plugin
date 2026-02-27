--[[
    jpdb.lua — JPDB MPV Plugin  (UI/UX v2 — Google-level redesign)

    Features:
    - Color-coded Japanese subtitles based on jpdb vocabulary state
    - Interactive hover popup with word details (inside mpv, no browser)
    - Clickable review buttons: Nothing / Something / Hard / Good / Easy
    - Mine buttons: Add to deck, Blacklist, Never Forget
    - Keyboard shortcuts for all actions

    Requirements:
    - server.js must be running: `node server.js`
    - config.json must have your jpdb API token set

    Install: copy this file to your mpv scripts directory
      Windows: %APPDATA%\mpv\scripts\jpdb.lua
]]

local mp         = require('mp')
local msg        = mp.msg
local assdraw    = require('mp.assdraw')
local utils      = require('mp.utils')

-- ─── Debug log ───────────────────────────────────────────────────────────────
local LOG_PATH = 'D:/scripts/jpdb-mpv-plugin/jpdb-debug.log'

local log_file = io.open(LOG_PATH, 'w')
if log_file then
    log_file:write('=== jpdb.lua started ' .. os.date('%Y-%m-%dT%H:%M:%S') .. ' ===\n')
    log_file:flush()
end

local function dlog(...)
    local parts = {}
    for _, v in ipairs({...}) do
        table.insert(parts, tostring(v))
    end
    local line = '[' .. os.date('%H:%M:%S') .. '] ' .. table.concat(parts, ' ') .. '\n'
    if log_file then
        log_file:write(line)
        log_file:flush()
    end
    msg.info(table.concat(parts, ' '))
end

mp.add_timeout(0.5, function()
    mp.osd_message('[jpdb] Plugin loaded! server.js must be running.', 4)
end)

local SERVER_URL   = 'http://127.0.0.1:9726'
local FONT_FAMILY  = 'Yu Gothic UI'

-- ══════════════════════════════════════════════════════════════════════════════
-- ─── Design System (Google Material You / dark video aesthetic) ───────────────
-- ══════════════════════════════════════════════════════════════════════════════
--
--  All colors are ASS BGR hex: &HBBGGRR&
--  Distances are in OSD units (1:1 pixel at default res)
--
--  Elevation model:
--    bg_base    (#0D0D14) — deepest background
--    bg_surface (#13131E) — popup panel surface
--    bg_header  (#1A1A28) — header band (slightly lifted)
--    bg_divider (#2A2A3E) — hairline dividers
--    bg_btn     (#22223A) — neutral button resting
--    bg_btn_hov (#30305A) — neutral button hover (4dp ripple tone)
--
--  Typography scale (fs):
--    fs_kanji   60   bold   — primary word display
--    fs_reading 26   normal — furigana / reading
--    fs_pos     15   normal — part-of-speech chip
--    fs_gloss   24   normal — English meaning
--    fs_meta    16   normal — freq rank, state badges
--    fs_btn     17   normal — button labels
--
--  Spacing grid: 8px base unit
--    PAD_H  = 20   horizontal inner padding
--    PAD_V  = 16   vertical inner padding (top/bottom)
--    UNIT   = 8    grid unit

local DS = {
    -- Popup geometry
    width       = 540,
    radius      = 0,      -- ASS doesn't support rounded corners natively
    lbar_w      = 6,      -- left accent bar (thinner, more refined)
    pad_h       = 20,     -- horizontal inner content padding
    pad_v       = 16,     -- vertical top/bottom padding
    unit        = 8,      -- grid unit

    -- Elevation colors (BGR)
    bg_base     = '&H14130D&',   -- deep navy-black
    bg_surface  = '&H1E1E13&',   -- card surface
    bg_header   = '&H281E1A&',   -- header tint (warm)
    bg_divider  = '&H3E3028&',   -- hairline
    shadow_col  = '&H000000&',
    shadow_al   = '&HA0&',

    -- Button palette (BGR)
    btn_neutral    = { bg = '&H302820&', hov = '&H484030&' },
    btn_add        = { bg = '&H28382A&', hov = '&H3C5040&' },
    btn_blacklist  = { bg = '&H28202A&', hov = '&H443040&' },
    btn_nf         = { bg = '&H20382A&', hov = '&H305040&' },
    btn_nothing    = { bg = '&H20207A&', hov = '&H3030A0&' },  -- deep red
    btn_something  = { bg = '&H18408A&', hov = '&H2858B0&' },  -- orange
    btn_hard       = { bg = '&H287898&', hov = '&H389AB8&' },  -- amber-teal
    btn_good       = { bg = '&H207030&', hov = '&H309048&' },  -- green
    btn_easy       = { bg = '&H704818&', hov = '&H906228&' },  -- purple-gold

    -- Text colors (BGR)
    col_white   = '&HFFFFFF&',
    col_dim     = '&HBBBBCC&',   -- reading / secondary
    col_muted   = '&H9999AA&',   -- meta labels
    col_chip    = '&H8899BB&',   -- POS chip text
    col_freq    = '&H7788AA&',   -- frequency label
    col_divider = '&H5A5A78&',
    col_shadow  = '&H000000&',

    -- Typography
    fs_kanji    = 56,
    fs_reading  = 26,
    fs_pos      = 15,
    fs_gloss    = 23,
    fs_meta     = 16,
    fs_btn_act  = 16,   -- action row button label
    fs_btn_rev  = 17,   -- review row button label
    fs_shortcut = 13,   -- keyboard shortcut hint

    -- Button heights (multiples of unit)
    bh_action   = 36,   -- action row (Add/Blacklist/NF)
    bh_review   = 44,   -- review row (Nothing…Easy)
    btn_gap     = 6,    -- gap between buttons

    -- Line heights
    lh_kanji    = 64,
    lh_reading  = 32,
    lh_pos      = 22,
    lh_gloss    = 30,   -- per wrapped gloss line
    lh_meta     = 22,
    lh_badge    = 24,

    -- Divider height
    divider_h   = 1,
}

-- Card state → ASS color (BGR)
local STATE_COLORS = {
    ['known']       = '&H50C878&',   -- emerald green
    ['never-forget']= '&H50C878&',   -- emerald green
    ['learning']    = '&H78C8A0&',   -- mint teal
    ['new']         = '&HE8A050&',   -- warm blue-ish (actually amber in RGB)
    ['not-in-deck'] = '&HE8A050&',   -- amber (with alpha)
    ['due']         = '&H3060FF&',   -- vivid red-orange
    ['failed']      = '&H2020EE&',   -- vivid red
    ['locked']      = '&H888898&',   -- cool gray
    ['suspended']   = '&H888898&',
    ['blacklisted'] = '&H888898&',
    ['redundant']   = '&HAAAABC&',   -- lighter gray
}

local STATE_ALPHA = {
    ['not-in-deck'] = '&H88&',
}

-- State → short human label for badge
local STATE_LABELS = {
    ['known']        = 'Known',
    ['never-forget'] = 'Never Forget',
    ['learning']     = 'Learning',
    ['new']          = 'New',
    ['not-in-deck']  = 'Not in Deck',
    ['due']          = 'Due',
    ['failed']       = 'Failed',
    ['locked']       = 'Locked',
    ['suspended']    = 'Suspended',
    ['blacklisted']  = 'Blacklisted',
    ['redundant']    = 'Redundant',
}

-- ─── State ──────────────────────────────────────────────────────────────────

local current_tokens   = {}
local current_text     = ''
local last_parsed_text = nil
local hovered_token    = nil
local hover_x          = 0
local hover_y          = 0
local subtitle_regions = {}
local jpdb_did_pause   = false

local popup_visible    = false
local popup_token      = nil
local popup_osd        = nil
local sub_osd          = nil
local popup_buttons    = {}
local hovered_button   = nil

local osd_w = 1280
local osd_h = 720

-- ─── HTTP helpers ───────────────────────────────────────────────────────────

local function http_request(method, path, body_table)
    local body_json = body_table and utils.format_json(body_table) or ''
    local args = {
        'curl', '-s', '-X', method,
        '--max-time', '8',
        '-H', 'Content-Type: application/json',
        SERVER_URL .. path,
    }
    if body_json ~= '' then
        table.insert(args, '-d')
        table.insert(args, body_json)
    end
    local res = mp.command_native({
        name = 'subprocess', args = args,
        capture_stdout = true, capture_stderr = true, playback_only = false,
    })
    dlog('http_request ' .. method .. ' ' .. path .. ' status=' .. tostring(res and res.status))
    if res.status ~= 0 then
        msg.error(string.format('[jpdb] curl failed (%d): %s', res.status, res.stderr or ''))
        return nil, 'curl failed: ' .. (res.stderr or 'unknown error')
    end
    local ok, data = pcall(utils.parse_json, res.stdout)
    if not ok or data == nil then
        msg.error('[jpdb] Failed to parse server response: ' .. (res.stdout or ''))
        return nil, 'bad JSON response'
    end
    if data.error then return nil, data.error end
    return data, nil
end

local function http_request_async(method, path, body_table, on_done)
    local body_json = body_table and utils.format_json(body_table) or ''
    local args = {
        'curl', '-s', '-X', method,
        '--max-time', '15',
        '-H', 'Content-Type: application/json',
        SERVER_URL .. path,
    }
    if body_json ~= '' then
        table.insert(args, '-d')
        table.insert(args, body_json)
    end
    mp.command_native_async({
        name = 'subprocess', args = args,
        capture_stdout = true, capture_stderr = true, playback_only = false,
    }, function(success, res, err)
        if not success or res.status ~= 0 then
            msg.error('[jpdb] Async request failed: ' .. (err or (res and res.stderr) or 'unknown'))
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

-- ─── UTF-8 character utilities ───────────────────────────────────────────────

local function utf8_len(s)
    local n, i = 0, 1
    while i <= #s do
        local b = s:byte(i)
        if b < 0x80 then i = i + 1
        elseif b < 0xE0 then i = i + 2
        elseif b < 0xF0 then i = i + 3
        else i = i + 4 end
        n = n + 1
    end
    return n
end

local function utf8_byte_to_char(s, byte_pos)
    local n, i = 0, 1
    while i <= byte_pos do
        local b = s:byte(i)
        if b < 0x80 then i = i + 1
        elseif b < 0xE0 then i = i + 2
        elseif b < 0xF0 then i = i + 3
        else i = i + 4 end
        n = n + 1
    end
    return n
end

local function split_text_lines(text)
    local result = {}
    local i = 1
    local line_start = 1
    local chars_before = 0
    while i <= #text do
        local b = text:byte(i)
        if b == 10 then
            local line_text = text:sub(line_start, i - 1)
            table.insert(result, {
                text         = line_text,
                byte_start   = line_start - 1,
                chars_before = chars_before,
            })
            chars_before = chars_before + utf8_len(line_text) + 1
            line_start = i + 1
            i = i + 1
        else
            if b < 0x80 then i = i + 1
            elseif b < 0xE0 then i = i + 2
            elseif b < 0xF0 then i = i + 3
            else i = i + 4 end
        end
    end
    local line_text = text:sub(line_start)
    table.insert(result, {
        text         = line_text,
        byte_start   = line_start - 1,
        chars_before = chars_before,
    })
    return result
end

-- ─── ASS helpers ────────────────────────────────────────────────────────────

local function ass_escape(s)
    if not s then return '' end
    return s:gsub('\\', '\\\\'):gsub('{', '\\{'):gsub('}', '\\}'):gsub('\n', '\\N')
end

-- Inline rectangle via \p1 drawing (no assdraw needed, faster)
local function ass_rect(events, x, y, w, h, color, alpha)
    if w <= 0 or h <= 0 then return end
    table.insert(events, string.format(
        '{\\an7\\pos(%d,%d)\\bord0\\shad0\\1c%s\\1a%s\\p1}m 0 0 l %d 0 %d %d 0 %d{\\p0}',
        x, y, color, alpha, w, w, h, h))
end

-- Thin separator line with gradient-like soft edges (two overlapping rects)
local function ass_divider(events, x, y, w)
    ass_rect(events, x, y, w, 1, DS.bg_divider, '&H00&')
end

local function ass_text(events, x, y, font, size, bold, color, alpha, text)
    table.insert(events, string.format(
        '{\\an7\\pos(%d,%d)\\fn%s\\fs%d\\b%d\\bord0\\shad0\\1c%s\\1a%s}%s',
        x, y, font, size, bold and 1 or 0, color, alpha, ass_escape(text)))
end

local function ass_text_center(events, cx, cy, font, size, bold, color, alpha, text)
    table.insert(events, string.format(
        '{\\an5\\pos(%d,%d)\\fn%s\\fs%d\\b%d\\bord0\\shad0\\1c%s\\1a%s}%s',
        cx, cy, font, size, bold and 1 or 0, color, alpha, ass_escape(text)))
end

-- ─── Get primary token state ─────────────────────────────────────────────────

local function get_primary_state(card_state)
    if not card_state or #card_state == 0 then return 'not-in-deck' end
    for _, s in ipairs(card_state) do
        if STATE_COLORS[s] then return s end
    end
    return card_state[1] or 'not-in-deck'
end

-- ─── Subtitle overlay ───────────────────────────────────────────────────────

local function build_subtitle_ass(tokens, raw_text)
    if not tokens or #tokens == 0 then return nil end
    local parts = {}
    local last  = 0
    table.sort(tokens, function(a, b) return a.start < b.start end)

    for _, tok in ipairs(tokens) do
        if tok.start > last then
            local pre = raw_text:sub(last + 1, tok.start)
            table.insert(parts, '{\\c&HFFFFFF&\\1a&H00&}' .. ass_escape(pre))
        end
        local state = get_primary_state(tok.card.state)
        local color = STATE_COLORS[state] or '&HFFFFFF&'
        local alpha = STATE_ALPHA[state]  or '&H00&'
        local tags  = '{\\c' .. color .. '\\1a' .. alpha
        if tok == hovered_token then
            -- Use underline + slight brightness boost tag for hover
            tags = tags .. '\\u1'
        end
        tags = tags .. '}'
        local text_part = raw_text:sub(tok.start + 1, tok['end'])
        table.insert(parts, tags .. ass_escape(text_part))
        last = tok['end']
    end

    if last < #raw_text then
        table.insert(parts, '{\\c&HFFFFFF&\\1a&H00&}' .. ass_escape(raw_text:sub(last + 1)))
    end
    return table.concat(parts)
end

local CHAR_PX     = 48
local LINE_HEIGHT = 58

local function subtitle_layout()
    local sub_y = osd_h - 100
    local lines = split_text_lines(current_text)
    local n     = #lines
    local sub_text_top = sub_y - n * LINE_HEIGHT
    return { n = n, sub_y = sub_y, sub_text_top = sub_text_top, lines = lines }
end

local function render_subtitles()
    if not sub_osd then return end
    subtitle_regions = {}
    if #current_tokens == 0 then
        sub_osd.data = ''
        sub_osd:update()
        return
    end
    local ass_content = build_subtitle_ass(current_tokens, current_text)
    if not ass_content then
        sub_osd.data = ''
        sub_osd:update()
        return
    end
    local layout = subtitle_layout()
    local sub_x  = math.floor(osd_w / 2)
    for line_idx, ln in ipairs(layout.lines) do
        local from_bottom = layout.n - line_idx
        local line_bottom = layout.sub_y - from_bottom * LINE_HEIGHT
        local y1 = line_bottom - CHAR_PX - 6
        local y2 = line_bottom + 10
        local line_nch  = utf8_len(ln.text)
        local line_w    = line_nch * CHAR_PX
        local line_left = sub_x - line_w / 2
        local line_byte_start = ln.byte_start
        local line_byte_end   = ln.byte_start + #ln.text
        for _, tok in ipairs(current_tokens) do
            if tok.start >= line_byte_start and tok['end'] <= line_byte_end + 1 then
                local ci_start = utf8_byte_to_char(current_text, tok.start) - ln.chars_before
                local ci_end   = utf8_byte_to_char(current_text, tok['end']) - ln.chars_before
                local x1 = math.floor(line_left + ci_start * CHAR_PX)
                local x2 = math.floor(line_left + ci_end   * CHAR_PX)
                table.insert(subtitle_regions, { x1=x1, x2=x2, y1=y1, y2=y2, token=tok })
            end
        end
    end
    dlog(string.format('regions=%d lines=%d sub_y=%d osd=%dx%d',
        #subtitle_regions, layout.n, layout.sub_y, osd_w, osd_h))
    local a = assdraw.ass_new()
    a:new_event()
    a:append('{\\an2')
    a:append('\\pos(' .. sub_x .. ',' .. layout.sub_y .. ')')
    a:append('\\fs48')
    a:append('\\bord2')
    a:append('\\shad1')
    a:append('\\b0}')
    a:append(ass_content)
    sub_osd.data = a.text
    sub_osd:update()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ─── POPUP RENDERING  ─────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local PARTS_OF_SPEECH = {
    n = 'Noun', pn = 'Pronoun', pref = 'Prefix', suf = 'Suffix',
    name = 'Name', ['name-fem'] = 'Feminine Name', ['name-male'] = 'Masculine Name',
    ['name-surname'] = 'Surname', ['name-person'] = 'Personal Name',
    ['name-place'] = 'Place Name', ['name-company'] = 'Company Name',
    ['adj-i'] = 'い-Adjective', ['adj-na'] = 'な-Adjective', ['adj-no'] = 'の-Adjective',
    ['adj-pn'] = 'Adjectival', adv = 'Adverb',
    aux = 'Auxiliary', ['aux-v'] = 'Auxiliary Verb', ['aux-adj'] = 'Auxiliary Adjective',
    conj = 'Conjunction', cop = 'Copula', ctr = 'Counter',
    exp = 'Expression', int = 'Interjection', num = 'Numeric', prt = 'Particle',
    vt = 'Transitive Verb', vi = 'Intransitive Verb',
    v1 = 'Ichidan Verb', v5 = 'Godan Verb', vk = 'Irregular Verb (くる)',
    vs = 'する Verb', vz = 'ずる Verb',
}

local function get_pos_label(pos_list)
    if not pos_list or #pos_list == 0 then return '' end
    local labels = {}
    for _, p in ipairs(pos_list) do
        table.insert(labels, PARTS_OF_SPEECH[p] or p)
    end
    return table.concat(labels, ' · ')
end

-- Simple greedy word-wrap (English text, split on spaces)
local function wrap_text(text, max_chars)
    local lines = {}
    local cur = {}
    local cur_len = 0
    for word in text:gmatch('%S+') do
        local wl = utf8_len(word)
        if cur_len > 0 and cur_len + 1 + wl > max_chars then
            table.insert(lines, table.concat(cur, ' '))
            cur = { word }
            cur_len = wl
        else
            table.insert(cur, word)
            cur_len = cur_len + (cur_len > 0 and 1 or 0) + wl
        end
    end
    if #cur > 0 then
        table.insert(lines, table.concat(cur, ' '))
    end
    return lines
end

-- Button color map
local BTN_MAP = {
    add            = DS.btn_add,
    blacklist      = DS.btn_blacklist,
    ['never-forget'] = DS.btn_nf,
    nothing        = DS.btn_nothing,
    something      = DS.btn_something,
    hard           = DS.btn_hard,
    good           = DS.btn_good,
    easy           = DS.btn_easy,
}

-- ─── Keyboard shortcut labels for review buttons ─────────────────────────────
local BTN_SHORTCUTS = {
    nothing = '1', something = '2', hard = '3', good = '4', easy = '5',
    add = 'A', blacklist = 'B', ['never-forget'] = 'N',
}

-- ─────────────────────────────────────────────────────────────────────────────

local function render_popup()
    if not popup_osd then return end
    if not popup_visible or not popup_token then
        popup_osd.data = ''
        popup_osd:update()
        return
    end

    popup_buttons = {}

    local card    = popup_token.card
    local state   = get_primary_state(card.state)
    local s_color = STATE_COLORS[state] or '&HFFFFFF&'

    local W      = DS.width
    local LB     = DS.lbar_w
    local PAD    = DS.pad_h
    local content_x = LB + PAD     -- left edge of text content

    -- ── WRAP CONFIG ──────────────────────────────────────────────────────
    -- At fs23 over (540 - 6 - 40) = 494px, roughly 42 chars fit
    local WRAP_CHARS = 42

    -- ── PASS 1: measure total height ─────────────────────────────────────
    local function measure_h()
        local h = DS.pad_v                  -- top padding

        h = h + DS.lh_kanji                -- kanji line
        if card.spelling ~= card.reading then
            h = h + DS.lh_reading           -- reading line
        end

        -- State badges + frequency on same row
        h = h + DS.lh_badge

        h = h + DS.unit                     -- gap after header meta

        -- Hairline divider
        h = h + DS.divider_h + DS.unit

        -- Meanings
        local shown, last_pos = 0, nil
        for _, m in ipairs(card.meanings or {}) do
            if shown >= 6 then break end
            local pl = get_pos_label(m.partOfSpeech)
            if pl ~= '' and pl ~= last_pos then
                h = h + DS.lh_pos           -- POS chip
                last_pos = pl
            end
            local gloss = table.concat(m.glosses or {}, '; ')
            local lines = wrap_text(gloss, WRAP_CHARS)
            h = h + #lines * DS.lh_gloss
            shown = shown + 1
        end

        h = h + DS.unit * 2                 -- breathe before buttons

        -- Hairline divider before buttons
        h = h + DS.divider_h + DS.unit

        -- Action row + review row
        h = h + DS.bh_action + DS.btn_gap
        h = h + DS.bh_review

        h = h + DS.pad_v                    -- bottom padding
        return h
    end

    local total_h = measure_h()

    -- ── COMPUTE POSITION ─────────────────────────────────────────────────
    -- Popup sits just above the subtitle block; never clips screen edges
    local layout = subtitle_layout()
    local py = math.max(8, layout.sub_text_top - DS.unit - total_h)

    -- Center on the hovered word
    local tok_cx = hover_x
    for _, region in ipairs(subtitle_regions) do
        if region.token == popup_token then
            tok_cx = (region.x1 + region.x2) / 2
            break
        end
    end
    local px = math.max(8, math.min(tok_cx - W / 2, osd_w - W - 8))

    -- ── PASS 2: draw ─────────────────────────────────────────────────────
    local bg_ev  = {}   -- drawn first (behind content)
    local fg_ev  = {}   -- drawn on top

    -- ── Drop shadow (two-layer for soft effect) ───────────────────────────
    ass_rect(bg_ev, px + 6, py + 8, W, total_h, DS.shadow_col, '&HCC&')
    ass_rect(bg_ev, px + 3, py + 4, W, total_h, DS.shadow_col, '&H88&')

    -- ── Main surface ─────────────────────────────────────────────────────
    ass_rect(bg_ev, px, py, W, total_h, DS.bg_surface, '&H00&')

    -- ── Left accent bar (card-state color) ───────────────────────────────
    ass_rect(bg_ev, px, py, LB, total_h, s_color, '&H00&')

    -- ── Top border hairline ───────────────────────────────────────────────
    ass_rect(bg_ev, px + LB, py, W - LB, 1, s_color, '&HC0&')

    -- ── Header band (slightly lifted background) ──────────────────────────
    local header_h = DS.pad_v + DS.lh_kanji
    if card.spelling ~= card.reading then header_h = header_h + DS.lh_reading end
    header_h = header_h + DS.lh_badge + DS.unit
    ass_rect(bg_ev, px + LB, py, W - LB, header_h, DS.bg_header, '&H00&')

    -- Cursor (drawing position, relative to popup top-left)
    local cx = px + content_x
    local cy = py + DS.pad_v

    -- ── Kanji / Spelling ─────────────────────────────────────────────────
    -- Large, bold, card-state color for instant visual recognition
    ass_text(fg_ev, cx, cy, FONT_FAMILY, DS.fs_kanji, true, s_color, '&H00&',
        ass_escape(card.spelling))
    cy = cy + DS.lh_kanji

    -- ── Reading (furigana) ───────────────────────────────────────────────
    if card.spelling ~= card.reading then
        ass_text(fg_ev, cx, cy, FONT_FAMILY, DS.fs_reading, false, DS.col_dim, '&H00&',
            ass_escape(card.reading))
        cy = cy + DS.lh_reading
    end

    -- ── State badges + frequency (inline, compact) ───────────────────────
    local badge_x = cx
    for _, s in ipairs(card.state) do
        local sc = STATE_COLORS[s] or '&H888888&'
        local label = STATE_LABELS[s] or s
        -- Dot indicator + label
        ass_text(fg_ev, badge_x, cy, FONT_FAMILY, DS.fs_meta, false, sc, '&H00&',
            '● ' .. ass_escape(label))
        badge_x = badge_x + utf8_len(label) * 10 + 30
    end

    -- Frequency rank right-side (we place it after badges with a separator)
    if card.frequencyRank then
        local freq_str = '  ·  #' .. tostring(card.frequencyRank)
        ass_text(fg_ev, badge_x, cy, FONT_FAMILY, DS.fs_meta, false, DS.col_freq, '&H00&', freq_str)
    end
    cy = cy + DS.lh_badge + DS.unit

    -- ── Divider ──────────────────────────────────────────────────────────
    ass_divider(fg_ev, px + LB + 2, cy, W - LB - 4)
    cy = cy + DS.divider_h + DS.unit

    -- ── Meanings ─────────────────────────────────────────────────────────
    local shown    = 0
    local last_pos = nil
    for i, m in ipairs(card.meanings or {}) do
        if shown >= 6 then break end
        local pos_label = get_pos_label(m.partOfSpeech)

        -- POS chip: small pill-style label (text-only, no box — keeps it clean)
        if pos_label ~= '' and pos_label ~= last_pos then
            ass_text(fg_ev, cx, cy, FONT_FAMILY, DS.fs_pos, false, DS.col_chip, '&H00&',
                '▸ ' .. ass_escape(pos_label))
            cy = cy + DS.lh_pos
            last_pos = pos_label
        end

        local gloss   = table.concat(m.glosses or {}, '; ')
        local wlines  = wrap_text(gloss, WRAP_CHARS)
        -- Meaning number glyph in dim color, text in bright white
        for li, wline in ipairs(wlines) do
            local prefix = (li == 1) and (tostring(i) .. '.  ') or '    '
            local text_col = (i % 2 == 0) and '&HE0E0F0&' or DS.col_white
            ass_text(fg_ev, cx, cy, FONT_FAMILY, DS.fs_gloss, false, text_col, '&H00&',
                ass_escape(prefix .. wline))
            cy = cy + DS.lh_gloss
        end
        shown = shown + 1
    end

    cy = cy + DS.unit * 2

    -- ── Button section divider ────────────────────────────────────────────
    ass_divider(fg_ev, px + LB + 2, cy, W - LB - 4)
    cy = cy + DS.divider_h + DS.unit

    -- ── Helper: draw one button ───────────────────────────────────────────
    local function draw_button(label, key, action, args, bx, by, bw, bh, fs)
        local is_hov = (hovered_button == key)
        local palette = BTN_MAP[key] or DS.btn_neutral
        local bg      = is_hov and palette.hov or palette.bg

        -- Button background
        ass_rect(bg_ev, bx, by, bw, bh, bg, '&H00&')

        -- Top-edge highlight for 3D lift (subtle)
        if is_hov then
            ass_rect(bg_ev, bx, by, bw, 1, DS.col_white, '&HDD&')
        end

        -- Keyboard shortcut hint (small, top-right corner of button)
        local sc = BTN_SHORTCUTS[key]
        if sc then
            ass_text(fg_ev, bx + bw - 14, by + 4,
                FONT_FAMILY, DS.fs_shortcut, false, DS.col_muted, '&H00&', sc)
        end

        -- Button label (centered)
        ass_text_center(fg_ev, bx + bw / 2, by + bh / 2,
            FONT_FAMILY, fs or DS.fs_btn_act, false, DS.col_white, '&H00&', label)

        table.insert(popup_buttons,
            { x1=bx, y1=by, x2=bx+bw, y2=by+bh, key=key, action=action, args=args })
    end

    -- ── Action row: Add / Blacklist / Never Forget ────────────────────────
    local blacklisted, never_forgott = false, false
    for _, s in ipairs(card.state) do
        if s == 'blacklisted'  then blacklisted  = true end
        if s == 'never-forget' then never_forgott = true end
    end

    local action_w = math.floor((W - LB - PAD * 2 - DS.btn_gap * 2) / 3)
    local bx = px + content_x
    draw_button('＋ Add to Deck',  'add',   'mine', {}, bx, cy, action_w, DS.bh_action)
    bx = bx + action_w + DS.btn_gap
    draw_button(blacklisted  and '✕ Un-Blacklist' or '⊘ Blacklist',
        'blacklist', 'set-flag',
        { flag='blacklist',    state=not blacklisted  }, bx, cy, action_w, DS.bh_action)
    bx = bx + action_w + DS.btn_gap
    draw_button(never_forgott and '★ Un-NF'  or '★ Never Forget',
        'never-forget', 'set-flag',
        { flag='never-forget', state=not never_forgott }, bx, cy, action_w, DS.bh_action)
    cy = cy + DS.bh_action + DS.btn_gap

    -- ── Review row: Nothing / Something / Hard / Good / Easy ─────────────
    local review_btns = {
        { '✕ Nothing',   'nothing',   'nothing'   },
        { '△ Something', 'something', 'something' },
        { '▲ Hard',      'hard',      'hard'      },
        { '✓ Good',      'good',      'good'      },
        { '★ Easy',      'easy',      'easy'      },
    }
    local rev_w = math.floor((W - LB - PAD * 2 - DS.btn_gap * 4) / 5)
    bx = px + content_x
    for _, b in ipairs(review_btns) do
        draw_button(b[1], b[2], 'review', { rating=b[3] }, bx, cy, rev_w, DS.bh_review, DS.fs_btn_rev)
        bx = bx + rev_w + DS.btn_gap
    end
    cy = cy + DS.bh_review + DS.pad_v

    -- ── Assemble final OSD data ───────────────────────────────────────────
    -- Merge bg then fg so content is always on top of backgrounds
    local all = {}
    for _, e in ipairs(bg_ev) do table.insert(all, e) end
    for _, e in ipairs(fg_ev) do table.insert(all, e) end

    popup_osd.data = table.concat(all, '\n')
    popup_osd:update()

    dlog(string.format('render_popup px=%d py=%d h=%d btn_count=%d',
        px, py, total_h, #popup_buttons))
end

-- ─── Mouse position → subtitle token mapping ─────────────────────────────────

local function find_hovered_token(mx, my)
    local best_tok, best_dist = nil, math.huge
    for _, region in ipairs(subtitle_regions) do
        if my >= region.y1 and my <= region.y2 then
            if mx >= region.x1 - 8 and mx <= region.x2 + 8 then
                local center = (region.x1 + region.x2) / 2
                local dist   = math.abs(mx - center)
                if dist < best_dist then
                    best_dist = dist
                    best_tok  = region.token
                end
            end
        end
    end
    return best_tok
end

-- ─── Button hit testing ──────────────────────────────────────────────────────

local function find_hovered_button(mx, my)
    for _, btn in ipairs(popup_buttons) do
        if mx >= btn.x1 and mx <= btn.x2 and my >= btn.y1 and my <= btn.y2 then
            return btn
        end
    end
    return nil
end

-- ─── Actions ─────────────────────────────────────────────────────────────────

local function show_toast(msg_text, duration_ms)
    duration_ms = duration_ms or 2000
    mp.osd_message(msg_text, duration_ms / 1000)
end

local function refresh_after_action()
    mp.add_timeout(0.1, function()
        local res, _ = http_request('POST', '/parse', { text = current_text })
        if res and res.tokens then
            current_tokens = res.tokens
            render_subtitles()
            if popup_visible and popup_token then
                for _, tok in ipairs(current_tokens) do
                    if tok.card.vid == popup_token.card.vid and
                       tok.card.sid == popup_token.card.sid then
                        popup_token = tok
                        break
                    end
                end
                render_popup()
            end
        end
    end)
end

local function do_review(card, rating)
    show_toast('Reviewing: ' .. rating .. '…')
    http_request_async('POST', '/review',
        { vid = card.vid, sid = card.sid, rating = rating },
        function(data, err)
            if err then show_toast('Review failed: ' .. err)
            else
                show_toast('✓ Reviewed: ' .. rating)
                refresh_after_action()
            end
        end)
end

local function do_mine(card, sentence)
    show_toast('Adding to deck…')
    http_request_async('POST', '/mine',
        { vid = card.vid, sid = card.sid, sentence = sentence or current_text },
        function(data, err)
            if err then show_toast('Mine failed: ' .. err)
            else show_toast('✓ Added: ' .. card.spelling) end
        end)
end

local function do_set_flag(card, flag, state)
    local verb = state and 'Setting' or 'Removing'
    show_toast(verb .. ' ' .. flag .. '…')
    http_request_async('POST', '/set-flag',
        { vid = card.vid, sid = card.sid, flag = flag, state = state },
        function(data, err)
            if err then show_toast('Flag failed: ' .. err)
            else
                show_toast('✓ ' .. (state and 'Added ' or 'Removed ') .. flag)
                refresh_after_action()
            end
        end)
end

local function dispatch_button(btn)
    if not popup_token then return end
    local card = popup_token.card
    if btn.action == 'review' then
        do_review(card, btn.args.rating)
    elseif btn.action == 'mine' then
        do_mine(card, current_text)
    elseif btn.action == 'set-flag' then
        do_set_flag(card, btn.args.flag, btn.args.state)
    end
end

-- ─── Subtitle observation ────────────────────────────────────────────────────

local parse_timer = nil

local function on_subtitle_change(_, new_text)
    if new_text == last_parsed_text then
        dlog('sub-text unchanged, skipping parse')
        return
    end
    last_parsed_text = new_text
    dlog('sub-text changed: "' .. tostring(new_text and new_text:sub(1,40)) .. '"')

    hovered_token = nil
    popup_visible = false
    popup_token   = nil
    popup_buttons = {}
    subtitle_regions = {}
    render_popup()

    if not new_text or new_text == '' then
        current_text   = ''
        current_tokens = {}
        render_subtitles()
        return
    end

    current_text = new_text

    if parse_timer then parse_timer:kill() end
    parse_timer = mp.add_timeout(0.08, function()
        parse_timer = nil
        if current_text ~= new_text then
            dlog('text changed during debounce, skipping')
            return
        end
        dlog('Sending async parse request for: "' .. new_text:sub(1,40) .. '"')
        http_request_async('POST', '/parse', { text = new_text }, function(res, err)
            if current_text ~= new_text then
                dlog('text changed while waiting for parse, ignoring response')
                return
            end
            if err then
                dlog('Parse error: ' .. tostring(err))
                msg.warn('[jpdb] Parse error: ' .. tostring(err))
                return
            end
            if res and res.tokens then
                dlog('Parse ok: ' .. #res.tokens .. ' tokens')
                current_tokens = res.tokens
                render_subtitles()
                if hovered_token then
                    popup_token    = hovered_token
                    popup_visible  = true
                    hovered_button = nil
                    render_popup()
                end
            end
        end)
    end)
end

mp.observe_property('sub-text', 'string', on_subtitle_change)
mp.set_property('sub-visibility', 'no')
mp.set_property('secondary-sub-visibility', 'no')

-- ─── OSD setup & window resize ──────────────────────────────────────────────

local function init_overlays()
    if not sub_osd then
        sub_osd = mp.create_osd_overlay('ass-events')
        sub_osd.z = 0
        dlog('sub_osd created')
    end
    if not popup_osd then
        popup_osd = mp.create_osd_overlay('ass-events')
        popup_osd.z = 1
        dlog('popup_osd created')
    end
    sub_osd.res_x   = osd_w;  sub_osd.res_y   = osd_h
    popup_osd.res_x = osd_w;  popup_osd.res_y = osd_h
end

init_overlays()

mp.register_event('file-loaded', function()
    local w = mp.get_property_number('osd-width')  or osd_w
    local h = mp.get_property_number('osd-height') or osd_h
    if w > 0 then osd_w = w end
    if h > 0 then osd_h = h end
    init_overlays()
    dlog('file-loaded osd=' .. osd_w .. 'x' .. osd_h)
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

-- ─── Pause / resume helpers ─────────────────────────────────────────────────

local function jpdb_pause()
    if not jpdb_did_pause and not mp.get_property_bool('pause') then
        mp.set_property_bool('pause', true)
        jpdb_did_pause = true
        dlog('paused for lookup')
    end
end

local function jpdb_resume()
    if jpdb_did_pause then
        mp.set_property_bool('pause', false)
        jpdb_did_pause = false
        dlog('resumed after lookup')
    end
end

local function close_popup()
    popup_visible  = false
    popup_token    = nil
    popup_buttons  = {}
    hovered_button = nil
    hovered_token  = nil
    render_popup()
    render_subtitles()
    jpdb_resume()
end

-- ─── Mouse tracking ──────────────────────────────────────────────────────────

local toggle_click_bindings  -- forward decl

local mouse_timer = nil

mp.observe_property('mouse-pos', 'native', function(_, pos)
    if not pos then return end
    hover_x = pos.x
    hover_y = pos.y

    if mouse_timer then return end
    mouse_timer = mp.add_timeout(0.016, function()
        mouse_timer = nil
        local mx = hover_x
        local my = hover_y

        local layout  = subtitle_layout()
        local zone_y1 = math.max(8, layout.sub_text_top - 400)
        local zone_y2 = layout.sub_y + 20
        local in_zone = (my >= zone_y1 and my <= zone_y2)

        if not in_zone then
            if popup_visible or hovered_token then
                close_popup()
                toggle_click_bindings(false)
            end
            return
        end

        -- Update button hover state
        if popup_visible then
            local btn = find_hovered_button(mx, my)
            local new_key = btn and btn.key or nil
            if new_key ~= hovered_button then
                hovered_button = new_key
                render_popup()
            end
        end

        local new_token = find_hovered_token(mx, my)
        if new_token ~= hovered_token then
            hovered_token = new_token
            render_subtitles()

            if new_token then
                jpdb_pause()
                popup_token    = new_token
                popup_visible  = true
                hovered_button = nil
                render_popup()
                toggle_click_bindings(true)
            end
        end
    end)
end)

-- ─── Mouse clicks ────────────────────────────────────────────────────────────

local clicks_bound = false

local function handle_left_click(event)
    if event and event.event ~= 'down' then return end
    local mx, my = hover_x, hover_y
    dlog('MBTN_LEFT DOWN at ' .. mx .. ',' .. my .. ' popup=' .. tostring(popup_visible))
    if popup_visible then
        local btn = find_hovered_button(mx, my)
        if btn then
            dispatch_button(btn)
            close_popup()
            toggle_click_bindings(false)
            return
        end
        close_popup()
        toggle_click_bindings(false)
    end
end

local function handle_left_dbl_click()
    if popup_visible then return end
    mp.command('cycle fullscreen')
end

toggle_click_bindings = function(enable)
    if enable and not clicks_bound then
        mp.add_forced_key_binding('MBTN_LEFT', 'jpdb-click', handle_left_click, { complex = true })
        mp.add_forced_key_binding('MBTN_LEFT_DBL', 'jpdb-dbl-click', handle_left_dbl_click)
        clicks_bound = true
    elseif not enable and clicks_bound then
        mp.remove_key_binding('jpdb-click')
        mp.remove_key_binding('jpdb-dbl-click')
        clicks_bound = false
    end
end

mp.add_forced_key_binding('MBTN_RIGHT', 'jpdb-close-popup', function()
    if popup_visible then
        close_popup()
        toggle_click_bindings(false)
    end
end)

-- ─── Keyboard shortcuts ──────────────────────────────────────────────────────

mp.add_key_binding('ESC', 'jpdb-esc', function()
    if popup_visible then
        close_popup()
        toggle_click_bindings(false)
    end
end)

mp.add_key_binding('shift', 'jpdb-show-popup', function()
    if hovered_token and not popup_visible then
        popup_token    = hovered_token
        popup_visible  = true
        hovered_button = nil
        render_popup()
        toggle_click_bindings(true)
    elseif popup_visible then
        close_popup()
        toggle_click_bindings(false)
    end
end)

mp.add_key_binding('a', 'jpdb-add', function()
    local tok = popup_token or hovered_token
    if tok then do_mine(tok.card, current_text) end
end)

local function review_hotkey(rating)
    return function()
        local tok = popup_token or hovered_token
        if tok then do_review(tok.card, rating) end
    end
end

mp.add_key_binding('1', 'jpdb-nothing',   review_hotkey('nothing'))
mp.add_key_binding('2', 'jpdb-something', review_hotkey('something'))
mp.add_key_binding('3', 'jpdb-hard',      review_hotkey('hard'))
mp.add_key_binding('4', 'jpdb-good',      review_hotkey('good'))
mp.add_key_binding('5', 'jpdb-easy',      review_hotkey('easy'))

mp.add_key_binding('b', 'jpdb-blacklist', function()
    local tok = popup_token or hovered_token
    if not tok then return end
    local is_bl = false
    for _, s in ipairs(tok.card.state) do if s == 'blacklisted' then is_bl = true end end
    do_set_flag(tok.card, 'blacklist', not is_bl)
end)

mp.add_key_binding('n', 'jpdb-never-forget', function()
    local tok = popup_token or hovered_token
    if not tok then return end
    local is_nf = false
    for _, s in ipairs(tok.card.state) do if s == 'never-forget' then is_nf = true end end
    do_set_flag(tok.card, 'never-forget', not is_nf)
end)

-- ─── Cleanup on exit ─────────────────────────────────────────────────────────

mp.register_event('shutdown', function()
    if sub_osd   then sub_osd:remove()   end
    if popup_osd then popup_osd:remove() end
end)

msg.info('[jpdb] Plugin loaded (UI v2). server.js must be running at ' .. SERVER_URL)