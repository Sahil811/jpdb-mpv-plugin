-- jpdb-config.lua
-- User Configurations for JPDB MPV Plugin

-- ═══════════════════════════════════════════════════════════════════════════════
-- LAYOUT & TYPOGRAPHY (theme-independent — structure, spacing, font sizes)
-- ═══════════════════════════════════════════════════════════════════════════════

local DS = {
    -- ======== POPUP SETTINGS ========
    width       = 540,
    lbar_w      = 3,
    pad_h       = 14,
    pad_v       = 10,
    unit        = 5,
    btn_gap     = 3,

    -- Typography sizes
    fs_kanji    = 54,
    fs_reading  = 26,
    fs_pos      = 13,
    fs_gloss    = 23,
    fs_meta     = 14,
    fs_badge    = 12,
    fs_btn_act  = 15,
    fs_btn_rev  = 16,
    fs_shortcut = 10,
    fs_toast    = 14,

    -- Line heights
    lh_kanji    = 60,
    lh_reading  = 30,
    lh_pos      = 17,
    lh_gloss    = 27,
    lh_meta     = 17,
    lh_badge    = 18,
    lh_toast    = 22,
    divider_h   = 1,

    -- Button heights
    bh_action   = 28,
    bh_review   = 34,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- THEME PALETTES — All visual color tokens live here.
-- Each theme is a complete color set. Select with `theme = 'dark'` below.
-- Colors are ASS BGR format (&HBBGGRR&), alphas 00=opaque FF=transparent.
-- ═══════════════════════════════════════════════════════════════════════════════

local THEMES = {
    -- ── Dark (default) ─ warm charcoal with subtle depth ─────────────────────
    dark = {
        -- Surfaces
        bg_popup     = '&H0F0E0A&',
        bg_surface   = '&H1A1914&',
        bg_header    = '&H1C1A15&',
        bg_divider   = '&H2A2620&',

        -- Shadows
        shadow_ambient = '&H000000&',
        shadow_key     = '&H000000&',
        shadow_fill    = '&H000000&',

        -- Badge
        badge_alpha = '&HE0&',

        -- Text
        col_primary    = '&HFFFFFF&',
        col_secondary  = '&HC8C4BC&',
        col_tertiary   = '&H8A8680&',
        col_gloss_odd  = '&HF5F2EA&',
        col_gloss_even = '&HE0DCD6&',
        col_pos        = '&HA8B8CC&',
        col_freq       = '&H88A0B8&',
        col_shortcut   = '&H888882&',
        col_divider    = '&H504A40&',
        col_toast_ok   = '&H60C880&',
        col_toast_err  = '&H5050EE&',

        -- Pitch accent
        pitch_high  = '&H4343E0&',
        pitch_low   = '&HE16941&',
        pitch_conn  = '&H4343E0&',
        pitch_label = '&HC0A880&',

        -- Kanji breakdown decoration
        kanji_shadow    = '&H000000&',
        kanji_glow_alpha = '&H60&',
        kanji_dot_idle  = '&H808080&',
        kanji_strip_colors = {'&H3333FF&', '&HFF33FF&', '&H33FF33&', '&H3399FF&', '&HFFFF33&'},

        -- Buttons
        btn_add       = { bg='&H243428&', hov='&H384E38&', act='&H4A6448&' },
        btn_blacklist = { bg='&H281E28&', hov='&H402E40&', act='&H583A58&' },
        btn_nf        = { bg='&H1E2E28&', hov='&H2E4A3C&', act='&H3C6050&' },
        btn_nothing   = { bg='&H18186A&', hov='&H282890&', act='&H3838A8&' },
        btn_something = { bg='&H143878&', hov='&H205098&', act='&H2C62B0&' },
        btn_hard      = { bg='&H246888&', hov='&H3488A8&', act='&H44A0C0&' },
        btn_good      = { bg='&H1A6028&', hov='&H288040&', act='&H369C52&' },
        btn_easy      = { bg='&H603E10&', hov='&H805822&', act='&H9C7030&' },
        btn_neutral   = { bg='&H282218&', hov='&H3C3428&', act='&H504438&' },
        btn_hover_line = '&HFFFFFF&',
    },

    -- ── Light ─ clean paper-white with warm accents ──────────────────────────
    light = {
        bg_popup     = '&HFAF8F2&',
        bg_surface   = '&HFFFFFF&',
        bg_header    = '&HF5F0E8&',
        bg_divider   = '&HE0D8D0&',

        shadow_ambient = '&HC0B8B0&',
        shadow_key     = '&HA8A098&',
        shadow_fill    = '&HD0C8C0&',

        badge_alpha = '&HD0&',

        col_primary    = '&H1A1A1A&',
        col_secondary  = '&H444038&',
        col_tertiary   = '&H787068&',
        col_gloss_odd  = '&H2A2820&',
        col_gloss_even = '&H3A3830&',
        col_pos        = '&H885830&',
        col_freq       = '&H886848&',
        col_shortcut   = '&H989088&',
        col_divider    = '&HC8C0B8&',
        col_toast_ok   = '&H208840&',
        col_toast_err  = '&H2020CC&',

        pitch_high  = '&H2020C0&',
        pitch_low   = '&HC05828&',
        pitch_conn  = '&H2020C0&',
        pitch_label = '&H806840&',

        kanji_shadow    = '&HC0B8B0&',
        kanji_glow_alpha = '&H80&',
        kanji_dot_idle  = '&HC0B8B0&',
        kanji_strip_colors = {'&H4040FF&', '&HCC40CC&', '&H40CC40&', '&H4488FF&', '&HCCCC40&'},

        btn_add       = { bg='&HC8F0D0&', hov='&H98D8A0&', act='&H70C080&' },
        btn_blacklist = { bg='&HF0D0E8&', hov='&HE0A8D0&', act='&HD088C0&' },
        btn_nf        = { bg='&HC8E8D8&', hov='&H98D0B8&', act='&H70C0A0&' },
        btn_nothing   = { bg='&HD0D0F8&', hov='&HA8A8E8&', act='&H8888D8&' },
        btn_something = { bg='&HC0D8F0&', hov='&H98C0E0&', act='&H78A8D0&' },
        btn_hard      = { bg='&HB8E0F0&', hov='&H90C8E0&', act='&H70B0D0&' },
        btn_good      = { bg='&HB8E8C0&', hov='&H90D898&', act='&H70C878&' },
        btn_easy      = { bg='&HD0D8F0&', hov='&HB0C0E0&', act='&H98A8D0&' },
        btn_neutral   = { bg='&HE8E4DC&', hov='&HD8D0C8&', act='&HC8C0B8&' },
        btn_hover_line = '&H404040&',
    },

    -- ── Midnight ─ deep blue-black with cool highlights ─────────────────────
    midnight = {
        bg_popup     = '&H1A0A08&',
        bg_surface   = '&H240E0C&',
        bg_header    = '&H281210&',
        bg_divider   = '&H3A2220&',

        shadow_ambient = '&H000000&',
        shadow_key     = '&H080000&',
        shadow_fill    = '&H000000&',

        badge_alpha = '&HE0&',

        col_primary    = '&HFFE8E0&',
        col_secondary  = '&HC8B8B0&',
        col_tertiary   = '&H908880&',
        col_gloss_odd  = '&HF0E0D8&',
        col_gloss_even = '&HD8C8C0&',
        col_pos        = '&HCCAA88&',
        col_freq       = '&HB89878&',
        col_shortcut   = '&H887870&',
        col_divider    = '&H503828&',
        col_toast_ok   = '&H60C880&',
        col_toast_err  = '&H5050EE&',

        pitch_high  = '&H5050F0&',
        pitch_low   = '&HF07848&',
        pitch_conn  = '&H5050F0&',
        pitch_label = '&HC8A078&',

        kanji_shadow    = '&H000000&',
        kanji_glow_alpha = '&H50&',
        kanji_dot_idle  = '&H605850&',
        kanji_strip_colors = {'&H4040FF&', '&HFF40FF&', '&H40FF60&', '&H40A0FF&', '&HFFFF40&'},

        btn_add       = { bg='&H1C3828&', hov='&H2C5038&', act='&H3C6848&' },
        btn_blacklist = { bg='&H2C1828&', hov='&H402838&', act='&H583848&' },
        btn_nf        = { bg='&H1C2828&', hov='&H2C4038&', act='&H3C5848&' },
        btn_nothing   = { bg='&H1C186C&', hov='&H2C2890&', act='&H3C38A8&' },
        btn_something = { bg='&H183878&', hov='&H285098&', act='&H3862B0&' },
        btn_hard      = { bg='&H286888&', hov='&H3888A8&', act='&H48A0C0&' },
        btn_good      = { bg='&H1C6028&', hov='&H2C8040&', act='&H3C9C52&' },
        btn_easy      = { bg='&H603E18&', hov='&H805828&', act='&H9C7038&' },
        btn_neutral   = { bg='&H2C2018&', hov='&H403428&', act='&H544838&' },
        btn_hover_line = '&HFFC8B0&',
    },

    -- ── Solarized ─ Ethan Schoonover's iconic palette ───────────────────────
    solarized = {
        bg_popup     = '&H362B00&',  -- base03
        bg_surface   = '&H423607&',  -- base02
        bg_header    = '&H423607&',
        bg_divider   = '&H756E58&',  -- base01

        shadow_ambient = '&H000000&',
        shadow_key     = '&H1A1200&',
        shadow_fill    = '&H1A1200&',

        badge_alpha = '&HD8&',

        col_primary    = '&H94A4AD&',  -- base1 (light text)
        col_secondary  = '&H756E58&',  -- base01
        col_tertiary   = '&H657B83&',  -- base00
        col_gloss_odd  = '&H94A4AD&',
        col_gloss_even = '&H839496&',  -- base0
        col_pos        = '&H8B8E86&',  -- cyan-ish
        col_freq       = '&H7B6E54&',
        col_shortcut   = '&H657B83&',
        col_divider    = '&H756E58&',
        col_toast_ok   = '&H009985&',  -- green
        col_toast_err  = '&H2F32DC&',  -- red

        pitch_high  = '&H2F32DC&',  -- red
        pitch_low   = '&HD28B26&',  -- blue
        pitch_conn  = '&H2F32DC&',
        pitch_label = '&H756E58&',

        kanji_shadow    = '&H1A1200&',
        kanji_glow_alpha = '&H70&',
        kanji_dot_idle  = '&H657B83&',
        kanji_strip_colors = {'&H2F32DC&', '&HD33682&', '&H009985&', '&HD28B26&', '&H0089B5&'},

        btn_add       = { bg='&H0A6E58&', hov='&H10886E&', act='&H18A088&' },
        btn_blacklist = { bg='&H602840&', hov='&H783850&', act='&H904860&' },
        btn_nf        = { bg='&H0A5E58&', hov='&H107868&', act='&H189078&' },
        btn_nothing   = { bg='&H1C2078&', hov='&H283090&', act='&H3440A8&' },
        btn_something = { bg='&H18487A&', hov='&H286090&', act='&H3878A8&' },
        btn_hard      = { bg='&H2C688A&', hov='&H3C88A8&', act='&H4CA0C0&' },
        btn_good      = { bg='&H0A6828&', hov='&H148840&', act='&H20A052&' },
        btn_easy      = { bg='&H584818&', hov='&H706028&', act='&H887838&' },
        btn_neutral   = { bg='&H423607&', hov='&H584A18&', act='&H6E5E28&' },
        btn_hover_line = '&H94A4AD&',
    },

    -- ── Monokai ─ vibrant syntax-inspired dark theme ────────────────────────
    monokai = {
        bg_popup     = '&H222218&',
        bg_surface   = '&H302E28&',
        bg_header    = '&H383430&',
        bg_divider   = '&H484440&',

        shadow_ambient = '&H000000&',
        shadow_key     = '&H0A0A08&',
        shadow_fill    = '&H000000&',

        badge_alpha = '&HE0&',

        col_primary    = '&HF0F0E8&',
        col_secondary  = '&HD0CCC0&',
        col_tertiary   = '&H908E88&',
        col_gloss_odd  = '&HE8E8E0&',
        col_gloss_even = '&HD0D0C8&',
        col_pos        = '&HE87CF6&',  -- monokai pink (BGR of #F67CE8)
        col_freq       = '&H56DCE6&',  -- monokai yellow (BGR of #E6DC56)
        col_shortcut   = '&H787470&',
        col_divider    = '&H585450&',
        col_toast_ok   = '&H56E6A0&',  -- monokai green
        col_toast_err  = '&H6666F9&',  -- monokai red-orange

        pitch_high  = '&H6666F9&',  -- warm red
        pitch_low   = '&HE87CF6&',  -- pink
        pitch_conn  = '&H6666F9&',
        pitch_label = '&H56DCE6&',

        kanji_shadow    = '&H000000&',
        kanji_glow_alpha = '&H50&',
        kanji_dot_idle  = '&H585450&',
        kanji_strip_colors = {'&H6666F9&', '&HE87CF6&', '&H56E6A0&', '&H56DCE6&', '&HED9866&'},

        btn_add       = { bg='&H1C4830&', hov='&H2C6840&', act='&H3C8850&' },
        btn_blacklist = { bg='&H3C1840&', hov='&H582858&', act='&H703868&' },
        btn_nf        = { bg='&H1C3830&', hov='&H2C5040&', act='&H3C6850&' },
        btn_nothing   = { bg='&H242480&', hov='&H3434A0&', act='&H4444B8&' },
        btn_something = { bg='&H203C80&', hov='&H305498&', act='&H406CB0&' },
        btn_hard      = { bg='&H2C6C90&', hov='&H3C8CB0&', act='&H4CA4C8&' },
        btn_good      = { bg='&H206830&', hov='&H308848&', act='&H40A860&' },
        btn_easy      = { bg='&H604418&', hov='&H805C28&', act='&H987438&' },
        btn_neutral   = { bg='&H302C20&', hov='&H484030&', act='&H605840&' },
        btn_hover_line = '&HF0F0E8&',
    },
}

-- Theme order for cycling
local THEME_ORDER = { 'dark', 'light', 'midnight', 'solarized', 'monokai' }

-- ═══════════════════════════════════════════════════════════════════════════════
-- THEME APPLICATION — merges selected palette into DS
-- ═══════════════════════════════════════════════════════════════════════════════

local current_theme_name = nil

local function apply_theme(name)
    local palette = THEMES[name]
    if not palette then
        error('Unknown theme: ' .. tostring(name) .. '. Available: ' .. table.concat(THEME_ORDER, ', '))
    end
    current_theme_name = name
    -- Merge all palette keys into DS (flat merge; button tables are replaced wholesale)
    for k, v in pairs(palette) do
        DS[k] = v
    end
end

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

    -- Global width multiplier applied to server font metrics.
    -- Compensates for differences between our Go font metrics and libass's
    -- FreeType rendering. Use Ctrl+= / Ctrl+- in mpv to tune in real-time.
    -- Decrease if hover regions are too wide (edges inaccurate).
    width_scale  = 1.0,

    line_h       = 72,

    -- Border width used in ASS rendering (\bordN) — hit regions expand by this
    bord_w       = 2,

    -- Vertical hit region calibration (fractions of font_size)
    ascent_ratio  = 0.88,  -- portion of font_size above baseline
    descent_ratio = 0.15,  -- portion of font_size below baseline
    vert_pad      = 4,     -- extra vertical padding (px) on top and bottom
}


-- ═══════════════════════════════════════════════════════════════════════════════
-- ACTIVE THEME — Change this to switch themes.
-- Available: 'dark', 'light', 'midnight', 'solarized', 'monokai'
-- ═══════════════════════════════════════════════════════════════════════════════

apply_theme('dark')

-- Build BTN_MAP from current DS (must be called after apply_theme)
local function build_btn_map()
    return {
        add              = DS.btn_add,
        blacklist        = DS.btn_blacklist,
        ['never-forget'] = DS.btn_nf,
        nothing          = DS.btn_nothing,
        something        = DS.btn_something,
        hard             = DS.btn_hard,
        good             = DS.btn_good,
        easy             = DS.btn_easy,
    }
end

return {
    -- Set to true to write a debug log file (jpdb-debug.log) and verbose messages.
    -- Leave false in production — no file is created, dlog() is a no-op.
    DEBUG_LOG = false,

    SERVER_URL  = 'http://127.0.0.1:9726',
    
    -- Change the font family used for both subtitles and popup UI
    FONT_FAMILY = 'Yu Gothic UI',

    DS = DS,
    SUBTITLE_OVERLAY = SUBTITLE_OVERLAY,

    -- Theme system
    THEMES      = THEMES,
    THEME_ORDER = THEME_ORDER,
    apply_theme = apply_theme,
    build_btn_map = build_btn_map,
    get_theme_name = function() return current_theme_name end,

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

    BTN_MAP = build_btn_map(),

    BTN_SHORTCUTS = {
        nothing='1', something='2', hard='3', good='4', easy='5',
        add='A', blacklist='B', ['never-forget']='N',
    }
}
