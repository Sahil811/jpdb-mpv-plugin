# Solving Pixel-Accurate Hover Detection Over Rendered Text

## The Problem

This plugin renders color-coded Japanese subtitles as ASS overlays in mpv, then
needs to detect which word the user is hovering over to show a popup dictionary.
The challenge: **we don't control where the text renderer places each character
on screen**.

mpv uses **libass** (backed by FreeType/HarfBuzz) for text rendering. Our Lua
script receives raw mouse coordinates and must map them back to the correct
word — but libass provides no API to query rendered character positions.

### Why It's Hard

A naive approach — "each CJK character is `fontSize` pixels wide" — quickly
breaks down because:

- Character widths vary (CJK ≈ 1em, kana ≈ 0.85em, punctuation ≈ 0.3em,
  Latin ≈ 0.5em)
- The text renderer applies kerning, hinting, and grid-fitting
- Center-aligned text (`\an2`) means the left edge depends on the total rendered
  width, which we don't know exactly
- Small per-character errors accumulate across a line — a 0.3px/char error
  becomes 10px over 30 characters

## The Journey: What We Tried

### Attempt 1: Character Class Estimation

Classify every character into width buckets (half-width, full-width, halfwidth
katakana) and estimate pixel positions.

```
CJK (U+3000+)     → fontSize × 1.0  (full-width)
Latin / ASCII      → fontSize × 0.5  (half-width)
HW Katakana (FF65) → fontSize × 0.5  (exception)
```

**Result**: ~70% accuracy. Works near the center of short lines, breaks badly
at the edges of long lines. The estimates are too coarse — real glyph widths
vary significantly within each class.

### Attempt 2: Server-Side Font Metrics (Go `sfnt` Package)

Load the actual font file (`YuGothM.ttc` → "Yu Gothic UI") in Go using
`golang.org/x/image/font/sfnt` and compute real per-glyph advance widths
with kerning:

```go
adv, _ := font.GlyphAdvance(&buf, glyphIdx, ppem, font.HintingNone)
cumPx += float64(adv) / 64.0  // 26.6 fixed-point → float
```

Send the cumulative pixel map (`px_map`) to the Lua client alongside parse
results.

**Result**: ~80% accuracy. Better character ratios, but a systematic drift
appeared — accuracy was asymmetric (fixing left edge broke right edge). A
uniform scale factor (`width_scale`) couldn't fix both sides.

**Root cause discovered**: Our Go `sfnt` returns **fractional** pixel advances
(e.g., 48.7px). FreeType in libass applies **integer grid-fitting** (rounds
each advance to whole pixels). Over 30+ characters, the fractional remainders
accumulate in one direction.

### Attempt 3: Integer Rounding

Round each glyph advance to nearest integer before accumulating, matching
FreeType's grid-fitting:

```go
cumPx += math.Round(float64(adv) / 64.0)  // not just float division!
```

**Result**: Marginal improvement. The asymmetric drift reduced but didn't
disappear. Other factors were at play — hinting differences, potential font
face mismatches, GPOS table handling.

### Attempt 4: `compute_bounds` — Let libass Tell Us (✅ Solution)

The breakthrough: **stop trying to independently match the renderer. Ask it
directly.**

mpv's `osd-overlay` command supports a `compute_bounds` parameter that returns
the actual bounding box of rendered ASS text — measured by the same libass
engine that displays it:

```lua
local res = mp.command_native({
    name = 'osd-overlay',
    id = 99,                    -- dedicated measurement overlay
    format = 'ass-events',
    data = '{\\an2\\pos(640,360)\\fnYu Gothic UI\\fsp0\\bord0\\shad0\\fs60}text here',
    res_x = osd_w, res_y = osd_h,
    compute_bounds = true,      -- the magic parameter
})
-- res.x0 = left edge,  res.x1 = right edge  (in OSD pixels)
-- width = res.x1 - res.x0  (exact as rendered by libass)
```

This gives us the **exact rendered width and position** from libass itself.

#### Two-Level Calibration

1. **Per-line total width**: Measure the full line → get exact `x0` (left
   edge) and total width. This fixes the centering mismatch completely.

2. **Per-token boundary positions**: For each token (word) boundary, measure
   the prefix text up to that byte position:
   ```
   Line:   "中にはいるんだよ"
   Tokens: [中に, は, いるん, だ, よ]
   
   Measure "中に"           → width₁ (exact pixel position of boundary 1)
   Measure "中には"         → width₂ (boundary 2)
   Measure "中にはいるん"   → width₃ (boundary 3)
   Measure "中にはいるんだ" → width₄ (boundary 4)
   Full line               → width₅ (already known)
   ```

   Now each token's pixel range is `[widthᵢ, widthᵢ₊₁]` — measured by libass,
   not approximated.

#### Hit Detection

With exact token boundaries, hit detection becomes trivial:

```lua
local px_offset = mouse_x - line_x0  -- offset from line's left edge

for _, region in ipairs(token_regions) do
    if px_offset >= region.px0 and px_offset < region.px1 then
        return region.token  -- exact match!
    end
end

-- Gap fallback: snap to nearest token center
```

No font metrics, no scale factors, no byte-to-pixel conversion. Just direct
comparison against measured boundaries.

## Architecture

```
┌─────────┐   subtitle text    ┌──────────┐  px_map (ratios)  ┌──────────┐
│  mpv     │ ────────────────→ │  Go      │ ───────────────→ │  Lua     │
│  player  │                   │  server  │                   │  plugin  │
│          │ ←──── ASS ─────── │          │                   │          │
│  libass  │   (renders text)  │ sfnt pkg │                   │          │
│          │                   └──────────┘                   │          │
│          │ ←── compute_bounds ──────────────────────────── │          │
│          │ ───→ {x0, x1} ──────────────────────────────→   │          │
│          │                                                  │          │
│          │ ←── mouse-pos ──────────────────────────────→   │          │
│          │                                                  │ hit test │
└─────────┘                                                  └──────────┘
```

The server-side font metrics still serve as a **fallback** (for mpv versions
without `compute_bounds`) and provide per-character width **ratios** used when
a full line measurement is available but per-boundary measurements aren't.

## Key Lessons

### 1. Don't Fight the Renderer — Query It

If your text renderer doesn't expose character positions, check if it exposes
bounding box queries. Even a total-width measurement is enormously valuable
because it eliminates centering error and provides a calibration anchor.

### 2. Fractional Errors Accumulate Directionally

When computing cumulative positions (character 1 + character 2 + ...), rounding
behavior matters. If you round differently than the renderer, errors don't
cancel — they accumulate left-to-right, causing asymmetric drift. Always match
the renderer's rounding strategy.

### 3. Scale Factors Can't Fix Ratio Problems

A uniform `width_scale` multiplier can correct total width but can't fix
per-character ratio errors. If character A is 2% too wide and character B is
2% too narrow, no single scale fixes both. You need per-boundary measurements
or matching the renderer's exact algorithm.

### 4. Font Face Identity Matters

"Yu Gothic" and "Yu Gothic UI" are different fonts in the same `.ttc` file.
Loading face[0] when the renderer uses face[1] gives plausible but wrong
metrics. Always verify the exact font face name and index.

### 5. Layer Your Solutions

Our final system uses three layers, each improving on the last:

| Layer | Accuracy | Cost | When Used |
|-------|----------|------|-----------|
| Character class estimation | ~70% | Zero (pure math) | Fallback if server unavailable |
| Server font metrics (Go sfnt) | ~80% | One HTTP call per subtitle | Fallback if compute_bounds unavailable |
| compute_bounds per-line | ~92% | 1 mpv call per line per subtitle | Primary calibration |
| compute_bounds per-boundary | ~99% | N calls per line (N = token count) | Full accuracy mode |

Each layer is a graceful fallback — the system never breaks, just degrades.

### 6. Cache Aggressively

`compute_bounds` triggers a full libass render internally. Cache results by
`(text, font_size, osd_width, osd_height)` and invalidate only when subtitles
change.

## Applicability Beyond This Project

This pattern applies to any application that needs to detect hover/click
positions within renderer-controlled text:

- **Electron/browser**: Use `Range.getBoundingClientRect()` or
  `canvas.measureText()` instead of guessing CSS text layout
- **Game engines**: Use the engine's `Font.MeasureString()` or equivalent
- **PDF viewers**: Use the PDF text extraction API for character positions
- **Terminal UIs**: Use `wcwidth()` for character display widths, not byte
  counts
- **Any 2D overlay**: If you can't query the renderer, render each word as a
  separate positioned element with known coordinates

The universal principle: **let the renderer measure what it rendered**, rather
than independently computing what you think it rendered.
