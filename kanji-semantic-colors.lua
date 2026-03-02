-- kanji-semantic-colors.lua
-- Semantic color coding for kanji breakdown display
-- 
-- This file defines color categories for kanji based on their English meanings.
-- Each kanji is matched against keyword lists and colored accordingly for
-- instant visual recognition and better memory retention.
--
-- Colors are in ASS BGR format (&HBBGGRR&):
--   &H0000FF& = Red, &H00FF00& = Green, &HFF0000& = Blue
--   &HFFFFFF& = White, &H000000& = Black
--
-- Alpha values control transparency:
--   &H00& = Fully opaque, &H40& = Slightly transparent,
--   &H80& = Half transparent, &HFF& = Fully transparent

return {
    -- ═══════════════════════════════════════════════════════════════════════
    -- 🔴 RED - Action/Movement/Verbs
    -- ═══════════════════════════════════════════════════════════════════════
    -- Represents dynamic actions, movement, and change
    -- Use for: verbs of motion, transfer, transformation
    {
        color = '&H3333FF&',  -- Bright red
        alpha = '&H40&',
        keywords = {
            'go', 'come', 'move', 'walk', 'run', 'fly', 'jump', 'enter', 'exit', 'leave',
            'return', 'pass', 'cross', 'rise', 'fall', 'climb', 'descend', 'flow', 'pour',
            'throw', 'pull', 'push', 'carry', 'bring', 'take', 'send', 'receive', 'give',
            'get', 'obtain', 'reach', 'arrive', 'depart', 'travel', 'journey', 'ride',
            'drive', 'sail', 'swim', 'dance', 'roll', 'turn', 'spin', 'rotate', 'shake'
        }
    },
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- 💜 MAGENTA - Emotion/Mind/Cognition
    -- ═══════════════════════════════════════════════════════════════════════
    -- Represents mental states, emotions, and cognitive processes
    -- Use for: feelings, thoughts, mental activities, psychological states
    {
        color = '&HFF33FF&',  -- Magenta
        alpha = '&H40&',
        keywords = {
            'feel', 'think', 'heart', 'mind', 'love', 'emotion', 'thought', 'idea',
            'believe', 'know', 'understand', 'remember', 'forget', 'learn', 'study',
            'consider', 'ponder', 'reflect', 'meditate', 'contemplate', 'happy', 'sad',
            'angry', 'joy', 'sorrow', 'fear', 'worry', 'hope', 'wish', 'desire', 'like',
            'hate', 'prefer', 'enjoy', 'suffer', 'pain', 'pleasure', 'comfort', 'peace',
            'calm', 'spirit', 'soul', 'consciousness', 'awareness', 'sense'
        }
    },
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- 💚 GREEN - Nature/Physical/Elements
    -- ═══════════════════════════════════════════════════════════════════════
    -- Represents the natural world, elements, and physical phenomena
    -- Use for: plants, weather, celestial bodies, materials, animals
    {
        color = '&H33FF33&',  -- Bright green
        alpha = '&H40&',
        keywords = {
            'tree', 'wood', 'forest', 'plant', 'flower', 'grass', 'leaf', 'root', 'branch',
            'seed', 'water', 'river', 'sea', 'ocean', 'lake', 'rain', 'snow', 'ice', 'cloud',
            'mist', 'fire', 'flame', 'burn', 'heat', 'warm', 'earth', 'soil', 'ground', 'land',
            'mountain', 'hill', 'valley', 'field', 'stone', 'rock', 'sun', 'moon', 'star',
            'sky', 'heaven', 'wind', 'air', 'breath', 'storm', 'thunder', 'light', 'dark',
            'shadow', 'bright', 'shine', 'metal', 'gold', 'silver', 'iron', 'copper',
            'animal', 'bird', 'fish', 'insect', 'beast'
        }
    },
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- 🧡 ORANGE - People/Social/Body
    -- ═══════════════════════════════════════════════════════════════════════
    -- Represents people, social relationships, and human body
    -- Use for: person types, family, body parts, social interactions
    {
        color = '&H3399FF&',  -- Orange
        alpha = '&H40&',
        keywords = {
            'person', 'people', 'human', 'man', 'woman', 'child', 'baby', 'boy', 'girl',
            'adult', 'friend', 'family', 'parent', 'father', 'mother', 'brother', 'sister',
            'son', 'daughter', 'ancestor', 'king', 'lord', 'master', 'servant', 'slave',
            'teacher', 'student', 'scholar', 'sage', 'wise', 'body', 'hand', 'foot', 'head',
            'face', 'eye', 'ear', 'nose', 'mouth', 'tongue', 'finger', 'arm', 'leg', 'bone',
            'flesh', 'blood', 'skin', 'hair', 'tooth', 'nail', 'meet', 'gather', 'group',
            'society', 'community'
        }
    },
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- 💙 CYAN - Time/Space/Abstract
    -- ═══════════════════════════════════════════════════════════════════════
    -- Represents temporal and spatial concepts
    -- Use for: time periods, directions, positions, locations
    {
        color = '&HFFFF33&',  -- Cyan
        alpha = '&H40&',
        keywords = {
            'time', 'hour', 'minute', 'second', 'moment', 'day', 'night', 'morning',
            'evening', 'noon', 'week', 'month', 'year', 'season', 'spring', 'summer',
            'autumn', 'winter', 'age', 'era', 'past', 'present', 'future', 'now', 'then',
            'before', 'after', 'early', 'late', 'old', 'place', 'location', 'position',
            'direction', 'way', 'above', 'below', 'up', 'down', 'high', 'low', 'top',
            'bottom', 'front', 'back', 'left', 'right', 'side', 'center', 'middle',
            'inside', 'outside', 'in', 'out', 'between', 'near', 'far', 'distance',
            'space', 'room', 'interval', 'gap', 'boundary', 'edge', 'corner'
        }
    },
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- 💛 YELLOW - Communication/Language
    -- ═══════════════════════════════════════════════════════════════════════
    -- Represents language, communication, and expression
    -- Use for: speech, writing, listening, linguistic concepts
    {
        color = '&H33FFFF&',  -- Yellow
        alpha = '&H40&',
        keywords = {
            'say', 'speak', 'talk', 'tell', 'word', 'language', 'voice', 'sound', 'hear',
            'listen', 'ask', 'answer', 'question', 'reply', 'respond', 'call', 'name',
            'write', 'read', 'book', 'letter', 'character', 'text', 'document', 'record'
        }
    }
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- ADD YOUR OWN CATEGORIES HERE
    -- ═══════════════════════════════════════════════════════════════════════
    -- Example:
    -- {
    --     color = '&HFF00FF&',  -- Purple
    --     alpha = '&H40&',
    --     keywords = {
    --         'concept', 'abstract', 'theory', 'principle'
    --     }
    -- }
}
