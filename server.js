/**
 * jpdb-mpv server.js
 * Local HTTP bridge between mpv Lua script and jpdb.io API.
 * Runs on localhost:9726 (configurable in config.json).
 *
 * Endpoints:
 *   POST /parse       - tokenize text via jpdb API
 *   POST /review      - submit a review grade (scrapes jpdb.io)
 *   POST /set-flag    - add/remove blacklist, never-forget, forq
 *   POST /mine        - add card to mining deck + set sentence
 *   GET  /config      - return current config
 *   GET  /status      - server health check
 */

'use strict';

const http  = require('http');
const https = require('https');
const fs    = require('fs');
const path  = require('path');
const url   = require('url');

// ─── Debug logging ────────────────────────────────────────────────────────────

const LOG_PATH = path.join(__dirname, 'debug-server.log');
// Truncate log on start
fs.writeFileSync(LOG_PATH, `=== jpdb server started ${new Date().toISOString()} ===\n`);

function log(...args) {
    const line = `[${new Date().toISOString()}] ${args.join(' ')}\n`;
    process.stdout.write(line);
    fs.appendFileSync(LOG_PATH, line);
}

// ─── Config ──────────────────────────────────────────────────────────────────

const CONFIG_PATH = path.join(__dirname, 'config.json');

function loadConfig() {
    try {
        return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
    } catch (e) {
        console.error('[jpdb] Failed to load config.json:', e.message);
        process.exit(1);
    }
}

let config = loadConfig();

// Watch for config changes so user can update API token without restart
fs.watch(CONFIG_PATH, () => {
    try {
        config = loadConfig();
        parseCache.clear();
        log('Config reloaded.');
    } catch (_) {}
});

// ─── Rate limiting ───────────────────────────────────────────────────────────

const API_RATELIMIT    = 200;  // ms between API calls
const SCRAPE_RATELIMIT = 1100; // ms between scrape calls

let lastApiCall    = 0;
let lastScrapeCall = 0;

function waitForRateLimit(type) {
    const now = Date.now();
    if (type === 'api') {
        const wait = Math.max(0, lastApiCall + API_RATELIMIT - now);
        lastApiCall = now + wait;
        return new Promise(r => setTimeout(r, wait));
    } else {
        const wait = Math.max(0, lastScrapeCall + SCRAPE_RATELIMIT - now);
        lastScrapeCall = now + wait;
        return new Promise(r => setTimeout(r, wait));
    }
}

// ─── Parse cache ─────────────────────────────────────────────────────────────

const parseCache = new Map(); // text → tokens

// ─── HTTP helpers ─────────────────────────────────────────────────────────────

function jpdbApiRequest(endpoint, body) {
    return new Promise((resolve, reject) => {
        const data   = JSON.stringify(body);
        const token  = config.apiToken;

        if (!token || token === 'YOUR_JPDB_API_TOKEN_HERE') {
            return reject(new Error('jpdb API token not configured. Edit config.json and set your apiToken.'));
        }

        const options = {
            hostname: 'jpdb.io',
            port:     443,
            path:     `/api/v1${endpoint}`,
            method:   'POST',
            headers: {
                'Content-Type':  'application/json',
                'Authorization': `Bearer ${token}`,
                'Accept':        'application/json',
                'Content-Length': Buffer.byteLength(data),
            },
        };

        const req = https.request(options, res => {
            let body = '';
            res.on('data', chunk => body += chunk);
            res.on('end', () => {
                try {
                    const parsed = JSON.parse(body);
                    if (res.statusCode < 200 || res.statusCode >= 300) {
                        log(`API error ${res.statusCode}: ${JSON.stringify(parsed)}`);
                        return reject(new Error(parsed.error_message || `HTTP ${res.statusCode}`));
                    }
                    resolve(parsed);
                } catch (e) {
                    reject(new Error(`Failed to parse jpdb response: ${e.message}`));
                }
            });
        });

        req.on('error', reject);
        req.write(data);
        req.end();
    });
}

function jpdbScrapeRequest(method, path, formBody, cookieJar) {
    return new Promise((resolve, reject) => {
        const data    = formBody || '';
        const options = {
            hostname: 'jpdb.io',
            port:     443,
            path:     path,
            method:   method,
            headers: {
                'Accept':       'text/html,application/xhtml+xml,*/*',
                'Content-Type': 'application/x-www-form-urlencoded',
                'User-Agent':   'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                'Cookie':       cookieJar || '',
            },
        };

        if (method === 'POST') {
            options.headers['Content-Length'] = Buffer.byteLength(data);
        }

        const req = https.request(options, res => {
            let body = '';
            // Collect Set-Cookie for session
            const setCookie = res.headers['set-cookie'];
            res.on('data', chunk => body += chunk);
            res.on('end', () => {
                if (res.statusCode >= 400) {
                    return reject(new Error(`HTTP ${res.statusCode} from jpdb scrape`));
                }
                if (body.includes('href="/login"') || body.includes('/login">Log in')) {
                    return reject(new Error('Not logged in to jpdb.io. Open jpdb.io in your browser and log in, then try again.'));
                }
                resolve({ body, setCookie: setCookie ? setCookie.join('; ') : '' });
            });
        });

        req.on('error', reject);
        if (method === 'POST' && data) req.write(data);
        req.end();
    });
}

// ─── API handlers ─────────────────────────────────────────────────────────────

const TOKEN_FIELDS = ['vocabulary_index', 'position', 'length', 'furigana'];
const VOCAB_FIELDS = [
    'vid', 'sid', 'rid', 'spelling', 'reading', 'frequency_rank',
    'part_of_speech', 'meanings_chunks', 'meanings_part_of_speech',
    'card_state', 'pitch_accent',
];

async function handleParse(text) {
    if (!text || typeof text !== 'string') throw new Error('text must be a non-empty string');

    const cached = parseCache.get(text);
    if (cached) {
        log(`PARSE cache hit for: "${text.slice(0,40)}"`);
        return cached;
    }

    log(`PARSE request for: "${text.slice(0,60)}"`);
    await waitForRateLimit('api');

    const response = await jpdbApiRequest('/parse', {
        text: [text],
        position_length_encoding: 'utf8',
        token_fields:       TOKEN_FIELDS,
        vocabulary_fields:  VOCAB_FIELDS,
    });

    // Build vocabulary cards
    const cards = response.vocabulary.map(vocab => {
        const [vid, sid, rid, spelling, reading, frequencyRank, partOfSpeech,
               meaningsChunks, meaningsPartOfSpeech, cardState, pitchAccent] = vocab;
        return {
            vid, sid, rid, spelling, reading,
            frequencyRank,
            partOfSpeech,
            meanings: meaningsChunks.map((glosses, i) => ({
                glosses,
                partOfSpeech: meaningsPartOfSpeech[i],
            })),
            state:       cardState || ['not-in-deck'],
            pitchAccent: pitchAccent || [],
        };
    });

    // Build tokens for first text entry
    const tokens = (response.tokens[0] || []).map(token => {
        const [vocabularyIndex, position, length, furigana] = token;
        const card = cards[vocabularyIndex];

        let offset = position;
        const rubies = furigana === null ? [] : furigana.flatMap(part => {
            if (typeof part === 'string') {
                offset += part.length;
                return [];
            }
            const [base, ruby] = part;
            const start = offset;
            const len   = base.length;
            const end   = (offset = start + len);
            return [{ text: ruby, start, end, length: len }];
        });

        return { card, start: position, end: position + length, length, rubies };
    });

    const result = { tokens, cards };
    parseCache.set(text, result);
    log(`PARSE ok: ${tokens.length} tokens, ${cards.length} cards`);

    // Keep cache bounded
    if (parseCache.size > 200) {
        parseCache.delete(parseCache.keys().next().value);
    }

    return result;
}

async function handleReview(vid, sid, rating) {
    const GRADES = {
        nothing: '1', something: '2', hard: '3', good: '4', easy: '5',
        pass: 'p', fail: 'f', known: 'k', unknown: 'n',
    };

    const grade = GRADES[rating];
    if (!grade) throw new Error(`Unknown rating: ${rating}`);
    log(`REVIEW vid=${vid} sid=${sid} rating=${rating} grade=${grade}`);

    await waitForRateLimit('scrape');

    // Step 1: GET the review page to get the review number
    const getResult = await jpdbScrapeRequest(
        'GET',
        `/review?c=vf%2C${vid}%2C${sid}`,
        null,
        ''
    );

    // Extract hidden input r=<review_no>
    const match = getResult.body.match(/name="r"\s+value="(\d+)"/);
    if (!match) {
        throw new Error(`Could not find review number for word ${vid}/${sid}. Make sure the word is in a deck.`);
    }
    const reviewNo = match[1];

    // Extract session cookie from redirect if present
    const cookie = getResult.setCookie;

    await waitForRateLimit('scrape');

    // Step 2: POST the review
    await jpdbScrapeRequest(
        'POST',
        '/review',
        `c=vf%2C${vid}%2C${sid}&r=${reviewNo}&g=${grade}`,
        cookie
    );

    // Invalidate cache so next parse gets fresh state
    parseCache.clear();
}

async function handleSetFlag(vid, sid, flag, state) {
    await waitForRateLimit('api');

    if (flag === 'forq') {
        // FORQ uses scrape-only endpoint
        await waitForRateLimit('scrape');
        const endpoint = state ? '/prioritize' : '/deprioritize';
        await jpdbScrapeRequest('POST', endpoint, `v=${vid}&s=${sid}&origin=/`, '');
    } else {
        const deckMap = {
            'blacklist':    'blacklist',
            'never-forget': 'never-forget',
        };
        const deckId = deckMap[flag];
        if (!deckId) throw new Error(`Unknown flag: ${flag}`);

        const endpoint = state ? '/deck/add-vocabulary' : '/deck/remove-vocabulary';
        await jpdbApiRequest(endpoint, { id: deckId, vocabulary: [[vid, sid]] });
    }

    parseCache.clear();
}

async function handleMine(vid, sid, sentence, translation, forq) {
    await waitForRateLimit('api');

    const deckId = config.miningDeckId;
    if (!deckId) throw new Error('miningDeckId not configured in config.json');

    // Add to mining deck
    await jpdbApiRequest('/deck/add-vocabulary', { id: deckId, vocabulary: [[vid, sid]] });

    // Set sentence if provided
    if (sentence) {
        await waitForRateLimit('api');
        const body = { vid, sid, sentence };
        if (translation) body.translation = translation;
        await jpdbApiRequest('/set-card-sentence', body);
    }

    // Also add to FORQ if requested
    if (forq || config.forqOnMine) {
        await waitForRateLimit('scrape');
        await jpdbScrapeRequest('POST', '/prioritize', `v=${vid}&s=${sid}&origin=/`, '');
    }

    parseCache.clear();
}

async function handleLookup(vid, sid) {
    await waitForRateLimit('api');

    const response = await jpdbApiRequest('/lookup-vocabulary', {
        list:   [[vid, sid]],
        fields: ['card_state'],
    });

    const info = response.vocabulary_info[0];
    if (!info) throw new Error(`Word ${vid}/${sid} not found`);
    return info[0] || ['not-in-deck'];
}

// ─── HTTP server ──────────────────────────────────────────────────────────────

function readBody(req) {
    return new Promise((resolve, reject) => {
        let data = '';
        req.on('data', chunk => data += chunk);
        req.on('end', () => {
            try {
                resolve(data ? JSON.parse(data) : {});
            } catch (e) {
                reject(new Error('Invalid JSON body'));
            }
        });
        req.on('error', reject);
    });
}

function sendJSON(res, statusCode, data) {
    const body = JSON.stringify(data);
    res.writeHead(statusCode, {
        'Content-Type':                'application/json',
        'Access-Control-Allow-Origin': '*',
        'Content-Length':              Buffer.byteLength(body),
    });
    res.end(body);
}

function sendError(res, statusCode, message) {
    sendJSON(res, statusCode, { error: message });
}

const server = http.createServer(async (req, res) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        res.writeHead(204, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET,POST', 'Access-Control-Allow-Headers': 'Content-Type' });
        return res.end();
    }

    const parsedUrl = url.parse(req.url, true);
    const pathname  = parsedUrl.pathname;

    log(`${req.method} ${pathname}`);

    try {
        // GET /status
        if (req.method === 'GET' && pathname === '/status') {
            return sendJSON(res, 200, { ok: true, version: '1.0.0' });
        }

        // GET /config
        if (req.method === 'GET' && pathname === '/config') {
            // Don't expose the full API token
            const safe = { ...config, apiToken: config.apiToken ? '***configured***' : null };
            return sendJSON(res, 200, safe);
        }

        // POST /parse
        if (req.method === 'POST' && pathname === '/parse') {
            const body   = await readBody(req);
            const text   = body.text;
            if (!text) return sendError(res, 400, 'text is required');
            log(`/parse text: "${(text||'').slice(0,60)}"`);
            const result = await handleParse(text);
            return sendJSON(res, 200, result);
        }

        // POST /review
        if (req.method === 'POST' && pathname === '/review') {
            const body = await readBody(req);
            const { vid, sid, rating } = body;
            if (!vid || !sid || !rating) return sendError(res, 400, 'vid, sid, and rating are required');
            await handleReview(vid, sid, rating);
            return sendJSON(res, 200, { ok: true });
        }

        // POST /set-flag
        if (req.method === 'POST' && pathname === '/set-flag') {
            const body = await readBody(req);
            const { vid, sid, flag, state } = body;
            if (!vid || !sid || !flag || state === undefined) return sendError(res, 400, 'vid, sid, flag, and state are required');
            await handleSetFlag(vid, sid, flag, state);
            return sendJSON(res, 200, { ok: true });
        }

        // POST /mine
        if (req.method === 'POST' && pathname === '/mine') {
            const body = await readBody(req);
            const { vid, sid, sentence, translation, forq } = body;
            if (!vid || !sid) return sendError(res, 400, 'vid and sid are required');
            await handleMine(vid, sid, sentence || null, translation || null, forq !== false);
            return sendJSON(res, 200, { ok: true });
        }

        // POST /lookup
        if (req.method === 'POST' && pathname === '/lookup') {
            const body  = await readBody(req);
            const { vid, sid } = body;
            if (!vid || !sid) return sendError(res, 400, 'vid and sid are required');
            const state = await handleLookup(vid, sid);
            return sendJSON(res, 200, { state });
        }

        sendError(res, 404, `Unknown endpoint: ${pathname}`);

    } catch (err) {
        console.error('[jpdb] Error:', err.message);
        sendError(res, 500, err.message);
    }
});

const PORT = config.serverPort || 9726;
server.listen(PORT, '127.0.0.1', () => {
    log(`Server running at http://127.0.0.1:${PORT}`);
    log(`Config: miningDeckId=${config.miningDeckId}, forqOnMine=${config.forqOnMine}`);
    if (!config.apiToken || config.apiToken === 'YOUR_JPDB_API_TOKEN_HERE') {
        log('WARNING: apiToken not set in config.json — API calls will fail!');
    }
});

server.on('error', err => {
    if (err.code === 'EADDRINUSE') {
        log(`Port ${PORT} already in use. Is another instance running?`);
    } else {
        log('Server error: ' + err.message);
    }
    process.exit(1);
});
