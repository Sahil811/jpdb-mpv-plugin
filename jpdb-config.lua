-- jpdb-config.lua
-- User Configurations for JPDB MPV Plugin

local DS = {
    -- ======== POPUP SETTINGS ========
    -- Master dimensions for the popup
    width       = 540,    -- Slightly narrower for better focus (reduced from 560)
    lbar_w      = 3,      -- Thinner accent bar (reduced from 4)
    pad_h       = 14,     -- Tighter horizontal padding (reduced from 16)
    pad_v       = 10,     -- Tighter vertical padding (reduced from 12)
    unit        = 5,      -- Smaller spacing unit (reduced from 6)
    btn_gap     = 3,      -- Minimal button gaps (reduced from 4)

    -- Surfaces (dark warm paper)
    bg_popup    = '&H0F0E0A&',   -- deepest background
    bg_surface  = '&H1A1914&',   -- card body
    bg_header   = '&H1C1A15&',   -- header zone (slightly darker for less contrast)
    bg_divider  = '&H2A2620&',   -- horizontal rule (lighter for subtlety)

    -- Shadows (stacked for depth) - Reduced for cleaner look
    shadow_ambient = '&H000000&',
    shadow_key     = '&H000000&',
    shadow_fill    = '&H000000&',

    -- State badge background tint (very translucent)
    badge_alpha = '&HE0&',       -- Slightly more transparent (was D8)

    -- Text hierarchy - Enhanced contrast
    col_primary   = '&HFFFFFF&', -- Pure white for kanji (was FAF8F2)
    col_secondary = '&HC8C4BC&', -- Brighter readings (was BCB8AE)
    col_tertiary  = '&H8A8680&', -- muted / meta
    col_gloss_odd  = '&HF5F2EA&', -- Brighter glosses (was F0EDE6)
    col_gloss_even = '&HE0DCD6&', -- Better contrast (was D4D0CA)
    col_pos       = '&HA8B8CC&', -- Brighter POS tags (was 9BAAC0)
    col_freq      = '&H88A0B8&', -- Brighter frequency (was 7A92A8)
    col_shortcut  = '&H888882&', -- Slightly brighter shortcuts (was 70706A)
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

    -- Typography sizes - Optimized hierarchy
    fs_kanji    = 54,     -- Slightly larger kanji for prominence (was 52)
    fs_reading  = 26,     -- Balanced reading size (was 28)
    fs_pos      = 13,     -- Smaller POS for less visual weight (was 14)
    fs_gloss    = 23,     -- Optimal gloss size (was 24)
    fs_meta     = 14,     -- Smaller meta (was 15)
    fs_badge    = 12,     -- Smaller badges (was 13)
    fs_btn_act  = 15,     -- Balanced button text (was 16)
    fs_btn_rev  = 16,     -- Balanced review buttons (was 17)
    fs_shortcut = 10,     -- Minimal shortcuts (was 11)
    fs_toast    = 14,     -- Smaller toast (was 15)

    -- Line heights - Optimized for readability and compactness
    lh_kanji    = 60,     -- Breathing room for kanji (was 58)
    lh_reading  = 30,     -- Tighter reading (was 32)
    lh_pos      = 17,     -- Compact POS (was 18)
    lh_gloss    = 27,     -- Optimal gloss spacing (was 28)
    lh_meta     = 17,     -- Compact meta (was 18)
    lh_badge    = 18,     -- Tighter badges (was 20)
    lh_toast    = 22,     -- Compact toast (was 24)
    divider_h   = 1,      -- Horizontal divider line thickness

    -- Button heights - Compact but clickable
    bh_action   = 28,     -- More compact action buttons (was 30)
    bh_review   = 34,     -- More compact review buttons (was 36)
}

-- ======== SUBTITLE OVERLAY SETTINGS ========
local SUBTITLE_OVERLAY = {
    pos_y_offset = 90,
    font_size    = 60,  

    -- Glyph width tracking for hit detection (3 width classes).
    -- These values are calibrated for Yu Gothic UI at font_size=60.
    -- When font_size changes, widths auto-scale proportionally.
    px_full      = 60,   -- CJK ideographs, hiragana, katakana, fullwidth punct
    px_half      = 32,   -- ASCII letters, digits, Latin extensions
    px_narrow    = 18,   -- ASCII punctuation, spaces (.,!?;:'" etc.)

    -- Global width multiplier. Adjust if hover regions are systematically
    -- too wide (< 1.0) or too narrow (> 1.0) for your font/display.
    width_scale  = 1.0,

    line_h       = 72,

    -- Border width used in ASS rendering (\bordN) — hit regions expand by this
    bord_w       = 2,

    -- Vertical hit region calibration (fractions of font_size)
    ascent_ratio  = 0.88,  -- portion of font_size above baseline
    descent_ratio = 0.15,  -- portion of font_size below baseline
    vert_pad      = 4,     -- extra vertical padding (px) on top and bottom
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
