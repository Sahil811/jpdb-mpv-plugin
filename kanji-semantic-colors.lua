-- kanji-semantic-colors.lua
-- Semantic color coding for kanji breakdown display
--
-- Colors are in ASS BGR format (&HBBGGRR&):
--   &H0000FF& = Red,    &H00FF00& = Green,   &HFF0000& = Blue
--   &HFF33FF& = Magenta, &H33FFFF& = Yellow,  &HFFFF33& = Cyan
--
-- Alpha: &H00& = Fully opaque → &HFF& = Fully transparent
--
-- ┌──────────────────────────────────────────────────────────┐
-- │  CATEGORY MAP                                            │
-- │  🔴 RED       → Action / Movement / Physical Verbs       │
-- │  💜 MAGENTA   → Emotion / Mind / Cognition               │
-- │  💚 GREEN     → Nature / Elements / Animals / Plants     │
-- │  🧡 ORANGE    → People / Body / Social / Family          │
-- │  💛 YELLOW    → Communication / Language / Arts          │
-- │  🩵 CYAN      → Time / Space / Direction / Position      │
-- │  🔵 BLUE      → Power / Law / Society / Military         │
-- │  🟣 PURPLE    → Abstract / Logic / Quantity / Change     │
-- │  🟤 BROWN     → Work / Tools / Food / Clothing / Objects │
-- │  🩶 SILVER    → State / Quality / Condition / Morality   │
-- │  🌸 PINK      → Life / Growth / Reproduction / Health    │
-- │  🟠 AMBER     → Learning / Knowledge / Science / Skill   │
-- └──────────────────────────────────────────────────────────┘

return {

    -- ═══════════════════════════════════════════════════════════════════════
    -- 🔴 RED - Action / Movement / Physical Verbs
    -- ═══════════════════════════════════════════════════════════════════════
    -- Dynamic physical actions, motion, and transformation.
    {
        color = '&H1111EE&',  -- Vivid red
        alpha = '&H30&',
        keywords = {
            -- Locomotion
            'go', 'come', 'move', 'walk', 'run', 'sprint', 'fly', 'soar', 'glide',
            'jump', 'leap', 'hop', 'skip', 'step', 'march', 'parade', 'trudge', 'stroll',
            'enter', 'exit', 'leave', 'depart', 'arrive', 'return', 'pass', 'cross',
            'rise', 'fall', 'ascend', 'descend', 'climb', 'scale', 'plunge', 'sink',
            'flow', 'pour', 'gush', 'drip', 'leak', 'spill', 'rush', 'dash', 'race',
            'flee', 'escape', 'chase', 'pursue', 'follow', 'lead', 'guide',
            'wander', 'roam', 'drift', 'stray', 'explore', 'advance', 'retreat',
            'slide', 'slip', 'crawl', 'creep', 'sneak', 'prowl', 'lurk',
            'travel', 'journey', 'ride', 'drive', 'sail', 'row', 'paddle', 'swim',
            'float', 'dive', 'surface', 'orbit', 'circle', 'loop',
            -- Transfer & carry
            'throw', 'toss', 'fling', 'hurl', 'launch', 'shoot',
            'pull', 'drag', 'haul', 'tug', 'yank',
            'push', 'shove', 'nudge', 'press',
            'carry', 'bear', 'transport', 'convey', 'deliver',
            'bring', 'take', 'fetch', 'retrieve', 'collect',
            'send', 'dispatch', 'forward', 'transfer',
            'receive', 'accept', 'obtain', 'acquire', 'gain', 'get', 'grab', 'seize',
            'reach', 'extend', 'stretch',
            -- Body movement
            'dance', 'roll', 'turn', 'spin', 'rotate', 'revolve', 'twist', 'coil',
            'shake', 'tremble', 'shiver', 'quiver', 'vibrate', 'wave', 'swing',
            'bow', 'kneel', 'crouch', 'bend', 'lean', 'tilt',
            'stand', 'sit', 'squat', 'lie', 'rest', 'sleep', 'wake', 'rise',
            'lift', 'raise', 'lower', 'hang', 'suspend', 'balance',
            -- Destructive / forceful acts
            'hit', 'strike', 'beat', 'punch', 'kick', 'stomp', 'slam', 'smash',
            'cut', 'slice', 'chop', 'slash', 'stab', 'pierce', 'tear', 'rip', 'shred',
            'break', 'shatter', 'crush', 'grind', 'pound', 'smash', 'destroy',
            'scratch', 'scrape', 'rub', 'polish', 'carve', 'engrave',
            -- Constructive / manipulative acts
            'bend', 'fold', 'wrap', 'bundle', 'pack', 'seal',
            'open', 'close', 'shut', 'lock', 'unlock',
            'tie', 'bind', 'fasten', 'knot', 'lace',
            'release', 'untie', 'loosen', 'free',
            'catch', 'hold', 'grip', 'grasp', 'clutch', 'squeeze',
            'drop', 'release', 'let', 'place', 'put', 'set', 'lay',
            'attach', 'fix', 'install', 'mount', 'embed',
            'remove', 'detach', 'peel', 'strip', 'extract', 'pull out',
            'insert', 'fill', 'load', 'empty', 'pour', 'drain',
            'mix', 'blend', 'stir', 'combine', 'merge',
            'separate', 'split', 'divide', 'cut', 'sever',
            'join', 'connect', 'link', 'attach', 'unite',
            'dig', 'excavate', 'bury', 'plant', 'sow',
            'cover', 'uncover', 'hide', 'reveal', 'expose',
            'gather', 'pile', 'stack', 'arrange', 'organize', 'sort',
            'scatter', 'spread', 'distribute', 'disperse'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 💜 MAGENTA - Emotion / Mind / Cognition / Will
    -- ═══════════════════════════════════════════════════════════════════════
    -- Internal mental and emotional experience.
    {
        color = '&HEE11EE&',  -- Vivid magenta
        alpha = '&H30&',
        keywords = {
            -- Core cognition
            'think', 'thought', 'idea', 'concept', 'notion', 'theory',
            'know', 'knowledge', 'understand', 'comprehend', 'grasp', 'realize',
            'learn', 'study', 'memorize', 'remember', 'recall', 'recollect',
            'forget', 'overlook', 'ignore',
            'consider', 'ponder', 'deliberate', 'reflect', 'contemplate', 'meditate',
            'imagine', 'visualize', 'fantasize', 'dream', 'envision',
            'perceive', 'notice', 'observe', 'sense', 'detect', 'recognize',
            'judge', 'evaluate', 'assess', 'critique', 'analyze', 'examine',
            'decide', 'choose', 'select', 'determine', 'resolve',
            'doubt', 'question', 'suspect', 'wonder', 'speculate', 'guess',
            'expect', 'anticipate', 'predict', 'assume', 'suppose', 'believe',
            'intend', 'plan', 'purpose', 'aim', 'goal', 'motive', 'reason',
            'interpret', 'conclude', 'infer', 'deduce', 'reason', 'logic',
            'discover', 'find', 'investigate', 'research', 'explore',
            -- Emotions — positive
            'happy', 'joy', 'delight', 'bliss', 'elation', 'ecstasy', 'cheerful',
            'glad', 'pleased', 'satisfied', 'content', 'grateful', 'thankful',
            'love', 'affection', 'adore', 'cherish', 'treasure', 'fond',
            'hope', 'wish', 'desire', 'dream', 'aspire', 'yearn', 'long',
            'like', 'prefer', 'enjoy', 'relish', 'appreciate',
            'excited', 'enthusiastic', 'eager', 'passionate', 'inspired', 'motivated',
            'proud', 'confident', 'brave', 'courageous', 'bold', 'daring',
            'calm', 'peaceful', 'serene', 'tranquil', 'relaxed', 'comfort',
            'curious', 'interested', 'fascinated', 'amazed', 'wonder', 'awe',
            -- Emotions — negative
            'sad', 'sorrow', 'grief', 'despair', 'misery', 'melancholy', 'lament',
            'cry', 'weep', 'sob', 'mourn',
            'angry', 'rage', 'fury', 'wrath', 'irritate', 'annoy', 'frustrate',
            'hate', 'despise', 'loathe', 'resent', 'envy', 'jealous',
            'fear', 'terror', 'dread', 'frighten', 'scare', 'panic', 'horror',
            'worry', 'anxious', 'nervous', 'uneasy', 'stress', 'tension',
            'shame', 'guilt', 'regret', 'remorse', 'embarrass', 'humiliate',
            'lonely', 'isolated', 'abandoned', 'lost', 'confused', 'bewildered',
            'bored', 'indifferent', 'apathetic', 'numb', 'empty',
            'suffer', 'pain', 'anguish', 'torment', 'distress',
            'disgust', 'repulse', 'reject', 'deny', 'refuse',
            'disappointed', 'disillusioned', 'betrayed', 'hurt',
            -- Inner self
            'heart', 'mind', 'soul', 'spirit', 'self', 'ego', 'identity',
            'consciousness', 'awareness', 'subconsciousness', 'instinct', 'intuition',
            'will', 'determination', 'resolve', 'discipline', 'patience', 'endurance',
            'nature', 'character', 'personality', 'attitude', 'mood', 'disposition',
            'sense', 'feeling', 'emotion', 'sentiment', 'impression'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 💚 GREEN - Nature / Elements / Animals / Plants
    -- ═══════════════════════════════════════════════════════════════════════
    -- The natural world in all its forms.
    {
        color = '&H11EE11&',  -- Vivid green
        alpha = '&H30&',
        keywords = {
            -- Flora
            'tree', 'wood', 'forest', 'grove', 'jungle', 'woodland', 'thicket',
            'plant', 'flower', 'blossom', 'bloom', 'petal', 'bud', 'sprout',
            'grass', 'lawn', 'meadow', 'herb', 'weed', 'fern', 'moss', 'algae',
            'leaf', 'leaves', 'foliage', 'canopy',
            'root', 'trunk', 'bark', 'branch', 'twig', 'stem', 'stalk', 'vine',
            'seed', 'spore', 'pod', 'nut', 'cone', 'fruit', 'berry',
            'grain', 'rice', 'wheat', 'bamboo', 'pine', 'cedar', 'oak', 'cherry',
            'maple', 'willow', 'plum', 'rose', 'lotus', 'chrysanthemum',
            'crop', 'harvest', 'field', 'cultivate', 'wither', 'bloom', 'grow',
            -- Water
            'water', 'river', 'stream', 'creek', 'brook', 'canal', 'channel',
            'sea', 'ocean', 'bay', 'gulf', 'strait', 'coast', 'shore', 'beach',
            'lake', 'pond', 'swamp', 'marsh', 'wetland',
            'waterfall', 'spring', 'well', 'fountain', 'geyser',
            'rain', 'drizzle', 'shower', 'downpour', 'flood', 'drought',
            'snow', 'blizzard', 'sleet', 'hail', 'frost', 'ice', 'glacier',
            'fog', 'mist', 'dew', 'humidity', 'moisture',
            'wave', 'tide', 'current', 'whirlpool', 'ripple',
            -- Fire
            'fire', 'flame', 'blaze', 'inferno', 'wildfire', 'spark', 'ember',
            'burn', 'scorch', 'char', 'smolder', 'ignite', 'extinguish',
            'smoke', 'ash', 'soot', 'heat', 'warmth', 'glow', 'torch', 'candle',
            -- Earth & terrain
            'earth', 'soil', 'dirt', 'clay', 'mud', 'gravel', 'sand', 'dust',
            'ground', 'land', 'terrain', 'landscape', 'wilderness',
            'mountain', 'peak', 'summit', 'ridge', 'cliff', 'slope', 'hill',
            'valley', 'canyon', 'gorge', 'ravine', 'chasm',
            'plain', 'plateau', 'steppe', 'tundra', 'desert', 'oasis',
            'island', 'peninsula', 'cape', 'continent',
            'cave', 'cavern', 'tunnel', 'crater',
            -- Stone & minerals
            'stone', 'rock', 'boulder', 'pebble',
            'metal', 'ore', 'mineral', 'crystal',
            'gold', 'silver', 'iron', 'steel', 'copper', 'bronze', 'tin', 'lead',
            'coal', 'jade', 'jewel', 'gem', 'diamond', 'ruby', 'sapphire',
            -- Sky & weather
            'sky', 'heaven', 'atmosphere', 'horizon',
            'sun', 'sunrise', 'sunset', 'solar', 'ray', 'beam',
            'moon', 'lunar', 'crescent', 'full moon',
            'star', 'constellation', 'galaxy', 'comet', 'meteor',
            'cloud', 'overcast', 'clear', 'rainbow',
            'wind', 'breeze', 'gust', 'gale', 'typhoon', 'cyclone', 'tornado',
            'storm', 'thunder', 'lightning', 'bolt',
            -- Light & dark
            'light', 'bright', 'shine', 'glow', 'gleam', 'sparkle', 'twinkle',
            'dark', 'darkness', 'shadow', 'shade', 'dim', 'dusk', 'night',
            'air', 'breath', 'oxygen', 'atmosphere',
            -- Animals
            'animal', 'creature', 'beast', 'monster', 'wild',
            'bird', 'sparrow', 'swallow', 'crane', 'hawk', 'eagle', 'raven', 'crow',
            'owl', 'pheasant', 'duck', 'goose', 'swan', 'parrot', 'peacock',
            'fish', 'salmon', 'carp', 'shark', 'whale', 'dolphin', 'octopus',
            'crab', 'lobster', 'shrimp', 'clam', 'oyster', 'squid',
            'insect', 'butterfly', 'bee', 'ant', 'beetle', 'dragonfly', 'cicada',
            'grasshopper', 'mosquito', 'fly', 'worm', 'spider',
            'horse', 'cow', 'ox', 'bull', 'pig', 'sheep', 'goat',
            'dog', 'cat', 'rabbit', 'mouse', 'rat', 'squirrel',
            'deer', 'elk', 'boar', 'bear', 'wolf', 'fox', 'tanuki', 'raccoon',
            'tiger', 'lion', 'leopard', 'panther',
            'monkey', 'ape', 'elephant', 'rhinoceros', 'hippopotamus',
            'snake', 'viper', 'cobra', 'python', 'lizard', 'gecko', 'crocodile',
            'turtle', 'tortoise', 'frog', 'toad', 'salamander',
            'dragon', 'phoenix', 'kirin', 'tengu',
            -- Animal parts
            'feather', 'claw', 'fang', 'horn', 'hoof', 'paw', 'wing', 'tail',
            'fur', 'scale', 'shell', 'mane', 'whisker', 'tusk', 'fin', 'gill'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 🧡 ORANGE - People / Body / Social / Family
    -- ═══════════════════════════════════════════════════════════════════════
    -- People, roles, relationships, human anatomy, and social interaction.
    {
        color = '&H1188FF&',  -- Orange
        alpha = '&H30&',
        keywords = {
            -- Generic people
            'person', 'people', 'human', 'mankind', 'being', 'individual',
            'man', 'woman', 'male', 'female', 'boy', 'girl', 'child', 'baby',
            'infant', 'toddler', 'youth', 'teen', 'adult', 'elder', 'old',
            -- Roles & occupations
            'king', 'queen', 'emperor', 'empress', 'prince', 'princess',
            'lord', 'noble', 'aristocrat', 'samurai',
            'master', 'servant', 'slave', 'retainer', 'follower', 'disciple',
            'soldier', 'warrior', 'knight', 'guard', 'spy', 'ninja', 'ronin',
            'priest', 'monk', 'nun', 'shaman', 'diviner', 'exorcist',
            'doctor', 'healer', 'midwife', 'pharmacist',
            'teacher', 'professor', 'instructor', 'tutor',
            'student', 'pupil', 'apprentice', 'beginner',
            'scholar', 'intellectual', 'philosopher', 'sage', 'wise',
            'artist', 'painter', 'sculptor', 'poet', 'author', 'writer',
            'musician', 'singer', 'dancer', 'actor', 'performer',
            'merchant', 'trader', 'vendor', 'shopkeeper',
            'farmer', 'fisherman', 'hunter', 'miner', 'woodcutter',
            'carpenter', 'blacksmith', 'potter', 'weaver', 'tailor',
            'cook', 'chef', 'baker', 'brewer',
            'builder', 'architect', 'engineer',
            'official', 'minister', 'bureaucrat', 'clerk',
            'judge', 'magistrate', 'detective', 'police',
            'spy', 'thief', 'bandit', 'criminal', 'outlaw',
            'hero', 'villain', 'champion', 'legend',
            'stranger', 'foreigner', 'visitor', 'guest', 'host',
            'neighbor', 'citizen', 'resident', 'refugee', 'exile',
            -- Family
            'family', 'clan', 'tribe', 'kin', 'relative', 'lineage', 'generation',
            'parent', 'father', 'mother', 'stepfather', 'stepmother',
            'brother', 'sister', 'sibling', 'twin',
            'son', 'daughter', 'child', 'offspring',
            'husband', 'wife', 'spouse', 'couple', 'partner',
            'grandfather', 'grandmother', 'grandparent', 'grandchild',
            'uncle', 'aunt', 'nephew', 'niece', 'cousin',
            'ancestor', 'descendant', 'heir', 'successor',
            'friend', 'companion', 'ally', 'rival', 'enemy',
            -- Body — head
            'head', 'skull', 'brain', 'face', 'forehead', 'temple',
            'eye', 'eyebrow', 'eyelid', 'pupil', 'iris',
            'ear', 'eardrum',
            'nose', 'nostril',
            'mouth', 'lip', 'tongue', 'tooth', 'teeth', 'gum', 'jaw', 'chin',
            'cheek', 'throat', 'neck',
            'hair', 'beard', 'mustache', 'eyebrow',
            -- Body — trunk
            'body', 'torso', 'chest', 'breast', 'belly', 'abdomen', 'stomach',
            'back', 'spine', 'shoulder', 'hip', 'waist', 'side', 'rib',
            -- Body — limbs
            'arm', 'elbow', 'wrist', 'hand', 'fist', 'palm', 'finger', 'thumb', 'nail',
            'leg', 'thigh', 'knee', 'ankle', 'foot', 'heel', 'sole', 'toe',
            -- Body — internal & material
            'bone', 'marrow', 'muscle', 'tendon', 'nerve', 'vein', 'artery',
            'blood', 'flesh', 'fat', 'skin', 'pore', 'sweat',
            'heart', 'lung', 'liver', 'kidney', 'intestine', 'stomach',
            'organ', 'cell', 'breath', 'pulse',
            -- Social interaction
            'meet', 'gather', 'assemble', 'unite', 'disperse',
            'group', 'team', 'crowd', 'mob', 'pair', 'couple',
            'society', 'community', 'village', 'city', 'nation',
            'marry', 'wed', 'divorce', 'engagement',
            'birth', 'born', 'die', 'death', 'funeral', 'burial',
            'greet', 'welcome', 'farewell', 'bow',
            'fight', 'argue', 'quarrel', 'reconcile', 'forgive',
            'agree', 'disagree', 'negotiate', 'compromise',
            'help', 'assist', 'support', 'cooperate', 'collaborate',
            'compete', 'challenge', 'oppose', 'betray', 'sacrifice'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 💛 YELLOW - Communication / Language / Arts / Expression
    -- ═══════════════════════════════════════════════════════════════════════
    -- All forms of human expression — spoken, written, performed, visual.
    {
        color = '&H11EEEE&',  -- Vivid yellow
        alpha = '&H30&',
        keywords = {
            -- Speech
            'say', 'speak', 'talk', 'utter', 'pronounce', 'articulate', 'express',
            'tell', 'narrate', 'recount', 'relay', 'report', 'inform',
            'ask', 'inquire', 'question', 'interrogate', 'interview',
            'answer', 'reply', 'respond', 'retort', 'counter',
            'call', 'summon', 'shout', 'yell', 'scream', 'cry', 'roar',
            'whisper', 'murmur', 'mutter', 'mumble', 'grumble',
            'sing', 'chant', 'hum', 'melody', 'song', 'lyric', 'verse',
            'laugh', 'giggle', 'chuckle', 'snicker', 'mock', 'tease',
            'sigh', 'groan', 'moan', 'gasp',
            -- Communication acts
            'announce', 'declare', 'proclaim', 'broadcast', 'publish',
            'promise', 'vow', 'swear', 'oath', 'pledge',
            'warn', 'caution', 'threaten', 'intimidate',
            'advise', 'suggest', 'recommend', 'guide', 'instruct',
            'teach', 'lecture', 'explain', 'describe', 'illustrate', 'demonstrate',
            'discuss', 'debate', 'argue', 'dispute', 'negotiate',
            'persuade', 'convince', 'seduce', 'tempt',
            'praise', 'compliment', 'flatter', 'glorify', 'honor',
            'insult', 'scold', 'criticize', 'blame', 'accuse', 'slander',
            'apologize', 'confess', 'admit', 'deny', 'lie', 'deceive', 'trick',
            'beg', 'plead', 'request', 'demand', 'command', 'order',
            'greet', 'introduce', 'address',
            'agree', 'consent', 'refuse', 'reject', 'object',
            -- Language & text
            'word', 'term', 'phrase', 'sentence', 'paragraph', 'passage',
            'language', 'tongue', 'dialect', 'accent', 'grammar', 'syntax',
            'meaning', 'definition', 'concept', 'nuance', 'context',
            'voice', 'sound', 'tone', 'pitch', 'volume', 'rhythm', 'accent',
            'hear', 'listen', 'overhear', 'eavesdrop',
            'write', 'compose', 'draft', 'author', 'pen',
            'read', 'skim', 'scan', 'decode', 'decipher',
            'name', 'title', 'label', 'call', 'term', 'designate',
            'translate', 'interpret', 'transcribe', 'paraphrase',
            'copy', 'transcribe', 'plagiarize',
            'letter', 'character', 'script', 'glyph', 'rune', 'hieroglyph',
            'text', 'manuscript', 'scroll', 'document', 'contract', 'certificate',
            'book', 'novel', 'tale', 'story', 'legend', 'myth', 'fable',
            'poem', 'haiku', 'sonnet', 'epic', 'ballad',
            'note', 'diary', 'journal', 'letter', 'message', 'memo',
            'record', 'list', 'register', 'catalog', 'index',
            'chapter', 'page', 'line', 'column', 'margin',
            'print', 'stamp', 'seal', 'sign', 'mark', 'symbol', 'logo', 'emblem',
            -- Arts & performance
            'art', 'artwork', 'masterpiece', 'creation',
            'draw', 'sketch', 'illustrate', 'outline', 'trace',
            'paint', 'color', 'shade', 'blend', 'stroke',
            'sculpt', 'carve', 'mold', 'cast',
            'picture', 'image', 'portrait', 'landscape', 'mural', 'fresco',
            'photograph', 'capture', 'depict', 'represent',
            'design', 'pattern', 'motif', 'decoration', 'ornament',
            'style', 'genre', 'form', 'composition', 'structure',
            'music', 'tune', 'rhythm', 'beat', 'tempo', 'harmony', 'chord',
            'instrument', 'string', 'drum', 'flute', 'lute', 'koto', 'shamisen',
            'perform', 'play', 'act', 'stage', 'theater', 'drama', 'comedy', 'tragedy',
            'dance', 'choreograph', 'recital', 'concert', 'festival', 'ceremony'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 🩵 CYAN - Time / Space / Direction / Position
    -- ═══════════════════════════════════════════════════════════════════════
    -- Temporal and spatial orientation — when and where.
    {
        color = '&HEEEE11&',  -- Vivid cyan
        alpha = '&H30&',
        keywords = {
            -- Time — units
            'time', 'moment', 'instant', 'second', 'minute', 'hour',
            'day', 'week', 'month', 'year', 'decade', 'century', 'millennium',
            'era', 'epoch', 'age', 'period', 'phase', 'cycle', 'term', 'duration',
            'interval', 'pause', 'break', 'delay', 'deadline',
            -- Time — parts of day
            'dawn', 'morning', 'noon', 'afternoon', 'evening', 'dusk', 'night', 'midnight',
            'sunrise', 'sunset', 'twilight',
            -- Time — seasons
            'spring', 'summer', 'autumn', 'fall', 'winter', 'season',
            'solstice', 'equinox', 'monsoon',
            -- Time — relative
            'past', 'history', 'before', 'previous', 'prior', 'former', 'once', 'ago',
            'present', 'now', 'current', 'today', 'at once', 'immediately',
            'future', 'later', 'after', 'next', 'soon', 'eventually', 'someday',
            'early', 'late', 'on time', 'ancient', 'recent', 'modern', 'new',
            'always', 'never', 'sometimes', 'often', 'rarely', 'occasionally',
            'first', 'last', 'again', 'still', 'already', 'yet',
            'begin', 'start', 'end', 'finish', 'continue', 'resume', 'pause',
            'temporary', 'permanent', 'brief', 'long', 'short',
            -- Space — general
            'place', 'location', 'site', 'spot', 'position', 'point',
            'area', 'region', 'zone', 'territory', 'domain',
            'world', 'universe', 'cosmos', 'realm', 'dimension',
            'country', 'nation', 'province', 'district', 'city', 'town', 'village',
            -- Direction
            'north', 'south', 'east', 'west', 'northeast', 'northwest',
            'southeast', 'southwest', 'compass',
            'direction', 'way', 'route', 'path', 'course',
            'toward', 'away', 'forward', 'backward', 'sideways',
            -- Orientation
            'above', 'below', 'up', 'down', 'high', 'low',
            'top', 'bottom', 'ceiling', 'floor',
            'front', 'back', 'forward', 'rear', 'ahead', 'behind',
            'left', 'right', 'side', 'lateral',
            'center', 'middle', 'core', 'heart',
            'inside', 'outside', 'interior', 'exterior',
            'in', 'out', 'within', 'beyond', 'through',
            'between', 'among', 'amid',
            'near', 'close', 'adjacent', 'beside', 'next',
            'far', 'distant', 'remote',
            'around', 'surrounding', 'encircling',
            'across', 'along', 'over', 'under', 'beneath', 'past',
            -- Spatial attributes
            'distance', 'depth', 'height', 'width', 'length', 'size', 'area', 'volume',
            'space', 'room', 'gap', 'interval', 'opening',
            'boundary', 'border', 'edge', 'rim', 'margin', 'limit',
            'corner', 'angle', 'end', 'tip', 'peak', 'base',
            'row', 'column', 'line', 'layer', 'level', 'rank',
            'circle', 'curve', 'arc', 'spiral',
            'straight', 'diagonal', 'parallel', 'perpendicular'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 🔵 BLUE - Power / Law / Society / Military / Economy
    -- ═══════════════════════════════════════════════════════════════════════
    -- Organized human systems: authority, religion, conflict, trade.
    {
        color = '&HDD6600&',  -- Deep blue
        alpha = '&H30&',
        keywords = {
            -- Government & authority
            'govern', 'rule', 'reign', 'control', 'administer', 'manage', 'oversee',
            'emperor', 'empress', 'king', 'queen', 'prince', 'princess',
            'shogun', 'daimyo', 'samurai', 'lord', 'noble', 'court',
            'government', 'regime', 'system', 'order', 'policy', 'administration',
            'official', 'minister', 'bureaucrat', 'secretary', 'chancellor',
            'palace', 'castle', 'fortress', 'capital', 'throne',
            'country', 'nation', 'state', 'empire', 'kingdom', 'republic',
            'province', 'region', 'territory', 'colony', 'border', 'domain',
            'authority', 'power', 'sovereignty', 'supremacy', 'dominion',
            'command', 'order', 'decree', 'edict', 'proclamation', 'charter',
            'rank', 'title', 'position', 'status', 'class', 'caste', 'hierarchy',
            -- Law & justice
            'law', 'rule', 'regulation', 'ordinance', 'statute', 'code',
            'right', 'duty', 'obligation', 'responsibility', 'privilege',
            'crime', 'offense', 'sin', 'violation', 'infringement',
            'punishment', 'penalty', 'fine', 'execution', 'exile', 'imprisonment',
            'prison', 'jail', 'detention',
            'judge', 'magistrate', 'court', 'tribunal', 'hearing',
            'justice', 'verdict', 'sentence', 'acquit', 'convict',
            'guilty', 'innocent', 'evidence', 'proof', 'witness', 'testimony',
            'trial', 'appeal', 'case', 'lawsuit', 'dispute',
            'permit', 'license', 'ban', 'prohibition', 'restriction', 'censorship',
            -- Religion & ritual
            'god', 'goddess', 'deity', 'divine', 'sacred', 'holy', 'spiritual',
            'shrine', 'temple', 'church', 'altar', 'sanctuary', 'pilgrimage',
            'worship', 'pray', 'prayer', 'offering', 'sacrifice', 'tribute',
            'ritual', 'ceremony', 'rite', 'festival', 'celebration', 'holiday',
            'blessing', 'curse', 'spell', 'charm', 'talisman', 'amulet',
            'fortune', 'fate', 'destiny', 'prophecy', 'oracle', 'omen', 'sign',
            'karma', 'rebirth', 'enlightenment', 'nirvana', 'paradise', 'hell',
            'demon', 'ghost', 'spirit', 'ancestor', 'venerate',
            'myth', 'legend', 'doctrine', 'creed', 'faith', 'belief', 'sect',
            -- Military
            'war', 'battle', 'combat', 'conflict', 'clash', 'skirmish', 'siege',
            'campaign', 'invasion', 'conquest', 'raid', 'ambush', 'retreat',
            'army', 'navy', 'force', 'troop', 'corps', 'regiment', 'squad', 'unit',
            'soldier', 'warrior', 'fighter', 'general', 'commander', 'captain',
            'weapon', 'sword', 'blade', 'spear', 'lance', 'bow', 'arrow',
            'shield', 'armor', 'helmet', 'fortress', 'barricade', 'moat',
            'attack', 'charge', 'assault', 'strike', 'bombard',
            'defend', 'guard', 'protect', 'repel', 'fortify',
            'conquer', 'occupy', 'subjugate', 'overthrow', 'depose',
            'victory', 'triumph', 'defeat', 'surrender', 'truce', 'peace', 'treaty',
            'enemy', 'foe', 'adversary', 'rival', 'ally', 'coalition',
            'strategy', 'tactic', 'maneuver', 'ambush', 'feint',
            'flag', 'banner', 'standard', 'insignia', 'crest',
            -- Economy & trade
            'money', 'coin', 'currency', 'cash', 'wealth', 'fortune', 'treasure',
            'trade', 'commerce', 'business', 'industry', 'enterprise',
            'sell', 'buy', 'purchase', 'barter', 'auction',
            'price', 'value', 'cost', 'worth', 'rate', 'tariff',
            'tax', 'levy', 'toll', 'tribute', 'fee', 'commission',
            'debt', 'loan', 'borrow', 'lend', 'credit', 'interest',
            'profit', 'loss', 'gain', 'surplus', 'deficit', 'budget',
            'market', 'shop', 'store', 'warehouse', 'port', 'harbor',
            'goods', 'product', 'merchandise', 'commodity', 'supply', 'demand',
            'resource', 'material', 'stock', 'inventory', 'export', 'import',
            'pay', 'wage', 'salary', 'reward', 'bonus', 'pension',
            'property', 'estate', 'ownership', 'possession', 'inheritance'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 🟣 PURPLE - Abstract / Logic / Quantity / Existence / Change
    -- ═══════════════════════════════════════════════════════════════════════
    -- The conceptual layer: numbers, logic, being, and transformation.
    {
        color = '&HCC22CC&',  -- Rich purple
        alpha = '&H30&',
        keywords = {
            -- Numbers
            'zero', 'one', 'two', 'three', 'four', 'five',
            'six', 'seven', 'eight', 'nine', 'ten',
            'eleven', 'twelve', 'twenty', 'thirty', 'forty', 'fifty',
            'hundred', 'thousand', 'ten thousand', 'million', 'billion',
            'first', 'second', 'third', 'fourth', 'fifth',
            -- Quantity
            'count', 'number', 'numeral', 'amount', 'quantity', 'measure',
            'sum', 'total', 'subtotal', 'remainder', 'average', 'median',
            'half', 'quarter', 'third', 'double', 'triple',
            'zero', 'nothing', 'empty', 'null', 'void',
            'all', 'every', 'entire', 'whole', 'complete', 'full',
            'none', 'nobody', 'nothing', 'nowhere',
            'some', 'few', 'several', 'many', 'numerous', 'countless',
            'most', 'least', 'more', 'less', 'extra', 'excess', 'surplus',
            'enough', 'sufficient', 'insufficient', 'scarce', 'abundant',
            'single', 'plural', 'sole', 'unique', 'various', 'diverse',
            'both', 'each', 'either', 'neither',
            -- Logic & reason
            'true', 'false', 'correct', 'incorrect', 'wrong', 'right',
            'valid', 'invalid', 'logical', 'illogical', 'rational', 'irrational',
            'equal', 'same', 'identical', 'equivalent',
            'different', 'opposite', 'contrary', 'contradictory',
            'similar', 'analogous', 'parallel',
            'compare', 'contrast', 'distinguish', 'differentiate',
            'match', 'fit', 'suit', 'conform', 'correspond',
            'exceed', 'surpass', 'fall short', 'lack',
            'positive', 'negative', 'neutral',
            'cause', 'effect', 'result', 'consequence', 'outcome',
            'reason', 'purpose', 'motive', 'basis', 'foundation',
            'condition', 'requirement', 'prerequisite', 'exception',
            'proof', 'evidence', 'fact', 'truth', 'lie', 'rumor',
            'theory', 'hypothesis', 'assumption', 'premise', 'conclusion',
            'problem', 'solution', 'answer', 'mystery', 'puzzle',
            -- Existence & change
            'exist', 'be', 'existence', 'presence', 'absence',
            'real', 'actual', 'virtual', 'potential', 'possible', 'impossible',
            'necessary', 'optional', 'inevitable', 'accidental', 'certain', 'uncertain',
            'become', 'transform', 'convert', 'evolve', 'develop', 'progress',
            'change', 'alter', 'modify', 'adjust', 'shift', 'vary',
            'grow', 'expand', 'increase', 'enlarge', 'multiply',
            'shrink', 'decrease', 'diminish', 'reduce', 'minimize',
            'appear', 'emerge', 'arise', 'originate', 'come from',
            'disappear', 'vanish', 'fade', 'cease', 'end', 'die out',
            'begin', 'start', 'initiate', 'launch', 'trigger',
            'end', 'finish', 'complete', 'conclude', 'terminate',
            'continue', 'persist', 'endure', 'last', 'sustain',
            'repeat', 'recur', 'cycle', 'alternate', 'rotate',
            'happen', 'occur', 'take place', 'arise', 'emerge',
            'create', 'generate', 'produce', 'yield', 'bring about',
            'destroy', 'eliminate', 'erase', 'abolish', 'annihilate',
            -- Degree & quality
            'great', 'magnificent', 'grand', 'enormous', 'vast', 'immense',
            'small', 'tiny', 'minute', 'negligible', 'trivial',
            'strong', 'powerful', 'mighty', 'forceful', 'potent',
            'weak', 'feeble', 'fragile', 'delicate', 'frail',
            'heavy', 'massive', 'dense', 'solid',
            'light', 'weightless', 'thin', 'hollow',
            'fast', 'swift', 'rapid', 'quick', 'instant',
            'slow', 'gradual', 'sluggish', 'leisurely',
            'hard', 'solid', 'rigid', 'firm', 'tough',
            'soft', 'flexible', 'pliable', 'elastic', 'supple',
            'sharp', 'keen', 'precise', 'accurate',
            'dull', 'blunt', 'vague', 'ambiguous',
            'important', 'significant', 'critical', 'essential', 'vital',
            'trivial', 'minor', 'negligible', 'irrelevant',
            'useful', 'practical', 'effective', 'efficient',
            'useless', 'wasteful', 'ineffective', 'futile',
            'rare', 'uncommon', 'extraordinary', 'exceptional',
            'common', 'ordinary', 'typical', 'standard', 'normal',
            'complex', 'complicated', 'intricate', 'sophisticated',
            'simple', 'plain', 'basic', 'fundamental', 'elementary',
            'clear', 'obvious', 'evident', 'transparent',
            'unclear', 'obscure', 'hidden', 'mysterious',
            'pure', 'refined', 'pristine', 'flawless',
            'mixed', 'impure', 'contaminated', 'corrupted'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 🟤 BROWN - Work / Tools / Food / Clothing / Objects / Buildings
    -- ═══════════════════════════════════════════════════════════════════════
    -- The material world of human making and daily life.
    {
        color = '&H2255BB&',  -- Warm brown
        alpha = '&H30&',
        keywords = {
            -- Work & labor
            'work', 'labor', 'toil', 'effort', 'task', 'job', 'duty', 'chore',
            'make', 'create', 'build', 'construct', 'assemble', 'manufacture',
            'repair', 'fix', 'restore', 'maintain', 'service', 'clean', 'wash',
            'craft', 'forge', 'cast', 'mold', 'carve', 'shape', 'polish',
            'weave', 'spin', 'knit', 'sew', 'stitch', 'embroider',
            'cook', 'boil', 'fry', 'roast', 'bake', 'steam', 'grill', 'brew',
            'farm', 'plow', 'sow', 'harvest', 'reap', 'cultivate', 'irrigate',
            'mine', 'drill', 'excavate', 'smelt', 'refine',
            'fish', 'cast', 'net', 'trap', 'hunt', 'stalk', 'snare',
            'chop', 'lumber', 'gather', 'collect', 'harvest',
            'prepare', 'process', 'package', 'distribute', 'deliver',
            'measure', 'weigh', 'calculate', 'estimate', 'plan',
            -- Tools & implements
            'tool', 'implement', 'instrument', 'device', 'machine', 'mechanism',
            'knife', 'blade', 'dagger', 'cleaver', 'razor',
            'axe', 'hatchet', 'adze',
            'hammer', 'mallet', 'chisel', 'punch',
            'saw', 'file', 'drill', 'plane',
            'needle', 'pin', 'hook', 'buckle', 'clasp',
            'thread', 'cord', 'rope', 'wire', 'chain', 'string',
            'brush', 'comb', 'rake', 'broom', 'mop', 'sponge',
            'pot', 'pan', 'kettle', 'cauldron', 'ladle', 'spatula', 'chopstick',
            'bowl', 'cup', 'mug', 'glass', 'goblet', 'bottle', 'flask',
            'plate', 'dish', 'tray', 'platter',
            'jar', 'jug', 'urn', 'vase', 'canteen',
            'box', 'chest', 'trunk', 'crate', 'casket',
            'bag', 'pouch', 'sack', 'basket', 'net', 'tub',
            'wheel', 'pulley', 'lever', 'gear', 'spring',
            'cart', 'wagon', 'sled', 'palanquin', 'carriage',
            'boat', 'ship', 'vessel', 'canoe', 'raft',
            'bridge', 'ladder', 'scaffold', 'platform',
            'key', 'lock', 'latch', 'hinge', 'bolt', 'nail', 'screw',
            'lamp', 'lantern', 'candle', 'torch', 'fire pit',
            'mirror', 'lens', 'glass', 'prism',
            -- Structures & spaces
            'house', 'home', 'dwelling', 'residence', 'abode', 'shelter',
            'building', 'structure', 'construction', 'architecture',
            'room', 'chamber', 'hall', 'corridor', 'passage', 'staircase',
            'wall', 'partition', 'column', 'pillar', 'beam', 'rafter',
            'roof', 'ceiling', 'floor', 'foundation', 'basement',
            'window', 'door', 'gate', 'arch', 'entrance', 'exit',
            'fence', 'hedge', 'wall', 'moat', 'drawbridge',
            'tower', 'spire', 'turret', 'battlement',
            'path', 'road', 'street', 'alley', 'avenue', 'boulevard',
            'bridge', 'tunnel', 'canal', 'aqueduct',
            'well', 'cistern', 'fountain', 'reservoir',
            'garden', 'yard', 'courtyard', 'plaza', 'square',
            'farm', 'field', 'paddock', 'orchard', 'stable', 'barn',
            'market', 'shop', 'stall', 'warehouse', 'storehouse',
            'temple', 'shrine', 'church', 'monastery',
            'castle', 'palace', 'fort', 'dungeon', 'prison',
            'school', 'library', 'hall', 'auditorium',
            'port', 'harbor', 'dock', 'pier', 'lighthouse',
            -- Food & drink
            'food', 'meal', 'dish', 'cuisine', 'recipe', 'ingredient',
            'eat', 'consume', 'devour', 'swallow', 'chew', 'bite', 'taste', 'savor',
            'drink', 'sip', 'gulp', 'quench', 'slurp',
            'fast', 'starve', 'hunger', 'thirst',
            'rice', 'bread', 'flour', 'grain', 'noodle', 'pasta',
            'meat', 'beef', 'pork', 'chicken', 'lamb', 'venison',
            'fish', 'seafood', 'shellfish',
            'vegetable', 'bean', 'pea', 'mushroom', 'tofu',
            'fruit', 'berry', 'citrus', 'melon', 'apple', 'plum', 'peach',
            'soup', 'broth', 'stew', 'porridge', 'congee',
            'sauce', 'dip', 'seasoning', 'salt', 'sugar', 'vinegar', 'oil', 'spice',
            'sweet', 'sour', 'salty', 'bitter', 'spicy', 'savory', 'bland',
            'wine', 'sake', 'beer', 'spirit', 'liquor', 'mead',
            'tea', 'coffee', 'juice', 'milk',
            -- Clothing & appearance
            'cloth', 'fabric', 'textile', 'material', 'fiber',
            'silk', 'cotton', 'wool', 'linen', 'leather', 'fur',
            'clothing', 'garment', 'outfit', 'attire', 'costume', 'uniform',
            'wear', 'dress', 'clothe', 'undress', 'strip',
            'robe', 'kimono', 'gown', 'cloak', 'mantle', 'cape',
            'shirt', 'coat', 'jacket', 'vest', 'tunic',
            'pants', 'skirt', 'trousers', 'shorts',
            'hat', 'cap', 'hood', 'veil', 'mask', 'crown', 'tiara',
            'shoe', 'boot', 'sandal', 'slipper', 'clog',
            'glove', 'mitten', 'sock', 'stocking',
            'belt', 'sash', 'strap', 'band',
            'sleeve', 'collar', 'hem', 'seam', 'pocket', 'button', 'zipper',
            'dye', 'pattern', 'embroidery', 'lace', 'fringe',
            'ornament', 'decoration', 'adornment', 'accessory',
            'ring', 'bracelet', 'necklace', 'earring', 'brooch', 'pendant',
            'mirror', 'comb', 'powder', 'perfume', 'cosmetic', 'makeup',
            'appearance', 'look', 'style', 'fashion', 'trend', 'beauty'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 🩶 SILVER - State / Quality / Morality / Condition
    -- ═══════════════════════════════════════════════════════════════════════
    -- Descriptive attributes, moral qualities, and conditions of being.
    -- Catch-all for adjectives and stative concepts.
    {
        color = '&HCCCCCC&',  -- Silver
        alpha = '&H30&',
        keywords = {
            -- General state
            'new', 'old', 'ancient', 'modern', 'original', 'traditional', 'classic',
            'real', 'actual', 'fake', 'artificial', 'natural', 'synthetic',
            'alive', 'living', 'dead', 'dying', 'undead',
            'open', 'closed', 'sealed', 'locked', 'hidden',
            'free', 'bound', 'captive', 'trapped', 'restrained',
            'safe', 'secure', 'dangerous', 'risky', 'hazardous', 'lethal',
            'healthy', 'well', 'sick', 'ill', 'diseased', 'injured', 'wounded',
            'broken', 'damaged', 'ruined', 'destroyed',
            'whole', 'intact', 'complete', 'partial', 'incomplete',
            'ready', 'prepared', 'unready', 'unfinished',
            'active', 'passive', 'idle', 'busy',
            'awake', 'asleep', 'conscious', 'unconscious',
            -- Moral & ethical
            'good', 'bad', 'evil', 'wicked', 'malicious', 'corrupt',
            'virtue', 'vice', 'sin', 'righteousness', 'justice', 'mercy',
            'right', 'wrong', 'just', 'unjust', 'fair', 'unfair',
            'honest', 'dishonest', 'truthful', 'deceitful', 'hypocritical',
            'loyal', 'disloyal', 'faithful', 'treacherous', 'reliable', 'unreliable',
            'brave', 'coward', 'bold', 'timid', 'reckless', 'cautious',
            'kind', 'cruel', 'compassionate', 'heartless', 'gentle', 'harsh',
            'generous', 'selfish', 'greedy', 'charitable',
            'humble', 'arrogant', 'proud', 'vain', 'modest',
            'sincere', 'insincere', 'genuine', 'pretentious',
            'wise', 'foolish', 'clever', 'stupid', 'naive', 'cunning',
            'patient', 'impatient', 'diligent', 'lazy', 'persistent', 'stubborn',
            'disciplined', 'reckless', 'careful', 'careless', 'thorough', 'sloppy',
            'obedient', 'rebellious', 'submissive', 'defiant', 'compliant',
            -- Sensory & physical qualities
            'beautiful', 'ugly', 'handsome', 'plain', 'attractive', 'repulsive',
            'graceful', 'clumsy', 'elegant', 'crude', 'refined', 'coarse',
            'bright', 'colorful', 'vivid', 'vibrant', 'pale', 'dull', 'faded',
            'smooth', 'rough', 'jagged', 'bumpy', 'silky', 'coarse', 'grainy',
            'loud', 'noisy', 'quiet', 'silent', 'deafening', 'faint',
            'fragrant', 'sweet-smelling', 'stinky', 'odorless', 'rotten',
            'hot', 'warm', 'cold', 'cool', 'freezing', 'scalding', 'lukewarm',
            'wet', 'dry', 'damp', 'moist', 'soaked', 'parched',
            'sweet', 'bitter', 'sour', 'salty', 'spicy', 'savory', 'tasteless',
            -- Relational
            'main', 'primary', 'secondary', 'minor', 'key', 'central',
            'related', 'unrelated', 'relevant', 'irrelevant', 'connected', 'separate',
            'together', 'alone', 'mutual', 'one-sided', 'reciprocal',
            'direct', 'indirect', 'explicit', 'implicit', 'literal', 'figurative',
            'general', 'specific', 'broad', 'narrow', 'wide', 'limited',
            'whole', 'partial', 'complete', 'fragmentary', 'thorough', 'superficial',
            'formal', 'informal', 'official', 'unofficial', 'public', 'private',
            'inner', 'outer', 'external', 'internal', 'surface', 'deep',
            'original', 'copy', 'genuine', 'imitation', 'authentic', 'counterfeit'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 🌸 PINK - Life / Growth / Reproduction / Health / Cycle
    -- ═══════════════════════════════════════════════════════════════════════
    -- The biological dimension: life cycles, health, growth, and reproduction.
    {
        color = '&HBB55FF&',  -- Pink
        alpha = '&H30&',
        keywords = {
            -- Life & death
            'life', 'live', 'alive', 'death', 'die', 'dead', 'mortality', 'immortal',
            'birth', 'born', 'newborn', 'infant', 'emerge', 'hatch',
            'age', 'grow', 'mature', 'wither', 'decay', 'rot', 'decompose',
            'survive', 'perish', 'extinction', 'extinction', 'revive', 'resurrect',
            -- Growth & development
            'grow', 'growth', 'develop', 'develop', 'evolve', 'progress', 'advance',
            'bloom', 'blossom', 'flourish', 'thrive', 'prosper',
            'wither', 'decline', 'degenerate', 'deteriorate', 'waste',
            'germinate', 'sprout', 'bud', 'ripen', 'mature', 'harvest',
            'small', 'young', 'juvenile', 'immature', 'undeveloped',
            'adult', 'full-grown', 'mature', 'developed', 'prime',
            'old', 'aged', 'elderly', 'ancient', 'senile', 'withered',
            -- Reproduction & family
            'reproduce', 'breed', 'propagate', 'multiply', 'spawn',
            'mate', 'couple', 'fertilize', 'conceive', 'pregnant', 'gestate',
            'give birth', 'bear', 'deliver', 'nurse', 'suckle', 'raise', 'nurture',
            'egg', 'seed', 'embryo', 'fetus', 'larva', 'pupa',
            'offspring', 'young', 'litter', 'brood', 'nest',
            -- Health & medicine
            'health', 'healthy', 'well', 'fit', 'robust', 'vigorous', 'vital',
            'sick', 'ill', 'unwell', 'diseased', 'infected', 'afflicted',
            'disease', 'illness', 'ailment', 'condition', 'disorder', 'syndrome',
            'fever', 'chill', 'pain', 'ache', 'swelling', 'rash', 'wound',
            'medicine', 'drug', 'herb', 'remedy', 'cure', 'antidote', 'vaccine',
            'heal', 'treat', 'recover', 'convalesce', 'rehabilitate',
            'hurt', 'injure', 'wound', 'damage', 'scar', 'fracture', 'bruise',
            'bleed', 'hemorrhage', 'clot', 'infect', 'swell', 'fester',
            'breathe', 'inhale', 'exhale', 'choke', 'suffocate', 'gasp',
            'hunger', 'thirst', 'fatigue', 'exhaustion', 'weakness',
            'sleep', 'rest', 'wake', 'consciousness', 'faint', 'coma',
            'poison', 'toxic', 'antidote', 'purify', 'detox',
            -- Biological cycle
            'cycle', 'season', 'renewal', 'rebirth', 'regenerate', 'regrow',
            'molt', 'shed', 'transform', 'metamorphosis', 'hibernate',
            'migrate', 'return', 'bloom', 'wilt', 'freeze', 'thaw'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 🟠 AMBER - Knowledge / Science / Skill / Learning / Measurement
    -- ═══════════════════════════════════════════════════════════════════════
    -- Human knowledge, skill, science, technology, and measurement.
    {
        color = '&H0099FF&',  -- Amber/gold
        alpha = '&H30&',
        keywords = {
            -- Learning & education
            'learn', 'study', 'educate', 'train', 'practice', 'drill', 'rehearse',
            'teach', 'instruct', 'mentor', 'coach', 'tutor', 'lecture', 'demonstrate',
            'school', 'academy', 'university', 'institute', 'classroom',
            'lesson', 'course', 'curriculum', 'subject', 'discipline', 'field',
            'graduate', 'pass', 'fail', 'exam', 'test', 'quiz', 'homework', 'assignment',
            'degree', 'diploma', 'certificate', 'qualification', 'rank', 'title',
            -- Knowledge & information
            'know', 'knowledge', 'information', 'data', 'fact', 'truth',
            'understand', 'comprehend', 'master', 'expertise', 'skill', 'ability',
            'discover', 'explore', 'investigate', 'research', 'experiment',
            'observe', 'examine', 'analyze', 'inspect', 'survey', 'evaluate',
            'find', 'reveal', 'uncover', 'disclose', 'expose',
            'prove', 'demonstrate', 'verify', 'confirm', 'disprove',
            'record', 'document', 'catalog', 'classify', 'organize', 'archive',
            'wisdom', 'intelligence', 'genius', 'talent', 'gift', 'aptitude',
            'memory', 'experience', 'insight', 'perspective', 'view', 'opinion',
            -- Science & nature study
            'science', 'physics', 'chemistry', 'biology', 'mathematics', 'geometry',
            'astronomy', 'geography', 'medicine', 'philosophy', 'history', 'literature',
            'element', 'compound', 'reaction', 'force', 'energy', 'matter',
            'atom', 'molecule', 'cell', 'organism', 'species', 'genus',
            'theory', 'law', 'principle', 'formula', 'equation', 'proof',
            'method', 'technique', 'process', 'procedure', 'system', 'model',
            -- Skill & craft
            'skill', 'technique', 'craft', 'art', 'ability', 'talent', 'mastery',
            'expert', 'master', 'novice', 'beginner', 'apprentice', 'veteran',
            'practice', 'improve', 'refine', 'perfect', 'hone', 'sharpen',
            'creative', 'innovative', 'inventive', 'original', 'unique',
            'strategy', 'plan', 'design', 'blueprint', 'scheme', 'approach',
            -- Measurement & mathematics
            'measure', 'count', 'calculate', 'compute', 'estimate', 'approximate',
            'weigh', 'gauge', 'calibrate', 'scale', 'grade', 'rate', 'rank',
            'number', 'figure', 'digit', 'fraction', 'percent', 'ratio', 'proportion',
            'length', 'width', 'height', 'depth', 'area', 'volume', 'mass', 'weight',
            'temperature', 'speed', 'velocity', 'force', 'pressure', 'density',
            'add', 'subtract', 'multiply', 'divide', 'calculate', 'solve',
            'increase', 'decrease', 'double', 'halve', 'square', 'root',
            'graph', 'chart', 'table', 'diagram', 'map', 'grid', 'axis',
            -- Technology & invention
            'technology', 'invention', 'innovation', 'discovery', 'creation',
            'build', 'engineer', 'design', 'construct', 'develop', 'program',
            'machine', 'mechanism', 'device', 'system', 'network', 'circuit',
            'tool', 'instrument', 'apparatus', 'equipment', 'gear', 'component'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- ADD YOUR OWN CATEGORIES BELOW
    -- ═══════════════════════════════════════════════════════════════════════
    -- Template:
    -- {
    --     color = '&HBBGGRR&',  -- Color name (remember: BGR not RGB!)
    --     alpha = '&H30&',      -- &H00& = opaque, &HFF& = transparent
    --     keywords = {
    --         'keyword1', 'keyword2', 'keyword3'
    --     }
    -- },
}
