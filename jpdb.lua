--[[
    jpdb.lua — JPDB MPV Plugin
    
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
-- Log always goes to the plugin folder (writable, not Program Files)
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

-- Show OSD confirmation so user knows the script loaded
mp.add_timeout(0.5, function()
    mp.osd_message('[jpdb] Plugin loaded! server.js must be running.', 4)
end)

-- ─── Configuration ──────────────────────────────────────────────────────────

local SERVER_URL   = 'http://127.0.0.1:9726'
local POPUP_WIDTH  = 480  -- popup panel width in OSD pixels
local POPUP_MAX_H  = 500  -- max popup height
local FONT_FAMILY  = 'Yu Gothic UI'  -- popup font (supports Japanese/CJK)

-- Card state to ASS color (BGR order, &H<BB><GG><RR>&)
local STATE_COLORS = {
    ['known']       = '&H00C070&',   -- green
    ['never-forget']= '&H00C070&',   -- green
    ['learning']    = '&H80A75E&',   -- teal
    ['new']         = '&HFF8D4B&',   -- blue
    ['not-in-deck'] = '&HFF8D4B&',   -- blue (will apply alpha)
    ['due']         = '&H0045FF&',   -- orange-red
    ['failed']      = '&H0000FF&',   -- red
    ['locked']      = '&H777777&',   -- gray
    ['suspended']   = '&H777777&',   -- gray
    ['blacklisted'] = '&H777777&',   -- gray
    ['redundant']   = '&HAAAAAA&',   -- light gray
}

local STATE_ALPHA = {
    ['not-in-deck'] = '&H80&',  -- 50% opacity
}

-- ─── State ──────────────────────────────────────────────────────────────────

local current_tokens   = {}    -- list of {card, start, end, length, rubies}
local current_text     = ''
local last_parsed_text = nil   -- guard against parse loop
local hovered_token    = nil   -- currently hovered token
local hover_x          = 0
local hover_y          = 0

-- Stored pixel hit regions for subtitle tokens (populated when rendering)
local subtitle_regions = {}

-- Pause/resume state — track if WE paused so we don't interfere with user's pause
local jpdb_did_pause   = false

-- Popup state
local popup_visible    = false
local popup_token      = nil   -- token the popup is showing
local popup_osd        = nil   -- OSD overlay for popup
local sub_osd          = nil   -- OSD overlay for color-coded subtitles

-- Button hit regions: list of {x1,y1,x2,y2, action, args}
local popup_buttons    = {}

-- OSD dimensions (updated on window resize)
local osd_w = 1280
local osd_h = 720

-- ─── HTTP helpers ───────────────────────────────────────────────────────────

-- Synchronous HTTP POST using mpv's subprocess (curl)
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
        name = 'subprocess',
        args = args,
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false,
    })

    dlog('http_request ' .. method .. ' ' .. path .. ' status=' .. tostring(res and res.status))

    if res.status ~= 0 then
        dlog('curl failed: ' .. (res.stderr or 'unknown'))
        msg.error(string.format('[jpdb] curl failed (%d): %s', res.status, res.stderr or ''))
        return nil, 'curl failed: ' .. (res.stderr or 'unknown error')
    end

    local ok, data = pcall(utils.parse_json, res.stdout)
    if not ok or data == nil then
        msg.error('[jpdb] Failed to parse server response: ' .. (res.stdout or ''))
        return nil, 'bad JSON response'
    end

    if data.error then
        return nil, data.error
    end

    return data, nil
end

-- Async HTTP request (fire-and-forget for reviews/mines)
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
        name = 'subprocess',
        args = args,
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false,
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
-- Lua's # operator returns UTF-8 BYTES, not characters.
-- CJK chars are 3 bytes each so we must count explicitly.

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
    -- Convert 0-based UTF-8 byte offset → 0-based character index
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

-- Split a subtitle text into per-line info for multi-line hit region calculation.
-- Each entry: { text, byte_start (0-based), chars_before }
local function split_text_lines(text)
    local result = {}
    local i = 1            -- 1-indexed byte cursor
    local line_start = 1   -- 1-indexed byte where this line starts
    local chars_before = 0 -- character count before this line
    while i <= #text do
        local b = text:byte(i)
        if b == 10 then  -- '\n'
            local line_text = text:sub(line_start, i - 1)
            table.insert(result, {
                text         = line_text,
                byte_start   = line_start - 1,  -- 0-based
                chars_before = chars_before,
            })
            chars_before = chars_before + utf8_len(line_text) + 1  -- +1 for \n
            line_start = i + 1
            i = i + 1
        else
            if b < 0x80 then i = i + 1
            elseif b < 0xE0 then i = i + 2
            elseif b < 0xF0 then i = i + 3
            else i = i + 4 end
        end
    end
    -- Last (or only) line
    local line_text = text:sub(line_start)
    table.insert(result, {
        text         = line_text,
        byte_start   = line_start - 1,
        chars_before = chars_before,
    })
    return result
end

-- ─── ASS helpers ────────────────────────────────────────────────────────────

local function ass_color(color_hex, alpha_hex)
    -- Returns ASS tags for primary color and optionally alpha
    local a = alpha_hex or '&H00&'
    return string.format('\\c%s\\1a%s', color_hex, a)
end

local function ass_escape(s)
    if not s then return '' end
    return s:gsub('\\', '\\\\'):gsub('{', '\\{'):gsub('}', '\\}'):gsub('\n', '\\N')
end

-- Draw a filled rectangle in ASS drawing commands
local function draw_rect(a, x1, y1, x2, y2)
    a:new_event()
    a:pos(0, 0)
    a:an(7)
    a:append(string.format('{\\bord0\\shad0\\p1}'))
    a:append(string.format('m %d %d l %d %d %d %d %d %d',
        x1, y1, x2, y1, x2, y2, x1, y2))
    a:append('{\\p0}')
end

-- ─── Get primary token state ─────────────────────────────────────────────────

local function get_primary_state(card_state)
    if not card_state or #card_state == 0 then return 'not-in-deck' end
    -- Prefer last element for redundant/locked combos
    for _, s in ipairs(card_state) do
        if STATE_COLORS[s] then
            return s
        end
    end
    return card_state[1] or 'not-in-deck'
end

-- ─── Subtitle overlay ───────────────────────────────────────────────────────

local function build_subtitle_ass(tokens, raw_text)
    if not tokens or #tokens == 0 then return nil end

    local ass    = assdraw.ass_new()
    local parts  = {}
    local last   = 0

    -- Sort tokens by start position
    table.sort(tokens, function(a, b) return a.start < b.start end)

    for _, tok in ipairs(tokens) do
        -- Characters before this token (unparsed — white)
        if tok.start > last then
            local pre = raw_text:sub(last + 1, tok.start)
            table.insert(parts, '{\\c&HFFFFFF&\\1a&H00&}' .. ass_escape(pre))
        end

        local state = get_primary_state(tok.card.state)
        local color = STATE_COLORS[state] or '&HFFFFFF&'
        local alpha = STATE_ALPHA[state]  or '&H00&'

        -- Hover underline
        local underline = ''
        if tok == hovered_token then
            underline = '\\u1'
        end

        local text_part = raw_text:sub(tok.start + 1, tok['end'])
        table.insert(parts, string.format('{\\c%s\\1a%s%s}%s',
                     color, alpha, underline, ass_escape(text_part)))

        last = tok['end']
    end

    -- Remainder text
    if last < #raw_text then
        table.insert(parts, '{\\c&HFFFFFF&\\1a&H00&}' .. ass_escape(raw_text:sub(last + 1)))
    end

    return table.concat(parts)
end

-- Shared subtitle layout constants (used by both render_subtitles and popup positioning)
local CHAR_PX     = 40   -- OSD units per CJK char at fs40
local LINE_HEIGHT = 48   -- fs40 + line spacing (≈ 1.2 × CHAR_PX)

local function subtitle_layout()
    -- Returns {n_lines, sub_y_anchor, sub_text_top, lines_info}
    -- sub_text_top: Y of the topmost subtitle pixel (for popup: popup must end above here)
    local sub_y = osd_h - 60
    local lines = split_text_lines(current_text)
    local n     = #lines
    local sub_text_top = sub_y - n * LINE_HEIGHT
    return { n = n, sub_y = sub_y, sub_text_top = sub_text_top, lines = lines }
end

local function render_subtitles()
    if not sub_osd then return end

    subtitle_regions = {}  -- reset hit regions

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

    -- Build per-line hit regions (multi-line subtitle support)
    local layout = subtitle_layout()
    local sub_x  = math.floor(osd_w / 2)

    for line_idx, ln in ipairs(layout.lines) do
        -- Y: last line (idx=n) is at bottom (sub_y), earlier lines are above by LINE_HEIGHT each
        local from_bottom  = layout.n - line_idx
        local line_bottom  = layout.sub_y - from_bottom * LINE_HEIGHT
        local y1 = line_bottom - CHAR_PX - 6
        local y2 = line_bottom + 10

        -- X: each line is individually centered
        local line_nch  = utf8_len(ln.text)
        local line_w    = line_nch * CHAR_PX
        local line_left = sub_x - line_w / 2

        -- Byte range of this line within the full text
        local line_byte_start = ln.byte_start
        local line_byte_end   = ln.byte_start + #ln.text

        for _, tok in ipairs(current_tokens) do
            if tok.start >= line_byte_start and tok['end'] <= line_byte_end + 1 then
                -- Character position within this line
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
    a:append('\\fs40')
    a:append('\\bord2')
    a:append('\\shad1')
    a:append('\\b0}')
    a:append(ass_content)
    sub_osd.data = a.text
    sub_osd:update()
end

-- ─── Popup rendering ─────────────────────────────────────────────────────────

local PARTS_OF_SPEECH = {
    n = 'Noun', pn = 'Pronoun', pref = 'Prefix', suf = 'Suffix',
    name = 'Name', ['name-fem'] = 'Name (Feminine)', ['name-male'] = 'Name (Masculine)',
    ['name-surname'] = 'Surname', ['name-person'] = 'Personal Name',
    ['name-place'] = 'Place Name', ['name-company'] = 'Company Name',
    ['adj-i'] = 'Adjective', ['adj-na'] = 'な-Adjective', ['adj-no'] = 'の-Adjective',
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
    return table.concat(labels, ', ')
end

-- Button color map (BGR for ASS)
local BTN_COLORS = {
    add          = { bg = '&H4B4B4B&', hover = '&H606060&' },
    blacklist    = { bg = '&H555555&', hover = '&H6A6A6A&' },
    ['never-forget'] = { bg = '&H006A40&', hover = '&H008050&' },
    nothing      = { bg = '&H0000CC&', hover = '&H0000FF&' },
    something    = { bg = '&H0000CC&', hover = '&H0000FF&' },
    hard         = { bg = '&H003FBF&', hover = '&H004DFF&' },
    good         = { bg = '&H006A40&', hover = '&H008050&' },
    easy         = { bg = '&H4B2B00&', hover = '&H5E3600&' },
}

local hovered_button = nil  -- key of currently hovered button

local function ass_rect(events, x, y, w, h, color, alpha)
    -- Draw filled rectangle using \\p1 (1:1 OSD coordinate mapping)
    -- Separate from assdraw to avoid scale=4 conflict
    table.insert(events, string.format(
        '{\\an7\\pos(%d,%d)\\bord0\\shad0\\1c%s\\1a%s\\p1}m 0 0 l %d 0 %d %d 0 %d{\\p0}',
        x, y, color, alpha, w, w, h, h))
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

local function render_popup()

    if not popup_osd then return end
    if not popup_visible or not popup_token then
        popup_osd.data = ''
        popup_osd:update()
        return
    end

    popup_buttons = {}

    local card  = popup_token.card
    local state = get_primary_state(card.state)
    local color = STATE_COLORS[state] or '&HFFFFFF&'

    -- Popup position: always strictly ABOVE the subtitle area
    -- sub_text_top = top of topmost subtitle line pixel
    -- popup bottom = sub_text_top - 10px gap → guaranteed never overlaps subtitle
    local layout = subtitle_layout()
    local popup_max_bottom = layout.sub_text_top - 10
    -- Estimate popup height to set py; actual height computed as cur_y grows
    local popup_h_est = math.min(popup_max_bottom - 10, 300)
    local py = math.max(10, popup_max_bottom - popup_h_est)

    -- Popup x: calculate from the center of the token's hit region, NOT current mouse position.
    -- This ensures the popup doesn't move when you move the mouse to click buttons!
    local tok_center_x = hover_x -- fallback
    for _, region in ipairs(subtitle_regions) do
        if region.token == popup_token then
            tok_center_x = (region.x1 + region.x2) / 2
            break
        end
    end
    local px = math.max(10, math.min(tok_center_x - POPUP_WIDTH / 2, osd_w - POPUP_WIDTH - 10))

    local ev     = {}  -- ASS event lines
    local text_x = px + 16
    local cur_y  = py + 16

    -- ── Header ───────────────────────────────────────────────────────────
    local header = ass_escape(card.spelling)
    if card.spelling ~= card.reading then
        header = header .. '  (' .. ass_escape(card.reading) .. ')'
    end
    ass_text(ev, text_x, cur_y, FONT_FAMILY, 28, true, color, '&H00&', header)
    cur_y = cur_y + 34

    -- State badges
    local badge_x = text_x
    for _, s in ipairs(card.state) do
        local sc = STATE_COLORS[s] or '&H888888&'
        ass_text(ev, badge_x, cur_y, FONT_FAMILY, 14, false, sc, '&H00&', '● ' .. ass_escape(s))
        badge_x = badge_x + (utf8_len(s) * 10 + 32)
    end
    cur_y = cur_y + 22

    -- Frequency rank
    if card.frequencyRank then
        ass_text(ev, text_x, cur_y, FONT_FAMILY, 14, false, '&HAAAAAA&', '&H00&',
            'Top ' .. tostring(card.frequencyRank))
        cur_y = cur_y + 20
    end

    -- Separator line
    ass_rect(ev, px + 8, cur_y, POPUP_WIDTH - 16, 1, '&H555555&', '&H00&')
    cur_y = cur_y + 8

    -- ── Meanings ─────────────────────────────────────────────────────────
    local shown    = 0
    local last_pos = nil
    for i, m in ipairs(card.meanings or {}) do
        if shown >= 6 then break end
        local pos_label = get_pos_label(m.partOfSpeech)
        if pos_label ~= '' and pos_label ~= last_pos then
            ass_text(ev, text_x, cur_y, FONT_FAMILY, 13, true, '&H888888&', '&H00&', pos_label)
            cur_y    = cur_y + 18
            last_pos = pos_label
        end
        local gloss = table.concat(m.glosses or {}, '; ')
        if utf8_len(gloss) > 48 then
            -- trim to char limit
            local b, n = 1, 0
            while b <= #gloss and n < 48 do
                local byte = gloss:byte(b)
                if byte < 0x80 then b = b + 1
                elseif byte < 0xE0 then b = b + 2
                elseif byte < 0xF0 then b = b + 3
                else b = b + 4 end
                n = n + 1
            end
            gloss = gloss:sub(1, b - 1) .. '...'
        end
        ass_text(ev, text_x + 8, cur_y, FONT_FAMILY, 15, false, '&HEEEEEE&', '&H00&',
            i .. '. ' .. ass_escape(gloss))
        cur_y = cur_y + 20
        shown = shown + 1
    end

    cur_y = cur_y + 6

    -- Separator line
    ass_rect(ev, px + 8, cur_y, POPUP_WIDTH - 16, 1, '&H555555&', '&H00&')
    cur_y = cur_y + 8

    -- ── Buttons ───────────────────────────────────────────────────────────
    local bh = 26
    local gap = 5

    local function draw_button(label, key, action, args, bx, by, bw)
        local is_hov = (hovered_button == key)
        local c = BTN_COLORS[key] or { bg = '&H333333&', hover = '&H555555&' }
        local bg = is_hov and c.hover or c.bg
        ass_rect(ev, bx, by, bw, bh, bg, '&H00&')
        ass_text_center(ev, bx + bw / 2, by + bh / 2, FONT_FAMILY, 13, false, '&HFFFFFF&', '&H00&', label)
        table.insert(popup_buttons, { x1=bx, y1=by, x2=bx+bw, y2=by+bh, key=key, action=action, args=args })
    end

    local blacklisted, never_forgott = false, false
    for _, s in ipairs(card.state) do
        if s == 'blacklisted'  then blacklisted  = true end
        if s == 'never-forget' then never_forgott = true end
    end

    -- Mine row
    local mw = math.floor((POPUP_WIDTH - 32 - gap * 2) / 3)
    local bx = px + 16
    draw_button('Add to Deck', 'add', 'mine', {}, bx, cur_y, mw)
    bx = bx + mw + gap
    draw_button(blacklisted and 'Un-Blacklist' or 'Blacklist', 'blacklist', 'set-flag',
        { flag = 'blacklist', state = not blacklisted }, bx, cur_y, mw)
    bx = bx + mw + gap
    draw_button(never_forgott and 'Un-NF' or 'Never Forget', 'never-forget', 'set-flag',
        { flag = 'never-forget', state = not never_forgott }, bx, cur_y, mw)
    cur_y = cur_y + bh + gap

    -- Review row
    local rw = math.floor((POPUP_WIDTH - 32 - gap * 4) / 5)
    bx = px + 16
    for _, b in ipairs({ {'Nothing','nothing'}, {'Something','something'}, {'Hard','hard'}, {'Good','good'}, {'Easy','easy'} }) do
        draw_button(b[1], b[2], 'review', { rating = b[2] }, bx, cur_y, rw)
        bx = bx + rw + gap
    end
    cur_y = cur_y + bh + 10

    -- ── Background (drawn first, before content) ──────────────────────────
    local actual_h = cur_y - py
    local all_ev   = {}

    -- Shadow
    ass_rect(all_ev, px + 3, py + 3, POPUP_WIDTH, actual_h, '&H000000&', '&H70&')
    -- Panel
    ass_rect(all_ev, px, py, POPUP_WIDTH, actual_h, '&H141414&', '&H08&')
    -- Accent bar
    ass_rect(all_ev, px, py, POPUP_WIDTH, 3, color, '&H00&')

    -- Combine: backgrounds first, then content
    for _, e in ipairs(ev) do table.insert(all_ev, e) end

    popup_osd.data = table.concat(all_ev, '\n')
    popup_osd:update()

    dlog(string.format('render_popup px=%d py=%d h=%d events=%d spelling=%s',
        px, py, actual_h, #all_ev, tostring(card.spelling)))
end


-- ─── Mouse position → subtitle token mapping ──────────────────────────────────────
-- Uses pixel regions stored during render_subtitles() for accurate hit detection.

local function find_hovered_token(mx, my)
    -- Use closest-center matching: find the token region whose CENTER X is
    -- closest to the mouse X. This prevents jumpy behavior at token boundaries.
    local best_tok  = nil
    local best_dist = math.huge
    for _, region in ipairs(subtitle_regions) do
        if my >= region.y1 and my <= region.y2 then
            -- Check if mx is within region with a small tolerance
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

local function do_review(card, rating)
    show_toast('Reviewing: ' .. rating .. '…')
    http_request_async('POST', '/review', { vid = card.vid, sid = card.sid, rating = rating },
        function(data, err)
            if err then
                show_toast('Review failed: ' .. err)
            else
                show_toast('Reviewed: ' .. rating)
                -- Refresh parse to get updated state
                mp.add_timeout(0.1, function()
                    local res, e = http_request('POST', '/parse', { text = current_text })
                    if res and res.tokens then
                        current_tokens = res.tokens
                        render_subtitles()
                        if popup_visible and popup_token then
                            -- Update popup token card state
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
        end)
end

local function do_mine(card, sentence)
    show_toast('Adding to deck…')
    http_request_async('POST', '/mine',
        { vid = card.vid, sid = card.sid, sentence = sentence or current_text },
        function(data, err)
            if err then
                show_toast('Mine failed: ' .. err)
            else
                show_toast('✓ Added: ' .. card.spelling)
            end
        end)
end

local function do_set_flag(card, flag, state)
    local verb = state and 'Setting' or 'Removing'
    show_toast(verb .. ' ' .. flag .. '…')
    http_request_async('POST', '/set-flag',
        { vid = card.vid, sid = card.sid, flag = flag, state = state },
        function(data, err)
            if err then
                show_toast('Flag failed: ' .. err)
            else
                show_toast('✓ ' .. (state and 'Added ' or 'Removed ') .. flag)
                -- Refresh
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
        end)
end

-- Dispatch a button action
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
    -- Guard: only process if text actually changed
    if new_text == last_parsed_text then
        dlog('sub-text unchanged, skipping parse')
        return
    end
    last_parsed_text = new_text
    dlog('sub-text changed: "' .. tostring(new_text and new_text:sub(1,40)) .. '"')

    -- Reset hover/popup state but keep OLD subtitle showing until new parse arrives
    hovered_token = nil
    popup_visible = false
    popup_token   = nil
    popup_buttons = {}
    subtitle_regions = {}
    render_popup()
    -- NOTE: Do NOT call render_subtitles() here — keep old subtitle visible
    -- until the async parse for the new text completes.

    if not new_text or new_text == '' then
        current_text   = ''
        current_tokens = {}
        render_subtitles()  -- only clear overlay when text is truly empty
        return
    end

    current_text = new_text

    -- Debounce: don't fire until text stabilizes (e.g. multi-line merges)
    if parse_timer then
        parse_timer:kill()
    end
    parse_timer = mp.add_timeout(0.08, function()
        parse_timer = nil
        -- Double-check text hasn't changed again during debounce
        if current_text ~= new_text then
            dlog('text changed during debounce, skipping')
            return
        end
        dlog('Sending async parse request for: "' .. new_text:sub(1,40) .. '"')
        http_request_async('POST', '/parse', { text = new_text }, function(res, err)
            -- Only apply if text hasn't changed since we sent the request
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
                -- If mouse is still over a word, auto-show popup
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

-- Disable default subtitle rendering so we can replace it with our colored version
mp.set_property('sub-visibility', 'no')

-- Also hide any secondary subs
mp.set_property('secondary-sub-visibility', 'no')

-- ─── OSD setup & window resize ──────────────────────────────────────────────

local function init_overlays()
    -- Safe to call multiple times
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
    sub_osd.res_x   = osd_w
    sub_osd.res_y   = osd_h
    popup_osd.res_x = osd_w
    popup_osd.res_y = osd_h
end

-- Initialize overlays immediately at script load so they are ready before any subtitle fires
init_overlays()

mp.register_event('file-loaded', function()
    local w = mp.get_property_number('osd-width')  or osd_w
    local h = mp.get_property_number('osd-height') or osd_h
    if w > 0 then osd_w = w end
    if h > 0 then osd_h = h end
    -- Re-init to update resolution
    init_overlays()
    dlog('file-loaded osd=' .. osd_w .. 'x' .. osd_h)
    -- Re-render if we already have tokens (subtitle fired before file-loaded)
    if #current_tokens > 0 then
        render_subtitles()
    end
end)

mp.observe_property('osd-width', 'number', function(_, w)
    if w and w > 0 then osd_w = w end
    if sub_osd   then sub_osd.res_x   = osd_w end
    if popup_osd then popup_osd.res_x = osd_w end
    render_subtitles()
    render_popup()
end)

mp.observe_property('osd-height', 'number', function(_, h)
    if h and h > 0 then osd_h = h end
    if sub_osd   then sub_osd.res_y   = osd_h end
    if popup_osd then popup_osd.res_y = osd_h end
    render_subtitles()
    render_popup()
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

        -- Interaction zone: from popup top down to below subtitle
        -- Use same formula as popup py so zone matches popup exactly
        local layout  = subtitle_layout()
        local zone_y1 = math.max(10, layout.sub_text_top - 310)  -- popup top estimate
        local zone_y2 = layout.sub_y + 20
        local in_zone = (my >= zone_y1 and my <= zone_y2)

        if not in_zone then
            -- Mouse outside the zone: close popup if open, resume video
            if popup_visible or hovered_token then
                close_popup()
            end
            return
        end

        -- ── Inside interaction zone ──────────────────────────────────────
        -- Update button hover highlight
        if popup_visible then
            local btn = find_hovered_button(mx, my)
            local new_key = btn and btn.key or nil
            if new_key ~= hovered_button then
                hovered_button = new_key
                render_popup()
            end
        end

        -- Track which subtitle word the mouse is over
        local new_token = find_hovered_token(mx, my)

        if new_token ~= hovered_token then
            hovered_token = new_token
            render_subtitles()  -- update underline

            if new_token then
                -- Entered a word → pause video, open popup
                jpdb_pause()
                popup_token    = new_token
                popup_visible  = true
                hovered_button = nil
                render_popup()
            elseif not popup_visible then
                -- No word but still in zone and no popup open → do nothing
                -- (popup stays open when mouse moves from word to popup buttons)
            end
        end
    end)
end)

-- ─── Mouse clicks ────────────────────────────────────────────────────────────

-- Click is ONLY for interacting with popup buttons.
mp.add_forced_key_binding('MBTN_LEFT', 'jpdb-click', function(event)
    if event and event.event ~= 'down' then return end
    local mx = hover_x
    local my = hover_y
    dlog('MBTN_LEFT DOWN at ' .. mx .. ',' .. my .. ' popup=' .. tostring(popup_visible))

    if popup_visible then
        local btn = find_hovered_button(mx, my)
        if btn then
            dispatch_button(btn)
            return
        end
        -- Clicked outside buttons — dismiss popup and resume
        close_popup()
    end
end, { complex = true })

-- Double-click: absorb if popup open, otherwise fullscreen toggle
mp.add_forced_key_binding('MBTN_LEFT_DBL', 'jpdb-dbl-click', function()
    if popup_visible then return end
    mp.command('cycle fullscreen')
end)

-- Right-click: close popup
mp.add_forced_key_binding('MBTN_RIGHT', 'jpdb-close-popup', function()
    if popup_visible then close_popup() end
end)

-- ─── Keyboard shortcuts ──────────────────────────────────────────────────────

-- ESC to close popup
mp.add_key_binding('ESC', 'jpdb-esc', function()
    if popup_visible then close_popup() end
end)

-- SPACE re-opens popup for hovered word without unpausing
mp.add_key_binding('shift', 'jpdb-show-popup', function()
    if hovered_token and not popup_visible then
        popup_token    = hovered_token
        popup_visible  = true
        hovered_button = nil
        render_popup()
    elseif popup_visible then
        close_popup()
    end
end)

-- Quick-add hovered word to mining deck
mp.add_key_binding('a', 'jpdb-add', function()
    local tok = popup_token or hovered_token
    if tok then
        do_mine(tok.card, current_text)
    end
end)

-- Quick review shortcuts
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

-- Blacklist / never-forget toggles
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

-- Escape to close popup
mp.add_key_binding('ESC', 'jpdb-esc', function()
    if popup_visible then
        popup_visible  = false
        popup_token    = nil
        popup_buttons  = {}
        hovered_button = nil
        render_popup()
    end
end)

-- ─── Cleanup on exit ─────────────────────────────────────────────────────────

mp.register_event('shutdown', function()
    if sub_osd   then sub_osd:remove()   end
    if popup_osd then popup_osd:remove() end
end)

msg.info('[jpdb] Plugin loaded. server.js must be running at ' .. SERVER_URL)
