-- jpdb-config.lua
-- User Configurations for JPDB MPV Plugin

local DS = {
    -- ======== POPUP SETTINGS ========
    -- Master dimensions for the popup
    width       = 560,    -- Max width of the popup (pixels)
    lbar_w      = 5,      -- Width of the left state colour bar
    pad_h       = 22,     -- Horizontal padding inside popup
    pad_v       = 18,     -- Vertical padding inside popup
    unit        = 8,      -- Base unit for vertical spacing
    btn_gap     = 5,      -- Gap between action/review buttons

    -- Surfaces (dark warm paper)
    bg_popup    = '&H0F0E0A&',   -- deepest background
    bg_surface  = '&H1A1914&',   -- card body
    bg_header   = '&H221F18&',   -- header zone (slightly lighter)
    bg_divider  = '&H332E24&',   -- horizontal rule

    -- Shadows (stacked for depth)
    shadow_ambient = '&H000000&',
    shadow_key     = '&H000000&',
    shadow_fill    = '&H000000&',

    -- State badge background tint (very translucent)
    badge_alpha = '&HD8&',       -- badge bg alpha (low opacity)

    -- Text hierarchy
    col_primary   = '&HFAF8F2&', -- headings, kanji
    col_secondary = '&HBCB8AE&', -- readings, labels
    col_tertiary  = '&H8A8680&', -- muted / meta
    col_gloss_odd  = '&HF0EDE6&',
    col_gloss_even = '&HD4D0CA&',
    col_pos       = '&H9BAAC0&', -- part-of-speech chips
    col_freq      = '&H7A92A8&', -- frequency rank
    col_shortcut  = '&H70706A&', -- keyboard shortcut hints
    col_divider   = '&H504A40&',
    col_toast_ok  = '&H60C880&', -- inline success
    col_toast_err = '&H5050EE&', -- inline error

    -- Buttons: { bg, hover, active }
    btn_add       = { bg='&H243428&', hov='&H384E38&', act='&H4A6448&' },
    btn_blacklist = { bg='&H281E28&', hov='&H402E40&', act='&H583A58&' },
    btn_nf        = { bg='&H1E2E28&', hov='&H2E4A3C&', act='&H3C6050&' },
    btn_nothing   = { bg='&H18186A&', hov='&H282890&', act='&H3838A8&' },
    btn_something = { bg='&H143878&', hov='&H205098&', act='&H2C62B0&' },
    btn_hard      = { bg='&H246888&', hov='&H3488A8&', act='&H44A0C0&' },
    btn_good      = { bg='&H1A6028&', hov='&H288040&', act='&H369C52&' },
    btn_easy      = { bg='&H603E10&', hov='&H805822&', act='&H9C7030&' },
    btn_neutral   = { bg='&H282218&', hov='&H3C3428&', act='&H504438&' },

    -- Typography sizes (pt, rendered by ASS font size)
    -- Increase these values to make the text larger inside the popup
    fs_kanji    = 52,     -- Main spelling (Kanji)
    fs_reading  = 24,     -- Reading (Kana) underneath spelling
    fs_pos      = 14,     -- Part of speech label (e.g. ▸ Noun)
    fs_gloss    = 22,     -- Meaning/English definitions
    fs_meta     = 15,     -- Meta information
    fs_badge    = 13,     -- State badge text (e.g. Known, New)
    fs_btn_act  = 15,     -- Action button text (Add, Blacklist)
    fs_btn_rev  = 16,     -- Review button text (Good, Easy, etc.)
    fs_shortcut = 12,     -- Keyboard shortcut hint text
    fs_toast    = 15,     -- Inline action feedback text

    -- Line heights (px) - Should be adjusted proportionally if you increase font sizes!
    lh_kanji    = 62,
    lh_reading  = 30,
    lh_pos      = 20,
    lh_gloss    = 28,
    lh_meta     = 20,
    lh_badge    = 22,
    lh_toast    = 26,
    divider_h   = 1,      -- Horizontal divider line thickness

    -- Button heights
    bh_action   = 34,
    bh_review   = 42,
}

-- ======== SUBTITLE OVERLAY SETTINGS ========
local SUBTITLE_OVERLAY = {
    -- Distance from the bottom of the screen (in pixels)
    -- Increase this if your subtitles overlap with the system UI or standard bottom subtitles
    pos_y_offset = 90,

    -- Subtitle font size rendering
    font_size    = 60,  

    -- Glyph width tracking for hit detection. If you change font_size,
    -- ideally you should change these proportionally.
    -- e.g. if font_size goes from 48 -> 60 (+25%), PX_FULL from 48 -> 60, PX_HALF from 26 -> ~32
    px_full      = 60,
    px_half      = 32,
    line_h       = 72,
}


return {
    -- Set to true to write a debug log file (jpdb-debug.log) and verbose messages.
    -- Leave false in production — no file is created, dlog() is a no-op.
    DEBUG_LOG = false,

    SERVER_URL  = 'http://127.0.0.1:9726',
    
    -- Change the font family used for both subtitles and popup UI
    FONT_FAMILY = 'Yu Gothic UI',

    DS = DS,
    SUBTITLE_OVERLAY = SUBTITLE_OVERLAY,

    -- ======== CARD STATES & COLOURS ========
    STATE_COLORS = {
        ['known']        = '&H50C878&',
        ['never-forget'] = '&H50C878&',
        ['learning']     = '&H70C8A0&',
        ['new']          = '&HE09040&',
        ['not-in-deck']  = '&HE09040&',
        ['due']          = '&H4878FF&',
        ['failed']       = '&H3030EE&',
        ['locked']       = '&H909098&',
        ['suspended']    = '&H909098&',
        ['blacklisted']  = '&H808088&',
        ['redundant']    = '&HAAAABC&',
    },

    -- Dimmer palette for non-hovered tokens (subtle — just slightly muted)
    STATE_COLORS_DIM = {
        ['known']        = '&H46B86E&',
        ['never-forget'] = '&H46B86E&',
        ['learning']     = '&H64BC94&',
        ['new']          = '&HCC8838&',
        ['not-in-deck']  = '&HCC8838&',
        ['due']          = '&H3C6EEE&',
        ['failed']       = '&H2828D8&',
        ['locked']       = '&H80808A&',
        ['suspended']    = '&H80808A&',
        ['blacklisted']  = '&H727278&',
        ['redundant']    = '&H9898AA&',
    },

    STATE_ALPHA  = { ['not-in-deck'] = '&H66&' },
    STATE_ALPHA_DIM = { ['not-in-deck'] = '&H44&' },

    STATE_LABELS = {
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
    },

    BTN_MAP = {
        add              = DS.btn_add,
        blacklist        = DS.btn_blacklist,
        ['never-forget'] = DS.btn_nf,
        nothing          = DS.btn_nothing,
        something        = DS.btn_something,
        hard             = DS.btn_hard,
        good             = DS.btn_good,
        easy             = DS.btn_easy,
    },

    BTN_SHORTCUTS = {
        nothing='1', something='2', hard='3', good='4', easy='5',
        add='A', blacklist='B', ['never-forget']='N',
    }
}
