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

    -- ═══════════════════════════════════════════════════════════════════
    -- 🔴 RED - Action / Movement / Physical Verbs
    -- ═══════════════════════════════════════════════════════════════════
    -- Dynamic physical actions, motion, and transformation.
    {
        color = '&H1111EE&',  -- Vivid red
        alpha = '&H30&',
        keywords = {
            'go', 'come', 'move', 'walk', 'run', 'sprint', 'fly', 'soar', 'glide', 'jump',
            'leap', 'hop', 'skip', 'step', 'march', 'parade', 'trudge', 'stroll', 'enter',
            'exit', 'leave', 'depart', 'arrive', 'return', 'pass', 'cross', 'rise', 'fall',
            'ascend', 'descend', 'climb', 'plunge', 'sink', 'flow', 'pour', 'gush', 'drip',
            'leak', 'spill', 'rush', 'dash', 'race', 'flee', 'escape', 'chase', 'pursue',
            'follow', 'lead', 'guide', 'wander', 'roam', 'drift', 'stray', 'advance',
            'retreat', 'slide', 'slip', 'crawl', 'creep', 'sneak', 'prowl', 'lurk', 'travel',
            'journey', 'ride', 'drive', 'sail', 'row', 'paddle', 'swim', 'float', 'dive',
            'surface', 'orbit', 'loop', 'throw', 'toss', 'fling', 'hurl', 'launch', 'shoot',
            'pull', 'drag', 'haul', 'tug', 'yank', 'push', 'shove', 'nudge', 'press', 'carry',
            'bear', 'transport', 'convey', 'deliver', 'bring', 'take', 'fetch', 'retrieve',
            'collect', 'send', 'dispatch', 'transfer', 'receive', 'accept', 'obtain',
            'acquire', 'gain', 'get', 'grab', 'seize', 'reach', 'extend', 'stretch', 'dance',
            'roll', 'turn', 'spin', 'rotate', 'revolve', 'twist', 'coil', 'shake', 'tremble',
            'shiver', 'quiver', 'vibrate', 'swing', 'kneel', 'crouch', 'bend', 'lean', 'tilt',
            'stand', 'sit', 'squat', 'rest', 'sleep', 'wake', 'lift', 'raise', 'lower',
            'hang', 'suspend', 'balance', 'hit', 'strike', 'beat', 'punch', 'kick', 'stomp',
            'slam', 'smash', 'cut', 'slice', 'chop', 'slash', 'stab', 'pierce', 'tear', 'rip',
            'shred', 'break', 'shatter', 'crush', 'grind', 'pound', 'destroy', 'scratch',
            'scrape', 'rub', 'polish', 'carve', 'engrave', 'fold', 'wrap', 'bundle', 'pack',
            'open', 'close', 'shut', 'unlock', 'tie', 'bind', 'fasten', 'knot', 'release',
            'untie', 'loosen', 'free', 'catch', 'hold', 'grip', 'grasp', 'clutch', 'squeeze',
            'drop', 'let', 'put', 'set', 'lay', 'attach', 'install', 'mount', 'embed',
            'remove', 'detach', 'peel', 'strip', 'extract', 'pull out', 'insert', 'fill',
            'load', 'drain', 'mix', 'blend', 'stir', 'combine', 'merge', 'separate', 'split',
            'divide', 'sever', 'join', 'connect', 'link', 'unite', 'dig', 'bury', 'sow',
            'cover', 'uncover', 'hide', 'expose', 'gather', 'pile', 'stack', 'arrange',
            'organize', 'sort', 'scatter', 'spread', 'distribute', 'disperse', 'see', 'watch',
            'search', 'stop', 'wait', 'hurry', 'thrust', 'blow', 'suck', 'touch', 'stare',
            'collide', 'wipe', 'sweep', 'tread', 'trample', 'stumble', 'penetrate',
            'interrupt', 'stuff', 'plug', 'spray', 'rinse', 'sprinkle', 'splash', 'dredge',
            'filter', 'kindle', 'shave', 'knead', 'lick', 'sniff', 'peek', 'stare at',
            'dodge', 'clap', 'tap', 'tickle', 'rattle',
            'kill', 'slay', 'slaughter', 'murder', 'strangle', 'hug', 'embrace',
            'beckon', 'summon forth', 'brandish', 'wield', 'pluck', 'pinch', 'poke',
            'serve', 'use', 'utilize', 'apply', 'handle', 'operate', 'manipulate',
            'win', 'lose', 'compete for', 'strive', 'struggle', 'overcome',
            'encounter', 'confront', 'scull', 'row a boat', 'vomit', 'spit',
            'discharge', 'emit', 'radiate', 'bestow', 'grant', 'offer',
            'equip', 'wring', 'unravel', 'untangle', 'dismantle',
            'substitute', 'replace', 'swap', 'exchange', 'transmit', 'relay signal',
            'accomplish', 'achieve', 'attain', 'surround', 'encircle', 'enclose',
            'desecrate', 'defile', 'profane', 'excel', 'excel at',
            'mingle', 'interact', 'socialize', 'mend', 'patch',
            'preserve', 'conserve', 'safeguard', 'maintain state',
            'reverse', 'invert', 'flip', 'revert', 'undo',
            'show', 'display', 'exhibit', 'demonstrate publicly',
            'settle', 'resolve', 'conclude', 'wrap up',
            'overflow', 'flood over', 'brim', 'spill over',
            'crack', 'fracture open', 'splinter', 'snap',
            'seep', 'ooze', 'permeate', 'infiltrate', 'trickle',
            'bore', 'penetrate through', 'perforate',
            'stagnate', 'idle about', 'languish', 'linger'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 💜 MAGENTA - Emotion / Mind / Cognition / Will
    -- ═══════════════════════════════════════════════════════════════════
    -- Internal mental and emotional experience.
    {
        color = '&HEE11EE&',  -- Vivid magenta
        alpha = '&H30&',
        keywords = {
            'think', 'thought', 'idea', 'concept', 'notion', 'know', 'knowledge',
            'understand', 'comprehend', 'realize', 'memorize', 'remember', 'recall',
            'recollect', 'forget', 'overlook', 'ignore', 'consider', 'ponder', 'deliberate',
            'reflect', 'contemplate', 'meditate', 'imagine', 'visualize', 'fantasize',
            'dream', 'envision', 'perceive', 'notice', 'sense', 'detect', 'recognize',
            'assess', 'critique', 'decide', 'choose', 'select', 'determine',
            'doubt', 'suspect', 'wonder', 'speculate', 'guess', 'expect', 'anticipate',
            'predict', 'assume', 'suppose', 'believe', 'intend', 'purpose', 'aim', 'goal',
            'motive', 'infer', 'deduce', 'logic', 'happy', 'joy', 'delight',
            'bliss', 'elation', 'ecstasy', 'cheerful', 'glad', 'pleased', 'satisfied',
            'content', 'grateful', 'thankful', 'love', 'affection', 'adore', 'cherish',
            'fond', 'hope', 'wish', 'desire', 'aspire', 'yearn', 'like', 'prefer', 'enjoy',
            'relish', 'appreciate', 'excited', 'enthusiastic', 'eager', 'passionate',
            'inspired', 'motivated', 'confident', 'courageous', 'daring', 'calm', 'peaceful',
            'serene', 'tranquil', 'relaxed', 'comfort', 'curious', 'interested', 'fascinated',
            'amazed', 'awe', 'sad', 'sorrow', 'grief', 'despair', 'misery', 'melancholy',
            'lament', 'cry', 'weep', 'sob', 'mourn', 'angry', 'rage', 'fury', 'wrath',
            'irritate', 'annoy', 'frustrate', 'hate', 'despise', 'loathe', 'resent', 'envy',
            'jealous', 'fear', 'terror', 'dread', 'frighten', 'scare', 'panic', 'horror',
            'worry', 'anxious', 'nervous', 'uneasy', 'stress', 'tension', 'shame', 'guilt',
            'regret', 'remorse', 'embarrass', 'humiliate', 'lonely', 'isolated', 'abandoned',
            'lost', 'confused', 'bewildered', 'bored', 'indifferent', 'apathetic', 'numb',
            'suffer', 'pain', 'anguish', 'torment', 'distress', 'disgust', 'repulse',
            'reject', 'deny', 'refuse', 'disappointed', 'disillusioned', 'betrayed', 'hurt',
            'heart', 'mind', 'soul', 'spirit', 'self', 'ego', 'identity', 'consciousness',
            'awareness', 'subconsciousness', 'instinct', 'intuition', 'will', 'determination',
            'patience', 'endurance', 'nature', 'character', 'personality', 'attitude', 'mood',
            'disposition', 'feeling', 'emotion', 'sentiment', 'impression', 'feelings',
            'dislike', 'scary', 'suspicious', 'flustered', 'tense', 'pitiful', 'lovely',
            'amazing', 'surprised', 'ashamed', 'reluctant', 'hateful', 'grudge', 'delighted',
            'pleasant', 'fun', 'refreshing', 'disgusted', 'depressed', 'dazzling', 'charming',
            'embarrassment', 'compassion', 'jealousy', 'mockery', 'despicable', 'enjoyment',
            'composure', 'hesitate', 'dither',
            'surprise', 'startled', 'shocked', 'upset', 'moved', 'touched',
            'depend', 'rely', 'trust',
            'nostalgia', 'long for', 'miss', 'crave',
            'favor', 'revere', 'worship deeply',
            'reflect on', 'muse',
            'confusion', 'chaos', 'turmoil', 'agitation', 'frenzy',
            'rapture', 'euphoria'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 💚 GREEN - Nature / Elements / Animals / Plants
    -- ═══════════════════════════════════════════════════════════════════
    -- The natural world in all its forms.
    {
        color = '&H11EE11&',  -- Vivid green
        alpha = '&H30&',
        keywords = {
            'tree', 'wood', 'forest', 'grove', 'jungle', 'woodland', 'thicket', 'plant',
            'flower', 'blossom', 'bloom', 'petal', 'bud', 'sprout', 'grass', 'lawn', 'meadow',
            'herb', 'weed', 'fern', 'moss', 'algae', 'leaf', 'leaves', 'foliage', 'canopy',
            'root', 'trunk', 'bark', 'branch', 'twig', 'stem', 'stalk', 'vine', 'seed',
            'spore', 'pod', 'nut', 'cone', 'fruit', 'berry', 'grain', 'rice', 'wheat',
            'bamboo', 'pine', 'cedar', 'oak', 'cherry', 'maple', 'willow', 'plum', 'rose',
            'lotus', 'chrysanthemum', 'crop', 'field', 'cultivate', 'wither', 'grow', 'water',
            'river', 'stream', 'creek', 'brook', 'canal', 'channel', 'sea', 'ocean', 'bay',
            'gulf', 'strait', 'coast', 'shore', 'beach', 'lake', 'pond', 'swamp', 'marsh',
            'wetland', 'waterfall', 'fountain', 'geyser', 'rain', 'drizzle', 'shower',
            'downpour', 'flood', 'drought', 'snow', 'blizzard', 'sleet', 'hail', 'frost',
            'ice', 'glacier', 'fog', 'mist', 'dew', 'humidity', 'moisture', 'wave', 'tide',
            'current', 'whirlpool', 'ripple', 'fire', 'flame', 'blaze', 'inferno', 'wildfire',
            'spark', 'ember', 'burn', 'scorch', 'char', 'smolder', 'ignite', 'extinguish',
            'smoke', 'ash', 'soot', 'heat', 'warmth', 'glow', 'torch', 'candle', 'earth',
            'soil', 'dirt', 'clay', 'mud', 'gravel', 'sand', 'dust', 'ground', 'land',
            'terrain', 'landscape', 'wilderness', 'mountain', 'peak', 'summit', 'ridge',
            'cliff', 'slope', 'hill', 'valley', 'canyon', 'gorge', 'ravine', 'chasm', 'plain',
            'plateau', 'steppe', 'tundra', 'desert', 'oasis', 'island', 'peninsula', 'cape',
            'continent', 'cave', 'cavern', 'tunnel', 'crater', 'stone', 'rock', 'boulder',
            'pebble', 'metal', 'ore', 'mineral', 'crystal', 'gold', 'silver', 'iron', 'steel',
            'copper', 'bronze', 'tin', 'coal', 'jade', 'jewel', 'gem', 'diamond', 'ruby',
            'sapphire', 'sky', 'heaven', 'atmosphere', 'horizon', 'sun', 'sunrise', 'sunset',
            'solar', 'ray', 'moon', 'lunar', 'crescent', 'full moon', 'star', 'constellation',
            'galaxy', 'comet', 'meteor', 'cloud', 'overcast', 'rainbow', 'wind', 'breeze',
            'gust', 'gale', 'typhoon', 'cyclone', 'tornado', 'storm', 'thunder', 'lightning',
            'light', 'bright', 'shine', 'gleam', 'sparkle', 'twinkle', 'dark', 'darkness',
            'shadow', 'shade', 'dim', 'air', 'breath', 'oxygen', 'animal', 'creature',
            'beast', 'monster', 'wild', 'bird', 'sparrow', 'swallow', 'crane', 'hawk',
            'eagle', 'raven', 'crow', 'owl', 'pheasant', 'duck', 'goose', 'swan', 'parrot',
            'peacock', 'fish', 'salmon', 'carp', 'shark', 'whale', 'dolphin', 'octopus',
            'crab', 'lobster', 'shrimp', 'clam', 'oyster', 'squid', 'insect', 'butterfly',
            'bee', 'ant', 'beetle', 'dragonfly', 'cicada', 'grasshopper', 'mosquito', 'worm',
            'spider', 'horse', 'cow', 'ox', 'bull', 'pig', 'sheep', 'goat', 'dog', 'cat',
            'rabbit', 'mouse', 'rat', 'squirrel', 'deer', 'elk', 'boar', 'wolf', 'fox',
            'tanuki', 'raccoon', 'tiger', 'lion', 'leopard', 'panther', 'monkey', 'ape',
            'elephant', 'rhinoceros', 'hippopotamus', 'snake', 'viper', 'cobra', 'python',
            'lizard', 'gecko', 'crocodile', 'turtle', 'tortoise', 'frog', 'toad',
            'salamander', 'dragon', 'phoenix', 'kirin', 'tengu', 'feather', 'claw', 'fang',
            'horn', 'hoof', 'paw', 'wing', 'tail', 'fur', 'shell', 'mane', 'whisker', 'tusk',
            'fin', 'gill', 'seaweed', 'mulberry', 'bush', 'turnip', 'eggplant', 'strawberry',
            'chestnut', 'pear', 'persimmon', 'ginger', 'garlic', 'onion', 'orchid',
            'camellia', 'jasmine', 'holly', 'butterbur', 'peony', 'bracken', 'reed', 'millet',
            'buckwheat', 'hemp', 'hay', 'firewood', 'amber', 'coral', 'reef', 'lagoon',
            'rapids', 'haze', 'sunshine', 'frozen', 'meteorite',
            'white', 'black', 'red', 'blue', 'green', 'yellow', 'purple', 'brown',
            'grey', 'gray', 'scarlet', 'crimson', 'indigo', 'violet', 'pink color',
            'firefly', 'seagull', 'housefly', 'wagtail', 'bat', 'tapir',
            'elm', 'thistle', 'wisteria', 'lily', 'hibiscus', 'ivy',
            'cypress', 'birch', 'poplar', 'magnolia', 'apricot', 'catalpa',
            'citrus tree', 'zelkova', 'camphor', 'lacquer tree', 'paulownia',
            'swamp gas', 'flames', 'volcanic', 'eruption', 'lava', 'magma',
            'kingfisher', 'hen', 'rooster', 'marten', 'otter', 'badger',
            'billows', 'breakers', 'surf', 'undertow',
            'moor', 'heath', 'bog', 'fen', 'peat',
            'scales', 'plumage', 'antler', 'pelt',
            'fodder', 'hay feed', 'pasture', 'grazing'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 🧡 ORANGE - People / Body / Social / Family
    -- ═══════════════════════════════════════════════════════════════════
    -- People, roles, relationships, human anatomy, and social interaction.
    {
        color = '&H1188FF&',  -- Orange
        alpha = '&H30&',
        keywords = {
            'person', 'people', 'human', 'mankind', 'being', 'individual', 'man', 'woman',
            'male', 'female', 'boy', 'girl', 'child', 'baby', 'infant', 'toddler', 'youth',
            'teen', 'adult', 'elder', 'aristocrat', 'servant', 'slave', 'retainer',
            'follower', 'disciple', 'knight', 'spy', 'ninja', 'ronin', 'priest', 'monk',
            'nun', 'shaman', 'diviner', 'exorcist', 'doctor', 'healer', 'midwife',
            'pharmacist', 'teacher', 'professor', 'instructor', 'student', 'pupil',
            'apprentice', 'scholar', 'intellectual', 'philosopher', 'sage', 'artist',
            'painter', 'sculptor', 'poet', 'writer', 'musician', 'singer', 'dancer', 'actor',
            'performer', 'merchant', 'trader', 'vendor', 'shopkeeper', 'farmer', 'fisherman',
            'hunter', 'miner', 'woodcutter', 'carpenter', 'blacksmith', 'potter', 'weaver',
            'tailor', 'chef', 'baker', 'brewer', 'builder', 'architect', 'clerk', 'detective',
            'police', 'thief', 'bandit', 'criminal', 'outlaw', 'hero', 'villain', 'champion',
            'stranger', 'foreigner', 'visitor', 'guest', 'host', 'neighbor', 'citizen',
            'resident', 'refugee', 'family', 'clan', 'tribe', 'kin', 'relative', 'lineage',
            'generation', 'parent', 'father', 'mother', 'stepfather', 'stepmother', 'brother',
            'sister', 'sibling', 'twin', 'son', 'daughter', 'husband', 'wife', 'spouse',
            'couple', 'partner', 'grandfather', 'grandmother', 'grandparent', 'grandchild',
            'uncle', 'aunt', 'nephew', 'niece', 'cousin', 'ancestor', 'descendant', 'heir',
            'successor', 'friend', 'companion', 'rival', 'head', 'skull', 'brain', 'face',
            'forehead', 'eye', 'eyebrow', 'eyelid', 'iris', 'ear', 'eardrum', 'nose',
            'nostril', 'mouth', 'lip', 'tongue', 'tooth', 'teeth', 'gum', 'jaw', 'chin',
            'cheek', 'throat', 'neck', 'hair', 'beard', 'mustache', 'body', 'torso', 'chest',
            'breast', 'belly', 'abdomen', 'stomach', 'spine', 'shoulder', 'hip', 'waist',
            'rib', 'arm', 'elbow', 'wrist', 'hand', 'fist', 'palm', 'finger', 'thumb', 'nail',
            'leg', 'thigh', 'knee', 'ankle', 'foot', 'heel', 'toe', 'bone', 'marrow',
            'muscle', 'tendon', 'nerve', 'vein', 'artery', 'blood', 'flesh', 'fat', 'skin',
            'pore', 'sweat', 'lung', 'liver', 'kidney', 'intestine', 'organ', 'pulse', 'meet',
            'group', 'team', 'crowd', 'mob', 'pair', 'society', 'community', 'marry', 'wed',
            'divorce', 'engagement', 'burial', 'greet', 'welcome', 'farewell', 'bow', 'fight',
            'quarrel', 'reconcile', 'forgive', 'agree', 'disagree', 'negotiate', 'compromise',
            'help', 'assist', 'support', 'cooperate', 'collaborate', 'compete', 'challenge',
            'oppose', 'betray', 'kid', 'guy', 'lad', 'gentleman', 'comrade', 'colleague',
            'housewife', 'bride', 'bridegroom', 'bachelor', 'orphan', 'widow', 'boss',
            'professional', 'assistant', 'overseer', 'perpetrator', 'horseman', 'baron',
            'marquis', 'highness', 'preteen', 'lips', 'butt', 'hips', 'thighs', 'shin',
            'armpit', 'eyelashes', 'gall bladder', 'intestines', 'entrails', 'pancreas',
            'bladder', 'femur', 'windpipe', 'womb', 'saliva', 'urine', 'corpse',
            'someone', 'somebody', 'anyone', 'everyone', 'member', 'participant',
            'audience', 'spectator', 'bystander', 'messenger', 'envoy', 'ambassador',
            'pirate', 'smuggler', 'assassin', 'peasant', 'nobleman', 'commoner',
            'vassal', 'concubine', 'mistress', 'dynasty', 'chinese', 'japanese',
            'role', 'position held', 'rank held', 'company', 'corporation',
            'relationship', 'bond', 'connection with', 'affiliation',
            'eyeball', 'pupil eye', 'retina', 'cornea',
            'statue', 'figurine', 'idol', 'effigy', 'bust sculpture',
            'seat', 'bench', 'stool', 'throne seat', 'cushion'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 💛 YELLOW - Communication / Language / Arts / Expression
    -- ═══════════════════════════════════════════════════════════════════
    -- All forms of human expression — spoken, written, performed, visual.
    {
        color = '&H11EEEE&',  -- Vivid yellow
        alpha = '&H30&',
        keywords = {
            'say', 'speak', 'talk', 'utter', 'pronounce', 'articulate', 'express', 'tell',
            'narrate', 'recount', 'relay', 'report', 'inform', 'ask', 'inquire', 'question',
            'interrogate', 'interview', 'answer', 'reply', 'respond', 'retort', 'counter',
            'call', 'summon', 'shout', 'yell', 'scream', 'roar', 'whisper', 'murmur',
            'mutter', 'mumble', 'grumble', 'sing', 'chant', 'hum', 'melody', 'song', 'lyric',
            'verse', 'laugh', 'giggle', 'chuckle', 'snicker', 'mock', 'tease', 'sigh',
            'groan', 'moan', 'announce', 'declare', 'proclaim', 'broadcast', 'publish',
            'promise', 'vow', 'swear', 'oath', 'pledge', 'warn', 'caution', 'threaten',
            'intimidate', 'advise', 'suggest', 'recommend', 'explain', 'describe',
            'illustrate', 'discuss', 'debate', 'argue', 'dispute', 'persuade', 'convince',
            'seduce', 'tempt', 'praise', 'compliment', 'flatter', 'glorify', 'honor',
            'insult', 'scold', 'criticize', 'blame', 'accuse', 'slander', 'apologize',
            'confess', 'admit', 'lie', 'deceive', 'trick', 'beg', 'plead', 'request',
            'demand', 'introduce', 'address', 'consent', 'object', 'word', 'term', 'phrase',
            'sentence', 'paragraph', 'language', 'dialect', 'accent', 'grammar', 'syntax',
            'meaning', 'definition', 'nuance', 'context', 'voice', 'sound', 'tone', 'pitch',
            'rhythm', 'hear', 'listen', 'overhear', 'eavesdrop', 'write', 'compose', 'draft',
            'author', 'pen', 'read', 'skim', 'scan', 'decode', 'decipher', 'name', 'label',
            'designate', 'translate', 'interpret', 'transcribe', 'paraphrase', 'copy',
            'plagiarize', 'letter', 'script', 'glyph', 'rune', 'hieroglyph', 'text',
            'manuscript', 'scroll', 'document', 'contract', 'book', 'novel', 'tale', 'story',
            'legend', 'fable', 'poem', 'haiku', 'sonnet', 'epic', 'ballad', 'note', 'diary',
            'journal', 'message', 'memo', 'record', 'list', 'register', 'index', 'chapter',
            'page', 'print', 'stamp', 'seal', 'sign', 'mark', 'symbol', 'logo', 'emblem',
            'art', 'artwork', 'masterpiece', 'creation', 'draw', 'sketch', 'outline', 'trace',
            'paint', 'color', 'stroke', 'sculpt', 'picture', 'image', 'portrait', 'mural',
            'fresco', 'photograph', 'capture', 'depict', 'represent', 'design', 'pattern',
            'motif', 'style', 'genre', 'form', 'composition', 'music', 'tune', 'tempo',
            'harmony', 'chord', 'instrument', 'drum', 'flute', 'lute', 'koto', 'shamisen',
            'perform', 'play', 'act', 'stage', 'theater', 'drama', 'comedy', 'tragedy',
            'choreograph', 'recital', 'concert', 'conversation', 'argument', 'explanation',
            'proposal', 'statement', 'query', 'criticism', 'verification', 'deliberation',
            'expression', 'proverb', 'chronicle', 'rhyme', 'quote', 'chat', 'preface',
            'edition', 'canon', 'footnote', 'epilogue', 'glossary', 'riddle', 'parable',
            'metaphor', 'translation', 'saying', 'mandate', 'commandment',
            'inscription', 'engrave text', 'calligraphy', 'cipher', 'code word',
            'dictation', 'recitation', 'monologue', 'dialogue', 'soliloquy',
            'applause', 'ovation', 'encore', 'curtain call'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 🩵 CYAN - Time / Space / Direction / Position
    -- ═══════════════════════════════════════════════════════════════════
    -- Temporal and spatial orientation — when and where.
    {
        color = '&HEEEE11&',  -- Vivid cyan
        alpha = '&H30&',
        keywords = {
            'time', 'moment', 'instant', 'second', 'minute', 'hour', 'day', 'week', 'month',
            'year', 'decade', 'century', 'millennium', 'era', 'epoch', 'age', 'period',
            'phase', 'cycle', 'duration', 'interval', 'pause', 'delay', 'deadline', 'dawn',
            'morning', 'noon', 'afternoon', 'evening', 'dusk', 'night', 'midnight',
            'twilight', 'spring', 'summer', 'autumn', 'winter', 'season', 'solstice',
            'equinox', 'monsoon', 'past', 'history', 'before', 'previous', 'prior', 'former',
            'once', 'ago', 'present', 'now', 'today', 'at once', 'immediately', 'future',
            'later', 'after', 'next', 'soon', 'eventually', 'someday', 'early', 'late',
            'on time', 'ancient', 'recent', 'modern', 'always', 'never', 'sometimes', 'often',
            'rarely', 'occasionally', 'first', 'last', 'again', 'still', 'already', 'yet',
            'begin', 'start', 'end', 'finish', 'continue', 'resume', 'temporary', 'permanent',
            'brief', 'long', 'short', 'place', 'location', 'site', 'spot', 'position',
            'point', 'area', 'zone', 'world', 'universe', 'cosmos', 'realm', 'dimension',
            'district', 'city', 'town', 'village', 'north', 'south', 'east', 'west',
            'northeast', 'northwest', 'southeast', 'southwest', 'compass', 'direction', 'way',
            'route', 'path', 'toward', 'away', 'forward', 'backward', 'sideways', 'above',
            'below', 'up', 'down', 'high', 'low', 'top', 'bottom', 'front', 'back', 'rear',
            'ahead', 'behind', 'left', 'right', 'side', 'lateral', 'center', 'middle', 'core',
            'inside', 'outside', 'interior', 'exterior', 'in', 'out', 'within', 'beyond',
            'through', 'between', 'among', 'amid', 'near', 'adjacent', 'beside', 'far',
            'distant', 'remote', 'around', 'surrounding', 'encircling', 'across', 'along',
            'over', 'under', 'beneath', 'distance', 'depth', 'height', 'width', 'length',
            'size', 'volume', 'space', 'gap', 'opening', 'boundary', 'border', 'edge', 'rim',
            'margin', 'limit', 'corner', 'angle', 'tip', 'base', 'column', 'line', 'layer',
            'level', 'circle', 'curve', 'arc', 'spiral', 'straight', 'diagonal', 'parallel',
            'perpendicular', 'midday', 'eternity', 'daybreak', 'morrow', 'calendar',
            'weekday', 'sequential', 'successive', 'steadily', 'gradually', 'simultaneously',
            'frequently', 'repeatedly', 'temporarily', 'instantaneously', 'suddenly',
            'finally', 'until', 'while', 'however', 'vicinity', 'circumference', 'outskirts',
            'countryside', 'metropolis', 'midair', 'apex', 'pedestal', 'backside', 'hole',
            'pipe', 'sphere', 'cylinder',
            'degree', 'degrees', 'mile', 'meter', 'kilometer', 'litre', 'litres',
            'section', 'part', 'portion', 'piece', 'bit', 'fragment', 'segment',
            'framework', 'structure of', 'layout', 'outline of'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 🔵 BLUE - Power / Law / Society / Military / Economy
    -- ═══════════════════════════════════════════════════════════════════
    -- Organized human systems: authority, religion, conflict, trade.
    {
        color = '&HDD6600&',  -- Deep blue
        alpha = '&H30&',
        keywords = {
            'govern', 'rule', 'reign', 'control', 'administer', 'manage', 'oversee',
            'emperor', 'empress', 'king', 'queen', 'prince', 'princess', 'shogun', 'daimyo',
            'samurai', 'lord', 'noble', 'court', 'government', 'regime', 'system', 'order',
            'policy', 'administration', 'official', 'minister', 'bureaucrat', 'secretary',
            'chancellor', 'palace', 'castle', 'fortress', 'capital', 'throne', 'country',
            'nation', 'state', 'empire', 'kingdom', 'republic', 'province', 'region',
            'territory', 'colony', 'domain', 'authority', 'power', 'sovereignty', 'supremacy',
            'dominion', 'command', 'decree', 'edict', 'proclamation', 'charter', 'rank',
            'title', 'status', 'class', 'caste', 'hierarchy', 'law', 'regulation',
            'ordinance', 'statute', 'code', 'duty', 'obligation', 'responsibility',
            'privilege', 'crime', 'offense', 'violation', 'infringement', 'punishment',
            'penalty', 'fine', 'execution', 'exile', 'imprisonment', 'prison', 'jail',
            'detention', 'judge', 'magistrate', 'tribunal', 'hearing', 'justice', 'verdict',
            'acquit', 'convict', 'guilty', 'innocent', 'evidence', 'witness', 'testimony',
            'trial', 'appeal', 'case', 'lawsuit', 'permit', 'license', 'ban', 'prohibition',
            'restriction', 'censorship', 'god', 'goddess', 'deity', 'divine', 'sacred',
            'holy', 'spiritual', 'shrine', 'temple', 'church', 'altar', 'sanctuary',
            'pilgrimage', 'worship', 'pray', 'prayer', 'offering', 'sacrifice', 'tribute',
            'ritual', 'ceremony', 'rite', 'festival', 'celebration', 'holiday', 'blessing',
            'curse', 'spell', 'charm', 'talisman', 'amulet', 'fortune', 'fate', 'destiny',
            'prophecy', 'oracle', 'omen', 'karma', 'enlightenment', 'nirvana', 'paradise',
            'hell', 'demon', 'ghost', 'venerate', 'myth', 'doctrine', 'creed', 'faith',
            'belief', 'sect', 'war', 'battle', 'combat', 'conflict', 'clash', 'skirmish',
            'siege', 'campaign', 'invasion', 'conquest', 'raid', 'ambush', 'army', 'navy',
            'troop', 'corps', 'regiment', 'squad', 'unit', 'soldier', 'warrior', 'fighter',
            'commander', 'captain', 'weapon', 'sword', 'spear', 'lance', 'arrow', 'shield',
            'armor', 'helmet', 'barricade', 'attack', 'charge', 'assault', 'bombard',
            'defend', 'guard', 'protect', 'repel', 'fortify', 'conquer', 'occupy',
            'subjugate', 'overthrow', 'depose', 'victory', 'triumph', 'defeat', 'surrender',
            'truce', 'peace', 'treaty', 'enemy', 'foe', 'adversary', 'ally', 'coalition',
            'strategy', 'tactic', 'maneuver', 'feint', 'flag', 'banner', 'insignia', 'crest',
            'money', 'coin', 'currency', 'cash', 'wealth', 'treasure', 'trade', 'commerce',
            'business', 'industry', 'enterprise', 'sell', 'buy', 'purchase', 'barter',
            'auction', 'price', 'value', 'cost', 'worth', 'rate', 'tariff', 'tax', 'levy',
            'toll', 'fee', 'commission', 'debt', 'loan', 'borrow', 'lend', 'credit',
            'interest', 'profit', 'loss', 'deficit', 'budget', 'market', 'store', 'goods',
            'product', 'merchandise', 'commodity', 'supply', 'resource', 'stock', 'inventory',
            'export', 'import', 'pay', 'wage', 'salary', 'reward', 'bonus', 'pension',
            'property', 'estate', 'ownership', 'possession', 'inheritance', 'politics',
            'political party', 'prefecture', 'bureau', 'institution', 'committee',
            'constitution', 'orders', 'clause', 'subsection', 'department', 'vote', 'reform',
            'imperial', 'ticket', 'warrant', 'arrest', 'suppress', 'invade', 'resist', 'gun',
            'bullet', 'cannon', 'warship', 'halberd', 'javelin', 'battalion', 'barracks',
            'outpost', 'fortification', 'palisade',
            'military', 'militia', 'conscript', 'recruit', 'enlist',
            'wholesale', 'retail', 'monopoly', 'cartel', 'revenue', 'dividend',
            'subsidy', 'ransom', 'plunder', 'loot', 'spoils', 'confiscate',
            'manacles', 'shackles', 'fetter', 'handcuffs', 'stocks', 'gallows',
            'rebellion', 'revolt', 'uprising', 'insurrection', 'coup', 'mutiny',
            'usurp', 'seize power', 'overthrow by force', 'dethrone',
            'religion', 'theology', 'denomination', 'congregation', 'parish',
            'harmonize', 'reconcile forces', 'mediate', 'arbitrate',
            'regard', 'consideration', 'deference', 'esteem for',
            'disappointment', 'disillusion', 'letdown', 'dismay'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 🟣 PURPLE - Abstract / Logic / Quantity / Existence / Change
    -- ═══════════════════════════════════════════════════════════════════
    -- The conceptual layer: numbers, logic, being, and transformation.
    {
        color = '&HCC22CC&',  -- Rich purple
        alpha = '&H30&',
        keywords = {
            'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
            'ten', 'eleven', 'twelve', 'twenty', 'thirty', 'forty', 'fifty', 'hundred',
            'thousand', 'ten thousand', 'million', 'billion', 'third', 'fourth', 'fifth',
            'count', 'number', 'numeral', 'amount', 'quantity', 'sum', 'total', 'subtotal',
            'remainder', 'average', 'median', 'half', 'quarter', 'double', 'triple',
            'nothing', 'empty', 'null', 'void', 'all', 'every', 'entire', 'whole', 'complete',
            'full', 'none', 'nobody', 'nowhere', 'some', 'few', 'several', 'many', 'numerous',
            'countless', 'most', 'least', 'more', 'less', 'extra', 'excess', 'surplus',
            'enough', 'sufficient', 'insufficient', 'scarce', 'abundant', 'single', 'plural',
            'sole', 'unique', 'various', 'diverse', 'both', 'each', 'either', 'neither',
            'true', 'false', 'correct', 'incorrect', 'valid', 'invalid', 'logical',
            'illogical', 'rational', 'irrational', 'equal', 'same', 'identical', 'equivalent',
            'different', 'opposite', 'contrary', 'contradictory', 'similar', 'analogous',
            'compare', 'contrast', 'distinguish', 'differentiate', 'match', 'fit', 'suit',
            'conform', 'correspond', 'exceed', 'surpass', 'fall short', 'lack', 'positive',
            'negative', 'neutral', 'cause', 'effect', 'result', 'consequence', 'outcome',
            'reason', 'basis', 'requirement', 'prerequisite', 'exception', 'proof', 'fact',
            'truth', 'rumor', 'theory', 'hypothesis', 'assumption', 'premise', 'conclusion',
            'problem', 'solution', 'mystery', 'puzzle', 'exist', 'be', 'existence',
            'presence', 'absence', 'virtual', 'potential', 'possible', 'impossible',
            'necessary', 'optional', 'inevitable', 'accidental', 'certain', 'uncertain',
            'become', 'transform', 'convert', 'evolve', 'develop', 'progress', 'change',
            'alter', 'modify', 'adjust', 'shift', 'vary', 'expand', 'increase', 'enlarge',
            'multiply', 'shrink', 'decrease', 'diminish', 'reduce', 'minimize', 'appear',
            'emerge', 'arise', 'originate', 'come from', 'disappear', 'vanish', 'fade',
            'cease', 'die out', 'initiate', 'trigger', 'terminate', 'persist', 'endure',
            'sustain', 'repeat', 'recur', 'alternate', 'happen', 'occur', 'take place',
            'generate', 'produce', 'yield', 'bring about', 'eliminate', 'erase', 'abolish',
            'annihilate', 'great', 'magnificent', 'grand', 'enormous', 'vast', 'immense',
            'small', 'tiny', 'negligible', 'trivial', 'strong', 'powerful', 'mighty',
            'forceful', 'potent', 'weak', 'feeble', 'fragile', 'delicate', 'frail', 'heavy',
            'massive', 'dense', 'solid', 'weightless', 'thin', 'hollow', 'fast', 'swift',
            'rapid', 'quick', 'slow', 'gradual', 'sluggish', 'leisurely', 'hard', 'rigid',
            'firm', 'tough', 'soft', 'flexible', 'pliable', 'elastic', 'supple', 'sharp',
            'keen', 'precise', 'accurate', 'blunt', 'vague', 'ambiguous', 'important',
            'significant', 'critical', 'essential', 'vital', 'minor', 'useful', 'practical',
            'effective', 'efficient', 'useless', 'wasteful', 'ineffective', 'futile', 'rare',
            'uncommon', 'extraordinary', 'exceptional', 'common', 'ordinary', 'typical',
            'standard', 'normal', 'complex', 'complicated', 'intricate', 'sophisticated',
            'simple', 'basic', 'fundamental', 'elementary', 'clear', 'obvious', 'evident',
            'transparent', 'unclear', 'obscure', 'hidden', 'mysterious', 'pure', 'pristine',
            'flawless', 'mixed', 'impure', 'contaminated', 'corrupted', 'special', 'usual',
            'multiple', 'extreme', 'utmost', 'easy', 'difficult', 'other', 'overall', 'odd',
            'inferior', 'superior', 'excessive', 'superfluous', 'supplementary', 'constant',
            'comparable', 'fitting', 'suitable', 'criteria', 'sequence', 'category', 'item',
            'error', 'success', 'example', 'addition', 'reduction', 'difference', 'extent',
            'limits',
            'large', 'huge', 'big', 'wide ranging', 'broad scope',
            'transformation', 'transition', 'metamorphose', 'fluctuate',
            'target', 'objective', 'intent',
            'origin', 'source', 'root cause', 'derivation', 'genesis',
            'topic', 'subject matter', 'theme', 'motif of', 'aspect',
            'activity', 'action', 'vigor', 'vitality', 'dynamism',
            'plentiful', 'ample', 'copious', 'bountiful', 'lavish',
            'favored', 'biased', 'partial to', 'inclined', 'predisposed',
            'almost', 'nearly', 'approximately', 'roughly', 'about',
            'only', 'merely', 'solely', 'exclusively',
            'best', 'worst', 'finest', 'prime quality', 'optimal'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 🟤 BROWN - Work / Tools / Food / Clothing / Objects / Buildings
    -- ═══════════════════════════════════════════════════════════════════
    -- The material world of human making and daily life.
    {
        color = '&H2255BB&',  -- Warm brown
        alpha = '&H30&',
        keywords = {
            'work', 'labor', 'toil', 'effort', 'task', 'job', 'chore', 'make', 'create',
            'build', 'construct', 'assemble', 'manufacture', 'repair', 'fix', 'restore',
            'maintain', 'service', 'clean', 'wash', 'craft', 'forge', 'cast', 'mold', 'shape',
            'weave', 'knit', 'sew', 'stitch', 'embroider', 'cook', 'boil', 'fry', 'roast',
            'bake', 'steam', 'grill', 'brew', 'farm', 'plow', 'harvest', 'reap', 'irrigate',
            'mine', 'drill', 'excavate', 'smelt', 'refine', 'net', 'trap', 'hunt', 'snare',
            'lumber', 'prepare', 'package', 'tool', 'implement', 'device', 'machine',
            'mechanism', 'knife', 'blade', 'dagger', 'cleaver', 'razor', 'axe', 'hatchet',
            'adze', 'hammer', 'mallet', 'chisel', 'saw', 'file', 'plane', 'needle', 'pin',
            'hook', 'buckle', 'clasp', 'thread', 'cord', 'rope', 'wire', 'chain', 'string',
            'brush', 'comb', 'rake', 'broom', 'mop', 'sponge', 'pot', 'pan', 'kettle',
            'cauldron', 'ladle', 'spatula', 'chopstick', 'bowl', 'cup', 'mug', 'glass',
            'goblet', 'bottle', 'flask', 'plate', 'dish', 'tray', 'platter', 'jar', 'jug',
            'urn', 'vase', 'canteen', 'box', 'crate', 'casket', 'bag', 'pouch', 'sack',
            'basket', 'tub', 'wheel', 'pulley', 'lever', 'gear', 'cart', 'wagon', 'sled',
            'palanquin', 'carriage', 'boat', 'ship', 'vessel', 'canoe', 'raft', 'bridge',
            'ladder', 'scaffold', 'platform', 'key', 'lock', 'latch', 'hinge', 'bolt',
            'screw', 'lamp', 'lantern', 'fire pit', 'mirror', 'lens', 'prism', 'house',
            'home', 'dwelling', 'residence', 'abode', 'shelter', 'building', 'structure',
            'construction', 'architecture', 'room', 'chamber', 'hall', 'corridor', 'passage',
            'staircase', 'wall', 'partition', 'pillar', 'beam', 'rafter', 'roof', 'ceiling',
            'floor', 'foundation', 'basement', 'window', 'door', 'gate', 'arch', 'entrance',
            'fence', 'hedge', 'moat', 'drawbridge', 'tower', 'spire', 'turret', 'battlement',
            'road', 'street', 'alley', 'avenue', 'boulevard', 'aqueduct', 'cistern',
            'reservoir', 'garden', 'yard', 'courtyard', 'plaza', 'paddock', 'orchard',
            'stable', 'barn', 'shop', 'stall', 'warehouse', 'storehouse', 'monastery', 'fort',
            'dungeon', 'library', 'auditorium', 'port', 'harbor', 'dock', 'pier',
            'lighthouse', 'food', 'meal', 'cuisine', 'recipe', 'ingredient', 'eat', 'consume',
            'devour', 'chew', 'bite', 'taste', 'savor', 'drink', 'sip', 'gulp', 'quench',
            'slurp', 'starve', 'bread', 'flour', 'noodle', 'pasta', 'meat', 'beef', 'pork',
            'chicken', 'lamb', 'venison', 'seafood', 'shellfish', 'vegetable', 'bean', 'pea',
            'mushroom', 'tofu', 'citrus', 'melon', 'apple', 'peach', 'soup', 'broth', 'stew',
            'porridge', 'congee', 'sauce', 'dip', 'seasoning', 'salt', 'sugar', 'vinegar',
            'oil', 'spice', 'bland', 'wine', 'sake', 'beer', 'liquor', 'mead', 'tea',
            'coffee', 'juice', 'milk', 'cloth', 'fabric', 'textile', 'material', 'fiber',
            'silk', 'cotton', 'wool', 'linen', 'leather', 'clothing', 'garment', 'outfit',
            'attire', 'costume', 'uniform', 'wear', 'dress', 'clothe', 'undress', 'robe',
            'kimono', 'gown', 'cloak', 'mantle', 'shirt', 'coat', 'jacket', 'vest', 'tunic',
            'pants', 'skirt', 'trousers', 'shorts', 'hat', 'cap', 'hood', 'veil', 'mask',
            'crown', 'tiara', 'shoe', 'boot', 'sandal', 'slipper', 'clog', 'glove', 'mitten',
            'sock', 'stocking', 'belt', 'sash', 'strap', 'band', 'sleeve', 'collar', 'hem',
            'seam', 'pocket', 'button', 'zipper', 'dye', 'embroidery', 'lace', 'fringe',
            'ornament', 'decoration', 'adornment', 'accessory', 'ring', 'bracelet',
            'necklace', 'earring', 'brooch', 'pendant', 'powder', 'perfume', 'cosmetic',
            'makeup', 'appearance', 'look', 'fashion', 'trend', 'beauty', 'vehicle', 'chair',
            'desk', 'shelf', 'curtain', 'pillow', 'umbrella', 'shoes', 'bathtub', 'bucket',
            'barrel', 'coffin', 'tank', 'bell', 'scissors', 'saddle', 'bridle', 'cane',
            'furnace', 'kiln', 'loom', 'spindle', 'anvil', 'lathe', 'sieve', 'straw mat',
            'straw', 'provisions', 'chopsticks', 'sweets', 'miso', 'pickles', 'noodles',
            'sushi', 'gyoza', 'paper', 'ink', 'charcoal', 'lacquer', 'tile', 'plank', 'rod',
            'board', 'baggage',
            'kitchen', 'pantry', 'cellar', 'attic', 'veranda', 'porch', 'balcony',
            'mat', 'rug', 'carpet', 'tapestry', 'blanket', 'quilt', 'mattress',
            'fan', 'bellows', 'parasol', 'awning', 'canopy cover',
            'ditch', 'trench', 'gutter', 'drain pipe', 'sewer',
            'park', 'playground', 'arena', 'stadium', 'colosseum',
            'wax', 'resin', 'tar', 'pitch substance', 'glue', 'adhesive',
            'chess', 'checkers', 'dice', 'domino', 'token', 'counter piece',
            'fluid', 'liquid', 'emulsion', 'gel',
            'notebook', 'ledger', 'register book', 'binder',
            'underwear', 'undergarment', 'rags', 'tatters',
            'satin', 'velvet', 'gauze', 'muslin', 'brocade',
            'cornerstone', 'keystone', 'foundation stone',
            'quill', 'feather pen', 'inkwell', 'paintbrush',
            'sampan', 'gondola', 'barge', 'ferry', 'tugboat',
            'mausoleum', 'tomb', 'crypt', 'sepulcher', 'memorial',
            'candlelight', 'lamplight', 'torchlight', 'chandelier'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 🩶 SILVER - State / Quality / Morality / Condition
    -- ═══════════════════════════════════════════════════════════════════
    -- Descriptive attributes, moral qualities, and conditions of being.
    -- Catch-all for adjectives and stative concepts.
    {
        color = '&HCCCCCC&',  -- Silver
        alpha = '&H30&',
        keywords = {
            'new', 'old', 'original', 'traditional', 'classic', 'real', 'actual', 'fake',
            'artificial', 'natural', 'synthetic', 'living', 'dying', 'undead', 'closed',
            'sealed', 'locked', 'bound', 'captive', 'trapped', 'restrained', 'safe', 'secure',
            'dangerous', 'risky', 'hazardous', 'lethal', 'well', 'injured', 'wounded',
            'broken', 'damaged', 'ruined', 'destroyed', 'intact', 'partial', 'incomplete',
            'ready', 'prepared', 'unready', 'unfinished', 'active', 'passive', 'idle', 'busy',
            'awake', 'asleep', 'conscious', 'unconscious', 'good', 'bad', 'evil', 'wicked',
            'malicious', 'corrupt', 'virtue', 'vice', 'sin', 'righteousness', 'mercy',
            'wrong', 'just', 'unjust', 'fair', 'unfair', 'honest', 'dishonest', 'truthful',
            'deceitful', 'hypocritical', 'loyal', 'disloyal', 'faithful', 'treacherous',
            'reliable', 'unreliable', 'brave', 'coward', 'bold', 'timid', 'reckless',
            'cautious', 'kind', 'cruel', 'compassionate', 'heartless', 'gentle', 'harsh',
            'generous', 'selfish', 'greedy', 'charitable', 'humble', 'arrogant', 'proud',
            'vain', 'modest', 'sincere', 'insincere', 'genuine', 'pretentious', 'wise',
            'foolish', 'clever', 'stupid', 'naive', 'cunning', 'patient', 'impatient',
            'diligent', 'lazy', 'persistent', 'stubborn', 'disciplined', 'careful',
            'careless', 'thorough', 'sloppy', 'obedient', 'rebellious', 'submissive',
            'defiant', 'compliant', 'beautiful', 'ugly', 'handsome', 'attractive',
            'repulsive', 'graceful', 'clumsy', 'elegant', 'crude', 'refined', 'coarse',
            'colorful', 'vivid', 'vibrant', 'pale', 'dull', 'faded', 'smooth', 'rough',
            'jagged', 'bumpy', 'silky', 'grainy', 'loud', 'noisy', 'quiet', 'silent',
            'deafening', 'faint', 'fragrant', 'sweet-smelling', 'stinky', 'odorless',
            'rotten', 'hot', 'warm', 'cold', 'cool', 'freezing', 'scalding', 'lukewarm',
            'wet', 'dry', 'damp', 'moist', 'soaked', 'parched', 'sweet', 'bitter', 'sour',
            'salty', 'spicy', 'savory', 'tasteless', 'main', 'primary', 'secondary',
            'central', 'related', 'unrelated', 'relevant', 'irrelevant', 'connected',
            'together', 'alone', 'mutual', 'one-sided', 'reciprocal', 'direct', 'indirect',
            'explicit', 'implicit', 'literal', 'figurative', 'general', 'specific', 'broad',
            'narrow', 'wide', 'limited', 'fragmentary', 'superficial', 'formal', 'informal',
            'unofficial', 'public', 'private', 'inner', 'outer', 'external', 'internal',
            'deep', 'imitation', 'authentic', 'counterfeit', 'dirty', 'tall', 'flat',
            'curved', 'shallow', 'violent', 'fierce', 'strict', 'polite', 'respectful',
            'vulgar', 'stingy', 'frugal', 'lenient', 'intimate', 'friendly', 'devoted',
            'nimble', 'sturdy', 'mediocre', 'plump', 'naked', 'sparse', 'glossy', 'ornate',
            'gorgeous', 'outstanding', 'excellent', 'nasty',
            'thing', 'matter of', 'affair', 'concern',
            'have', 'possess', 'own', 'belong', 'contain',
            'needed', 'required', 'essential for', 'indispensable',
            'roadway', 'highway', 'pathway', 'trail', 'walkway',
            'define', 'specify', 'characterize', 'describe as',
            'respect', 'honor deeply', 'esteem', 'admire', 'veneration',
            'emaciated', 'gaunt', 'skeletal', 'haggard', 'scrawny',
            'liked', 'quality', 'trait', 'attribute', 'characteristic',
            'lightweight', 'heavy duty', 'intense', 'fierce quality', 'mild',
            'secret', 'covert', 'clandestine', 'confidential', 'classified',
            'widespread', 'prevalent', 'pervasive', 'ubiquitous'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 🌸 PINK - Life / Growth / Reproduction / Health / Cycle
    -- ═══════════════════════════════════════════════════════════════════
    -- The biological dimension: life cycles, health, growth, and reproduction.
    {
        color = '&HBB55FF&',  -- Pink
        alpha = '&H30&',
        keywords = {
            'life', 'live', 'alive', 'death', 'die', 'dead', 'mortality', 'immortal', 'birth',
            'born', 'newborn', 'hatch', 'mature', 'decay', 'rot', 'decompose', 'survive',
            'perish', 'extinction', 'revive', 'resurrect', 'growth', 'flourish', 'thrive',
            'prosper', 'decline', 'degenerate', 'deteriorate', 'waste', 'germinate', 'ripen',
            'young', 'juvenile', 'immature', 'undeveloped', 'full-grown', 'developed',
            'prime', 'aged', 'elderly', 'senile', 'withered', 'reproduce', 'breed',
            'propagate', 'spawn', 'mate', 'fertilize', 'conceive', 'pregnant', 'gestate',
            'give birth', 'nurse', 'suckle', 'nurture', 'egg', 'embryo', 'fetus', 'larva',
            'pupa', 'offspring', 'litter', 'brood', 'nest', 'health', 'healthy', 'robust',
            'vigorous', 'sick', 'ill', 'unwell', 'diseased', 'infected', 'afflicted',
            'disease', 'illness', 'ailment', 'condition', 'disorder', 'syndrome', 'fever',
            'chill', 'ache', 'swelling', 'rash', 'wound', 'medicine', 'drug', 'remedy',
            'cure', 'antidote', 'vaccine', 'heal', 'treat', 'recover', 'convalesce',
            'rehabilitate', 'injure', 'damage', 'scar', 'fracture', 'bruise', 'bleed',
            'hemorrhage', 'clot', 'infect', 'fester', 'breathe', 'inhale', 'exhale',
            'choke', 'suffocate', 'gasp', 'hunger', 'thirst', 'fatigue', 'exhaustion',
            'weakness', 'coma', 'poison', 'toxic', 'purify', 'detox', 'renewal', 'rebirth',
            'regenerate', 'regrow', 'molt', 'shed', 'metamorphosis', 'hibernate', 'migrate',
            'wilt', 'freeze', 'thaw', 'medical', 'therapy', 'diagnosis', 'smallpox',
            'epidemic', 'paralysis', 'cancer', 'diarrhea', 'cough', 'inflammation',
            'pregnancy', 'lifespan', 'upbringing', 'nutrition', 'nourishing', 'deceased',
            'funeral',
            'flavor', 'savour', 'aroma', 'fragrance', 'scent of',
            'happiness', 'longevity', 'prosperity', 'fertility', 'abundance',
            'spleen', 'phlegm', 'mucus', 'bile', 'pus',
            'protein', 'vitamin', 'mineral nutrient', 'calcium', 'fiber nutrient',
            'ghee', 'lard', 'tallow', 'grease',
            'cripple', 'disabled', 'handicapped', 'impaired'
        }
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 🟠 AMBER - Knowledge / Science / Skill / Learning / Measurement
    -- ═══════════════════════════════════════════════════════════════════
    -- Human knowledge, skill, science, technology, and measurement.
    {
        color = '&H0099FF&',  -- Amber/gold
        alpha = '&H30&',
        keywords = {
            'learn', 'study', 'educate', 'train', 'practice', 'rehearse', 'teach', 'instruct',
            'mentor', 'coach', 'tutor', 'lecture', 'demonstrate', 'school', 'academy',
            'university', 'institute', 'classroom', 'lesson', 'course', 'curriculum',
            'subject', 'discipline', 'graduate', 'fail', 'exam', 'test', 'quiz', 'homework',
            'assignment', 'diploma', 'certificate', 'qualification', 'information',
            'data', 'master', 'expertise', 'skill', 'ability', 'discover', 'explore',
            'investigate', 'research', 'experiment', 'observe', 'examine', 'analyze',
            'inspect', 'survey', 'evaluate', 'find', 'reveal', 'disclose', 'prove', 'verify',
            'confirm', 'disprove', 'catalog', 'classify', 'archive', 'wisdom', 'intelligence',
            'genius', 'talent', 'gift', 'aptitude', 'memory', 'experience', 'insight',
            'perspective', 'view', 'opinion', 'science', 'physics', 'chemistry', 'biology',
            'mathematics', 'geometry', 'astronomy', 'geography', 'philosophy', 'literature',
            'element', 'compound', 'reaction', 'force', 'energy', 'matter', 'atom',
            'molecule', 'cell', 'organism', 'species', 'genus', 'principle', 'formula',
            'equation', 'method', 'technique', 'process', 'procedure', 'model', 'mastery',
            'expert', 'novice', 'beginner', 'veteran', 'improve', 'perfect', 'hone',
            'sharpen', 'creative', 'innovative', 'inventive', 'plan', 'blueprint', 'scheme',
            'approach', 'measure', 'calculate', 'compute', 'estimate', 'approximate', 'weigh',
            'gauge', 'calibrate', 'scale', 'grade', 'figure', 'digit', 'fraction', 'percent',
            'ratio', 'proportion', 'mass', 'weight', 'temperature', 'speed', 'velocity',
            'pressure', 'density', 'add', 'subtract', 'solve', 'halve', 'square', 'graph',
            'chart', 'table', 'diagram', 'map', 'grid', 'axis', 'technology', 'invention',
            'innovation', 'discovery', 'engineer', 'program', 'network', 'circuit',
            'apparatus', 'equipment', 'component',
            'training', 'specialty', 'performance', 'achievements', 'accomplishment',
            'navigation', 'calibration', 'latitude', 'diameter', 'metric',
            'chemical substance', 'magnetic', 'electric', 'financial', 'insurance',
            'compensation', 'expenditure'
        }
    }
}
