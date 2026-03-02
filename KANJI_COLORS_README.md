# Kanji Semantic Color Coding

## Overview
The popup now displays kanji with **intelligent color coding** based on their semantic meaning. This helps with instant visual recognition and creates stronger memory associations.

## File Structure
```
jpdb-mpv-plugin/
├── main.lua                      # Main plugin code
├── jpdb-config.lua               # General configuration
├── kanji-semantic-colors.lua     # ⭐ Kanji color categories (edit this!)
├── kanji_meanings.json           # Kanji meanings database
└── KANJI_COLORS_README.md        # This file
```

## How It Works
Each kanji's English meaning is matched against keyword lists in `kanji-semantic-colors.lua`. When a match is found, the kanji is rendered in the corresponding category color.

## Color Categories

### 🔴 RED - Action/Movement
**Color:** `&H3333FF&` (Bright Red)  
**Meanings:** go, move, walk, run, fly, jump, enter, exit, throw, pull, push, carry, etc.  
**Purpose:** Represents dynamic actions and movement verbs

### 💜 MAGENTA - Emotion/Mind
**Color:** `&HFF33FF&` (Magenta)  
**Meanings:** feel, think, heart, mind, love, happy, sad, know, understand, etc.  
**Purpose:** Represents mental states, emotions, and cognition

### 💚 GREEN - Nature/Physical
**Color:** `&H33FF33&` (Bright Green)  
**Meanings:** tree, water, fire, earth, sun, moon, mountain, river, plant, etc.  
**Purpose:** Represents natural elements and the physical world

### 🧡 ORANGE - People/Social
**Color:** `&H3399FF&` (Orange)  
**Meanings:** person, man, woman, child, friend, family, body, hand, face, etc.  
**Purpose:** Represents people, social relations, and body parts

### 💙 CYAN - Time/Space
**Color:** `&HFFFF33&` (Cyan)  
**Meanings:** time, day, year, place, above, below, inside, outside, near, far, etc.  
**Purpose:** Represents temporal and spatial concepts

### 💛 YELLOW - Communication
**Color:** `&H33FFFF&` (Yellow)  
**Meanings:** say, speak, talk, word, voice, hear, write, read, book, etc.  
**Purpose:** Represents language and communication

### ⭐ DEFAULT - State Color
**Color:** Adaptive (based on card learning state)  
**Purpose:** Used for kanji that don't match any category

## Customization

### Adding New Keywords
Edit `kanji-semantic-colors.lua` and add keywords to any category:

```lua
-- In kanji-semantic-colors.lua
{
    color = '&H3333FF&',  -- RED
    alpha = '&H40&',
    keywords = {
        'go', 'move', 'walk',
        -- Add your keywords here
        'sprint', 'dash', 'leap'
    }
}
```

### Changing Colors
Colors are in **ASS BGR format** (`&HBBGGRR&`):
- `&H0000FF&` = Pure Red
- `&H00FF00&` = Pure Green  
- `&HFF0000&` = Pure Blue
- `&HFFFFFF&` = White
- `&H000000&` = Black

Example - Change Action/Movement to pure red in `kanji-semantic-colors.lua`:
```lua
{
    color = '&H0000FF&',  -- Changed from &H3333FF&
    alpha = '&H40&',
    keywords = { ... }
}
```

### Adding New Categories
Add a new category to `kanji-semantic-colors.lua`:

```lua
-- At the end of the return table, before the closing }
{
    color = '&HFF00FF&',  -- Purple
    alpha = '&H40&',
    keywords = {
        'concept', 'abstract', 'theory', 'principle',
        'essence', 'fundamental', 'basic', 'core'
    }
}
```

### Adjusting Transparency
The `alpha` value controls transparency:
- `&H00&` = Fully opaque
- `&H40&` = Slightly transparent (default)
- `&H80&` = Half transparent
- `&HFF&` = Fully transparent

## Tips

1. **Order Matters:** Categories are checked in order. Put more specific categories first.

2. **Keyword Matching:** Uses Lua's `string.match()`, so partial matches work:
   - `'walk'` matches "walk", "walking", "walked"
   - Be careful with short words that might match unintentionally

3. **Testing:** Enable debug mode in `jpdb-config.lua` (`DEBUG_LOG = true`) to see which kanji get which colors

4. **Performance:** The system is optimized - adding more keywords has minimal impact

5. **Backup:** Keep a backup of `kanji-semantic-colors.lua` before making major changes

6. **Reload:** Changes take effect when you restart MPV or reload the script

## Examples

**Word:** 気持ち (kimochi - feeling)
- 気 (spirit) → 💜 MAGENTA (emotion/mind)
- 持 (have) → 🔴 RED (action)

**Word:** 人生 (jinsei - life)  
- 人 (person) → 🧡 ORANGE (people)
- 生 (life) → 💚 GREEN (nature/physical)

**Word:** 時間 (jikan - time)
- 時 (time) → 💙 CYAN (time/space)
- 間 (interval) → 💙 CYAN (time/space)

## Troubleshooting

**Kanji not getting colored?**
- Check if the English meaning contains any keywords
- Add the meaning to the appropriate category in config
- Verify the kanji exists in `kanji_meanings.json`

**Wrong color assigned?**
- Check keyword order - first match wins
- Make keywords more specific
- Move category higher in the list for priority

**Want to disable color coding?**
- Rename `kanji-semantic-colors.lua` to `kanji-semantic-colors.lua.bak`
- Or replace the file contents with: `return {}`
- The system will fall back to state colors for all kanji

**Want to share your color scheme?**
- Just share your `kanji-semantic-colors.lua` file!
- Others can drop it into their plugin folder
