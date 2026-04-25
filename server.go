// jpdb-mpv server.go
// Build:  go build -o jpdb-server .
// Run:    ./jpdb-server
//
// Requires Go 1.22+ (method+path routing syntax)

package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
	"unicode/utf8"

	"golang.org/x/image/font"
	"golang.org/x/image/font/sfnt"
	"golang.org/x/image/math/fixed"
)

// ─── MPV instance counter ─────────────────────────────────────────────────────
// Each MPV window calls POST /register on startup and POST /unregister on
// shutdown. When the count drops to zero the server exits gracefully so it
// doesn't linger after the last player closes.

var (
	mpvCount   int64          // atomic — current number of live MPV instances
	shutdownCh = make(chan struct{}) // closed to trigger graceful shutdown
)

func handleRegister(w http.ResponseWriter, r *http.Request) {
	n := atomic.AddInt64(&mpvCount, 1)
	logger.Log("MPV registered (total=%d)", n)
	sendJSON(w, 200, map[string]any{"ok": true, "mpv_count": n})
}

func handleUnregister(w http.ResponseWriter, r *http.Request) {
	n := atomic.AddInt64(&mpvCount, -1)
	if n < 0 {
		atomic.StoreInt64(&mpvCount, 0)
		n = 0
	}
	logger.Log("MPV unregistered (total=%d)", n)
	sendJSON(w, 200, map[string]any{"ok": true, "mpv_count": n})
	if n == 0 {
		logger.Log("Last MPV instance closed — shutting down server")
		close(shutdownCh)
	}
}

// ─── Config ───────────────────────────────────────────────────────────────────

type Config struct {
	APIToken     string `json:"apiToken"`
	MiningDeckID string `json:"miningDeckId"`
	ServerPort   int    `json:"serverPort"`
	ForqOnMine   bool   `json:"forqOnMine"`
	CookiePath   string `json:"cookiePath"`
	Debug        bool   `json:"debug"`
}

var currentConfig atomic.Pointer[Config]

func loadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read config.json: %w", err)
	}
	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("parse config.json: %w", err)
	}
	if cfg.ServerPort == 0 {
		cfg.ServerPort = 9726
	}
	return &cfg, nil
}

func getConfig() *Config { return currentConfig.Load() }

// ─── Persistent cookie store ──────────────────────────────────────────────────
// Loaded from cookiePath on startup; written back whenever jpdb sends a
// Set-Cookie header so the session stays alive across server restarts.
//
// The cookie file may be in Netscape cookie jar format (tab-separated:
//   domain  httpOnly  path  secure  expiry  name  value)
// or in simple "name=value; name=value" format.
// We detect the format automatically.

var (
	cookieMu     sync.RWMutex
	storedCookie string // ready-to-use Cookie header value: "sid=abc; foo=bar"
)

func getCookiePath() string {
	cfg := getConfig()
	if cfg == nil {
		return ""
	}
	return cfg.CookiePath
}

// parseNetscapeCookieJar reads a Netscape cookie jar file and returns a map
// of cookie name → value. Lines starting with # or blank are skipped.
// Valid lines have 7 tab-separated fields:
//
//	domain  includeSubdomains  path  secure  expiry  name  value
func parseNetscapeCookieJar(data string) map[string]string {
	out := map[string]string{}
	for _, line := range strings.Split(data, "\n") {
		line = strings.TrimRight(line, "\r")
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		fields := strings.SplitN(line, "\t", 7)
		if len(fields) == 7 {
			name := strings.TrimSpace(fields[5])
			value := strings.TrimSpace(fields[6])
			if name != "" {
				out[name] = value
			}
			continue
		}
		// Fallback: simple key=value pairs separated by semicolons
		for _, part := range strings.Split(line, ";") {
			part = strings.TrimSpace(part)
			if idx := strings.IndexByte(part, '='); idx > 0 {
				out[part[:idx]] = part[idx+1:]
			}
		}
	}
	return out
}

// cookieMapToHeader builds a Cookie request header string from a name→value map.
func cookieMapToHeader(m map[string]string) string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	parts := make([]string, 0, len(m))
	for _, k := range keys {
		parts = append(parts, k+"="+m[k])
	}
	return strings.Join(parts, "; ")
}

// cookieMapToNetscape serialises a name→value map as a Netscape cookie jar file.
func cookieMapToNetscape(m map[string]string) string {
	const expiry = "4070908800" // 2099-01-01
	lines := []string{
		"# Netscape HTTP Cookie File",
		"# Managed by jpdb-server.",
		"",
	}
	for name, value := range m {
		lines = append(lines, strings.Join([]string{
			"jpdb.io", "FALSE", "/", "FALSE", expiry, name, value,
		}, "\t"))
	}
	return strings.Join(lines, "\n") + "\n"
}

// parseCookieHeader extracts name=value pairs from a Set-Cookie response
// header, discarding cookie attributes (Path, Expires, HttpOnly, etc.).
func parseCookieHeader(setCookieValue string) map[string]string {
	out := map[string]string{}
	for _, part := range strings.Split(setCookieValue, ";") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		lower := strings.ToLower(part)
		if strings.HasPrefix(lower, "path=") || strings.HasPrefix(lower, "expires=") ||
			strings.HasPrefix(lower, "max-age=") || strings.HasPrefix(lower, "domain=") ||
			strings.HasPrefix(lower, "samesite=") || lower == "httponly" || lower == "secure" {
			continue
		}
		if idx := strings.IndexByte(part, '='); idx > 0 {
			out[part[:idx]] = part[idx+1:]
		}
	}
	return out
}

func loadCookieFile() {
	p := getCookiePath()
	if p == "" {
		return
	}
	data, err := os.ReadFile(p)
	if err != nil {
		if !os.IsNotExist(err) {
			logger.Log("WARN cookie load: %v", err)
		}
		return
	}
	pairs := parseNetscapeCookieJar(string(data))
	header := cookieMapToHeader(pairs)
	cookieMu.Lock()
	storedCookie = header
	cookieMu.Unlock()
	if header != "" {
		logger.Log("Cookie loaded (%d pairs) from %s", len(pairs), p)
	} else {
		logger.Log("Cookie file present but no valid cookies found in %s", p)
	}
}

func getStoredCookie() string {
	cookieMu.RLock()
	defer cookieMu.RUnlock()
	return storedCookie
}

// saveCookie merges new Set-Cookie values from a scrape response into the
// in-memory store and persists the updated map to disk in Netscape format.
func saveCookie(setCookieHeader string) {
	if setCookieHeader == "" {
		return
	}
	incoming := parseCookieHeader(setCookieHeader)
	if len(incoming) == 0 {
		return
	}

	p := getCookiePath()

	// Reload existing file so we don't lose cookies we don't have in memory
	var existing map[string]string
	if p != "" {
		if data, err := os.ReadFile(p); err == nil {
			existing = parseNetscapeCookieJar(string(data))
		}
	}
	if existing == nil {
		existing = map[string]string{}
	}
	for k, v := range incoming {
		existing[k] = v
	}

	header := cookieMapToHeader(existing)
	cookieMu.Lock()
	storedCookie = header
	cookieMu.Unlock()

	if p == "" {
		return
	}
	if err := os.WriteFile(p, []byte(cookieMapToNetscape(existing)), 0600); err != nil {
		logger.Log("WARN cookie save: %v", err)
	} else {
		logger.Log("Cookie saved (%d pairs) to %s", len(existing), p)
	}
}

// ─── Async buffered logger ────────────────────────────────────────────────────
// When debug=false the logger is a silent no-op (no file, no stdout output).
// When debug=true it writes timestamped lines to a log file and stdout.
// The enabled flag can be toggled at runtime via setDebug() on hot-reload.

type AsyncLogger struct {
	ch      chan string
	f       *os.File
	buf     *bufio.Writer
	enabled atomic.Bool
	done    chan struct{}
}

func newAsyncLogger(path string, enabled bool) *AsyncLogger {
	al := &AsyncLogger{
		ch:   make(chan string, 4096),
		done: make(chan struct{}),
	}
	al.enabled.Store(enabled)
	if enabled {
		f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
		if err != nil {
			log.Fatalf("Cannot open log file: %v", err)
		}
		al.f = f
		al.buf = bufio.NewWriterSize(f, 64*1024)
	}
	go al.drain()
	return al
}

func (al *AsyncLogger) setDebug(enabled bool, path string) {
	was := al.enabled.Swap(enabled)
	if enabled && !was && al.f == nil {
		// Turning on: open the log file for the first time
		f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err == nil {
			al.f = f
			al.buf = bufio.NewWriterSize(f, 64*1024)
		}
	}
}

func (al *AsyncLogger) drain() {
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case line, ok := <-al.ch:
			if !ok {
				// Channel closed — flush and exit
				if al.buf != nil {
					al.buf.Flush()
				}
				if al.f != nil {
					al.f.Close()
				}
				return
			}
			if al.buf != nil {
				al.buf.WriteString(line)
			}
		case <-ticker.C:
			if al.buf != nil {
				al.buf.Flush()
			}
		}
	}
}

func (al *AsyncLogger) Close() {
	close(al.ch)
}

func (al *AsyncLogger) Log(format string, args ...any) {
	if !al.enabled.Load() {
		return
	}
	line := fmt.Sprintf("[%s] %s\n",
		time.Now().Format("15:04:05.000"),
		fmt.Sprintf(format, args...))
	fmt.Print(line)
	select {
	case al.ch <- line:
	default: // drop if buffer full — never block
	}
}

var logger *AsyncLogger

// ─── Rate limiter ─────────────────────────────────────────────────────────────
// Tracks the next available slot; callers sleep only when needed.
// Concurrent callers queue fairly via the mutex.

type RateLimiter struct {
	mu       sync.Mutex
	nextSlot time.Time
	gap      time.Duration
}

func newRateLimiter(gap time.Duration) *RateLimiter {
	return &RateLimiter{nextSlot: time.Now(), gap: gap}
}

func (r *RateLimiter) Wait(ctx context.Context) error {
	r.mu.Lock()
	now := time.Now()
	wait := r.nextSlot.Sub(now)
	if wait < 0 {
		wait = 0
	}
	r.nextSlot = now.Add(wait).Add(r.gap)
	r.mu.Unlock()

	if wait > 0 {
		select {
		case <-time.After(wait):
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	return nil
}

var (
	apiLimiter    = newRateLimiter(200 * time.Millisecond)
	scrapeLimiter = newRateLimiter(1100 * time.Millisecond)
)

// ─── LRU Parse Cache ──────────────────────────────────────────────────────────
// O(1) get/set/evict via doubly-linked list + map.
// RWMutex allows concurrent reads; writes take exclusive lock.

type cacheEntry struct {
	key        string
	val        json.RawMessage
	prev, next *cacheEntry
}

type LRUCache struct {
	mu         sync.RWMutex
	cap        int
	items      map[string]*cacheEntry
	head, tail *cacheEntry
}

func newLRUCache(cap int) *LRUCache {
	return &LRUCache{cap: cap, items: make(map[string]*cacheEntry, cap)}
}

func (c *LRUCache) Get(key string) (json.RawMessage, bool) {
	c.mu.Lock()
	e, ok := c.items[key]
	if !ok {
		c.mu.Unlock()
		return nil, false
	}
	c.remove(e)
	c.pushFront(e)
	val := e.val
	c.mu.Unlock()
	return val, true
}

func (c *LRUCache) Set(key string, val json.RawMessage) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if e, ok := c.items[key]; ok {
		e.val = val
		c.remove(e)
		c.pushFront(e)
		return
	}
	if len(c.items) >= c.cap {
		if c.tail != nil {
			delete(c.items, c.tail.key)
			c.remove(c.tail)
		}
	}
	e := &cacheEntry{key: key, val: val}
	c.items[key] = e
	c.pushFront(e)
}

func (c *LRUCache) Clear() {
	c.mu.Lock()
	c.items = make(map[string]*cacheEntry, c.cap)
	c.head, c.tail = nil, nil
	c.mu.Unlock()
}

func (c *LRUCache) remove(e *cacheEntry) {
	if e.prev != nil {
		e.prev.next = e.next
	} else {
		c.head = e.next
	}
	if e.next != nil {
		e.next.prev = e.prev
	} else {
		c.tail = e.prev
	}
	e.prev, e.next = nil, nil
}

func (c *LRUCache) pushFront(e *cacheEntry) {
	e.next = c.head
	e.prev = nil
	if c.head != nil {
		c.head.prev = e
	}
	c.head = e
	if c.tail == nil {
		c.tail = e
	}
}

var parseCache = newLRUCache(300)

// Audio cache: vid → decoded audio bytes (OGG)
type audioCacheEntry struct {
	data        []byte
	contentType string
}

var (
	audioCacheMu sync.RWMutex
	audioCache   = make(map[string]*audioCacheEntry, 50)
)

// ─── HTTPS client ─────────────────────────────────────────────────────────────
// Tuned transport for jpdb.io: connection pool + HTTP/2 multiplexing.

var jpdbClient = &http.Client{
	Timeout: 30 * time.Second,
	Transport: &http.Transport{
		MaxIdleConns:          10,
		MaxIdleConnsPerHost:   4,
		MaxConnsPerHost:       4,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   10 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
		ForceAttemptHTTP2:     true,
	},
}

// ─── JPDB API request ─────────────────────────────────────────────────────────

func jpdbAPI(ctx context.Context, endpoint string, body any) (json.RawMessage, error) {
	cfg := getConfig()
	if cfg.APIToken == "" || cfg.APIToken == "YOUR_JPDB_API_TOKEN_HERE" {
		return nil, fmt.Errorf("jpdb API token not configured in config.json")
	}

	if err := apiLimiter.Wait(ctx); err != nil {
		return nil, err
	}

	payload, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, "POST",
		"https://jpdb.io/api/v1"+endpoint, bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+cfg.APIToken)
	req.Header.Set("Accept", "application/json")

	resp, err := jpdbClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("jpdb API request failed: %w", err)
	}
	defer resp.Body.Close()

	respData, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20)) // 2 MB limit
	if err != nil {
		return nil, err
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		var errBody map[string]any
		json.Unmarshal(respData, &errBody)
		msg, _ := errBody["error_message"].(string)
		if msg == "" {
			msg = fmt.Sprintf("HTTP %d", resp.StatusCode)
		}
		logger.Log("API error %d: %s", resp.StatusCode, string(respData))
		return nil, fmt.Errorf("jpdb API error: %s", msg)
	}

	return json.RawMessage(respData), nil
}

// ─── JPDB scrape request ──────────────────────────────────────────────────────

func jpdbScrape(ctx context.Context, method, urlPath, formBody, cookie string) (string, string, error) {
	if err := scrapeLimiter.Wait(ctx); err != nil {
		return "", "", err
	}

	var bodyReader io.Reader
	if formBody != "" {
		bodyReader = strings.NewReader(formBody)
	}

	req, err := http.NewRequestWithContext(ctx, method,
		"https://jpdb.io"+urlPath, bodyReader)
	if err != nil {
		return "", "", err
	}
	req.Header.Set("Accept", "text/html,application/xhtml+xml,*/*")
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
	if cookie != "" {
		req.Header.Set("Cookie", cookie)
	}
	if formBody != "" {
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	}

	resp, err := jpdbClient.Do(req)
	if err != nil {
		return "", "", fmt.Errorf("scrape request failed: %w", err)
	}
	defer resp.Body.Close()

	setCookie := strings.Join(resp.Header["Set-Cookie"], "; ")

	bodyBytes, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20)) // 2 MB limit
	if err != nil {
		return "", "", err
	}
	bodyStr := string(bodyBytes)

	if resp.StatusCode >= 400 {
		return "", "", fmt.Errorf("HTTP %d from jpdb scrape", resp.StatusCode)
	}
	if strings.Contains(bodyStr, `href="/login"`) || strings.Contains(bodyStr, `/login">Log in`) {
		return "", "", fmt.Errorf("not logged in to jpdb.io — please log in via browser")
	}

	return bodyStr, setCookie, nil
}

// ─── Font metrics for pixel-accurate hit detection ────────────────────────────

var (
	metricsFont     *sfnt.Font
	metricsFontErr  error
	metricsFontOnce sync.Once
)

// loadMetricsFont tries common Windows font paths for Yu Gothic UI.
// Falls back gracefully — if no font is found, /parse responses omit px_map
// and the Lua side uses its estimated width model.
func loadMetricsFont() {
	// Priority order: YuGothM.ttc has "Yu Gothic UI Regular" (face[1]),
	// which matches the ASS \fn "Yu Gothic UI" specification.
	// YuGothR.ttc has "Yu Gothic Regular" + "Yu Gothic UI Semilight" — wrong weights.
	fontPaths := []string{
		filepath.Join(os.Getenv("WINDIR"), "Fonts", "YuGothM.ttc"),
		filepath.Join(os.Getenv("WINDIR"), "Fonts", "YuGothR.ttc"),
		filepath.Join(os.Getenv("WINDIR"), "Fonts", "YuGothB.ttc"),
		`C:\Windows\Fonts\YuGothM.ttc`,
		`C:\Windows\Fonts\YuGothR.ttc`,
		`C:\Windows\Fonts\YuGothB.ttc`,
		filepath.Join(os.Getenv("WINDIR"), "Fonts", "yugothic.ttf"),
		filepath.Join(os.Getenv("WINDIR"), "Fonts", "msgothic.ttc"),
	}

	targetFamily := "Yu Gothic UI"

	for _, p := range fontPaths {
		data, err := os.ReadFile(p)
		if err != nil {
			continue
		}

		// Try as TrueType Collection — enumerate all faces to find exact match
		col, err := sfnt.ParseCollection(data)
		if err == nil {
			numFonts := col.NumFonts()
			logger.Log("FONT file %s: TTC with %d faces", p, numFonts)
			var bestFont *sfnt.Font
			bestScore := 0
			for i := 0; i < numFonts; i++ {
				f, err := col.Font(i)
				if err != nil {
					continue
				}
				var buf sfnt.Buffer
				name, _ := f.Name(&buf, sfnt.NameIDFamily)
				full, _ := f.Name(&buf, sfnt.NameIDFull)
				logger.Log("FONT face[%d]: family=%q full=%q", i, name, full)

				score := 0
				if name == targetFamily {
					score = 3 // Exact match: "Yu Gothic UI"
				} else if strings.HasPrefix(name, targetFamily+" ") {
					score = 2 // Variant: "Yu Gothic UI Semilight", etc.
				} else if strings.Contains(name, "Gothic") {
					score = 1 // Fallback: any Gothic font
				}
				if score > bestScore {
					bestScore = score
					bestFont = f
					logger.Log("FONT candidate face[%d]: %q (score=%d)", i, name, score)
				}
			}
			if bestFont != nil {
				metricsFont = bestFont
				var buf sfnt.Buffer
				name, _ := metricsFont.Name(&buf, sfnt.NameIDFamily)
				logger.Log("FONT SELECTED: %q from %s", name, p)
				return
			}
		}

		// Try as single font
		f, err := sfnt.Parse(data)
		if err == nil {
			var buf sfnt.Buffer
			name, _ := f.Name(&buf, sfnt.NameIDFamily)
			logger.Log("FONT loaded: %s family=%q", p, name)
			metricsFont = f
			return
		}
	}

	metricsFontErr = fmt.Errorf("could not load any Japanese font for metrics")
	logger.Log("FONT WARNING: %v — hover will use estimated widths", metricsFontErr)
}

// computePixelMap returns a byte-indexed (1-based) cumulative pixel map
// for the given text at the given font size.  Each entry is [bytePos, px].
// Returns nil if font is not available.
func computePixelMap(text string, fontSize float64) [][]float64 {
	metricsFontOnce.Do(loadMetricsFont)
	if metricsFont == nil {
		return nil
	}

	var buf sfnt.Buffer
	ppem := fixed.Int26_6(fontSize * 64) // 26.6 fixed point

	result := make([][]float64, 0, utf8.RuneCountInString(text)+1)
	cumPx := 0.0
	byteIdx := 0
	var prevGlyph sfnt.GlyphIndex
	hasPrev := false
	fallbackCount := 0

	for _, r := range text {
		result = append(result, []float64{float64(byteIdx + 1), cumPx})

		idx, err := metricsFont.GlyphIndex(&buf, r)
		if err != nil || idx == 0 {
			// Glyph not in font — estimate based on Unicode range
			fallbackCount++
			if r >= 0x3000 {
				cumPx += fontSize
			} else if r >= 0x80 {
				cumPx += fontSize * 0.5
			} else {
				cumPx += fontSize * 0.5
			}
			hasPrev = false
		} else {
			// Apply kerning between consecutive glyphs
			if hasPrev {
				kern, err := metricsFont.Kern(&buf, prevGlyph, idx, ppem, font.HintingNone)
				if err == nil {
					cumPx += float64(kern) / 64.0
				}
			}
			adv, err := metricsFont.GlyphAdvance(&buf, idx, ppem, font.HintingNone)
			if err != nil {
				cumPx += fontSize
			} else {
				cumPx += float64(adv) / 64.0
			}
			prevGlyph = idx
			hasPrev = true
		}

		byteIdx += utf8.RuneLen(r)
	}

	// Sentinel: end of text
	result = append(result, []float64{float64(byteIdx + 1), cumPx})

	if fallbackCount > 0 {
		logger.Log("FONT px_map: %d chars, %d glyph fallbacks, total=%.1fpx", utf8.RuneCountInString(text), fallbackCount, cumPx)
	}

	return result
}

// ─── Parse handler ────────────────────────────────────────────────────────────

var (
	tokenFields = []string{"vocabulary_index", "position", "length", "furigana"}
	vocabFields = []string{
		"vid", "sid", "rid", "spelling", "reading", "frequency_rank",
		"part_of_speech", "meanings_chunks", "meanings_part_of_speech",
		"card_state", "pitch_accent",
	}
)

func handleParse(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	var body struct {
		Text     string  `json:"text"`
		FontSize float64 `json:"font_size"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Text == "" {
		sendError(w, 400, "text is required")
		return
	}
	if body.FontSize <= 0 {
		body.FontSize = 60 // default
	}

	// Cache key includes font_size for pixel map accuracy
	cacheKey := fmt.Sprintf("%s@@%.0f", body.Text, body.FontSize)
	if cached, ok := parseCache.Get(cacheKey); ok {
		logger.Log("PARSE cache hit: %q", truncate(body.Text, 40))
		sendRaw(w, 200, cached)
		return
	}

	logger.Log("PARSE: %q", truncate(body.Text, 60))

	raw, err := jpdbAPI(r.Context(), "/parse", map[string]any{
		"text":                     []string{body.Text},
		"position_length_encoding": "utf8",
		"token_fields":             tokenFields,
		"vocabulary_fields":        vocabFields,
	})
	if err != nil {
		sendError(w, 500, err.Error())
		return
	}

	var resp struct {
		Vocabulary [][]json.RawMessage   `json:"vocabulary"`
		Tokens     [][][]json.RawMessage `json:"tokens"`
	}
	if err := json.Unmarshal(raw, &resp); err != nil {
		sendError(w, 500, "failed to parse jpdb response: "+err.Error())
		return
	}

	// Build cards
	cards := make([]map[string]any, 0, len(resp.Vocabulary))
	for _, v := range resp.Vocabulary {
		if len(v) < 11 {
			continue
		}
		var chunksRaw [][]json.RawMessage
		json.Unmarshal(v[7], &chunksRaw)
		var posChunks []json.RawMessage
		json.Unmarshal(v[8], &posChunks)

		meanings := make([]map[string]any, 0, len(chunksRaw))
		for i, glosses := range chunksRaw {
			m := map[string]any{"glosses": glosses}
			if i < len(posChunks) {
				m["partOfSpeech"] = posChunks[i]
			}
			meanings = append(meanings, m)
		}

		state := json.RawMessage(`["not-in-deck"]`)
		if v[9] != nil && string(v[9]) != "null" {
			state = v[9]
		}

		cards = append(cards, map[string]any{
			"vid": v[0], "sid": v[1], "rid": v[2],
			"spelling": v[3], "reading": v[4],
			"frequencyRank": v[5],
			"partOfSpeech":  v[6],
			"meanings":      meanings,
			"state":         state,
			"pitchAccent":   v[10],
		})
	}

	// Build tokens
	var rawTokens [][]json.RawMessage
	if len(resp.Tokens) > 0 {
		rawTokens = resp.Tokens[0]
	}

	tokens := make([]map[string]any, 0, len(rawTokens))
	for _, t := range rawTokens {
		if len(t) < 4 {
			continue
		}
		var vocabIdx int
		json.Unmarshal(t[0], &vocabIdx)
		var position, length int64
		json.Unmarshal(t[1], &position)
		json.Unmarshal(t[2], &length)

		// Build rubies — use rune length for correct multi-byte Japanese offsets
		rubies := []map[string]any{}
		if string(t[3]) != "null" {
			var furigana []json.RawMessage
			json.Unmarshal(t[3], &furigana)
			offset := position
			for _, part := range furigana {
				var s string
				if json.Unmarshal(part, &s) == nil {
					// Plain string — advance by rune count, not byte count
					offset += int64(len([]rune(s)))
					continue
				}
				var pair []string
				if json.Unmarshal(part, &pair) == nil && len(pair) == 2 {
					start := offset
					runeLen := int64(len([]rune(pair[0])))
					offset += runeLen
					rubies = append(rubies, map[string]any{
						"text":   pair[1],
						"start":  start,
						"end":    offset,
						"length": runeLen,
					})
				}
			}
		}

		var card any
		if vocabIdx >= 0 && vocabIdx < len(cards) {
			card = cards[vocabIdx]
		}
		tokens = append(tokens, map[string]any{
			"card":   card,
			"start":  position,
			"end":    position + length,
			"length": length,
			"rubies": rubies,
		})
	}

	// Compute pixel-accurate character width map using actual font metrics
	pxMap := computePixelMap(body.Text, body.FontSize)

	responseData := map[string]any{"tokens": tokens, "cards": cards}
	if pxMap != nil {
		responseData["px_map"] = pxMap
	}

	result, _ := json.Marshal(responseData)
	parseCache.Set(cacheKey, result)
	logger.Log("PARSE ok: %d tokens, %d cards, px_map=%v", len(tokens), len(cards), pxMap != nil)
	sendRaw(w, 200, result)
}

// ─── Review handler ───────────────────────────────────────────────────────────

var reviewNoRE = regexp.MustCompile(`name="r"\s+value="(\d+)"`)
var dataAudioRE = regexp.MustCompile(`data-audio="([^"]+)"`)

var grades = map[string]string{
	"nothing": "1", "something": "2", "hard": "3",
	"good": "4", "easy": "5", "pass": "p",
	"fail": "f", "known": "k", "unknown": "n",
}

func handleReview(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	var body struct {
		VID    any    `json:"vid"`
		SID    any    `json:"sid"`
		Rating string `json:"rating"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		sendError(w, 400, "invalid JSON: "+err.Error())
		return
	}

	vid := anyToStr(body.VID)
	sid := anyToStr(body.SID)
	if vid == "" || sid == "" || body.Rating == "" {
		sendError(w, 400, "vid, sid, and rating are required")
		return
	}

	grade, ok := grades[body.Rating]
	if !ok {
		sendError(w, 400, "unknown rating: "+body.Rating)
		return
	}

	logger.Log("REVIEW vid=%s sid=%s rating=%s", vid, sid, body.Rating)

	page, newCookie, err := jpdbScrape(r.Context(), "GET",
		fmt.Sprintf("/review?c=vf%%2C%s%%2C%s", vid, sid), "", getStoredCookie())
	if err != nil {
		sendError(w, 500, err.Error())
		return
	}
	if newCookie != "" {
		saveCookie(newCookie)
	}

	matches := reviewNoRE.FindStringSubmatch(page)
	if matches == nil {
		sendError(w, 500, "could not find review number — is the word in a deck?")
		return
	}

	form := fmt.Sprintf("c=vf%%2C%s%%2C%s&r=%s&g=%s", vid, sid, matches[1], grade)
	if _, newCookie2, err2 := jpdbScrape(r.Context(), "POST", "/review", form, getStoredCookie()); err2 != nil {
		sendError(w, 500, err2.Error())
		return
	} else if newCookie2 != "" {
		saveCookie(newCookie2)
	}

	parseCache.Clear()
	sendJSON(w, 200, map[string]any{"ok": true})
}

// ─── Set-flag handler ─────────────────────────────────────────────────────────

func handleSetFlag(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	var body struct {
		VID   any    `json:"vid"`
		SID   any    `json:"sid"`
		Flag  string `json:"flag"`
		State *bool  `json:"state"` // *bool distinguishes false from missing
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		sendError(w, 400, "invalid JSON: "+err.Error())
		return
	}

	vid := anyToStr(body.VID)
	sid := anyToStr(body.SID)
	if vid == "" || sid == "" || body.Flag == "" || body.State == nil {
		sendError(w, 400, "vid, sid, flag, and state are required")
		return
	}

	logger.Log("SET-FLAG vid=%s sid=%s flag=%s state=%v", vid, sid, body.Flag, *body.State)

	var err error
	if body.Flag == "forq" {
		ep := "/deprioritize"
		if *body.State {
			ep = "/prioritize"
		}
		var newCookie string
		_, newCookie, err = jpdbScrape(r.Context(), "POST", ep,
			fmt.Sprintf("v=%s&s=%s&origin=/", vid, sid), getStoredCookie())
		if newCookie != "" {
			saveCookie(newCookie)
		}
	} else {
		deckMap := map[string]string{
			"blacklist":    "blacklist",
			"never-forget": "never-forget",
		}
		deckID, exists := deckMap[body.Flag]
		if !exists {
			sendError(w, 400, "unknown flag: "+body.Flag)
			return
		}
		ep := "/deck/remove-vocabulary"
		if *body.State {
			ep = "/deck/add-vocabulary"
		}
		vidInt, vidOk := anyToInt64(body.VID)
		sidInt, sidOk := anyToInt64(body.SID)
		if !vidOk || !sidOk {
			sendError(w, 400, "vid and sid must be integers")
			return
		}
		_, err = jpdbAPI(r.Context(), ep, map[string]any{
			"id":         deckID,
			"vocabulary": [][]int64{{vidInt, sidInt}},
		})
	}

	if err != nil {
		sendError(w, 500, err.Error())
		return
	}
	parseCache.Clear()
	sendJSON(w, 200, map[string]any{"ok": true})
}

// ─── Mine handler ─────────────────────────────────────────────────────────────

func handleMine(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	var body struct {
		VID         any    `json:"vid"`
		SID         any    `json:"sid"`
		Sentence    string `json:"sentence"`
		Translation string `json:"translation"`
		Forq        *bool  `json:"forq"` // *bool distinguishes false from missing
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		sendError(w, 400, "invalid JSON: "+err.Error())
		return
	}

	vid := anyToStr(body.VID)
	sid := anyToStr(body.SID)
	if vid == "" || sid == "" {
		sendError(w, 400, "vid and sid are required")
		return
	}

	cfg := getConfig()
	if cfg.MiningDeckID == "" {
		sendError(w, 500, "miningDeckId not configured in config.json")
		return
	}

	logger.Log("MINE vid=%s sid=%s", vid, sid)

	vidInt, vidOk := anyToInt64(body.VID)
	sidInt, sidOk := anyToInt64(body.SID)
	if !vidOk || !sidOk {
		sendError(w, 400, "vid and sid must be integers")
		return
	}

	if _, err := jpdbAPI(r.Context(), "/deck/add-vocabulary", map[string]any{
		"id":         cfg.MiningDeckID,
		"vocabulary": [][]int64{{vidInt, sidInt}},
	}); err != nil {
		sendError(w, 500, err.Error())
		return
	}

	if body.Sentence != "" {
		sb := map[string]any{"vid": vidInt, "sid": sidInt, "sentence": body.Sentence}
		if body.Translation != "" {
			sb["translation"] = body.Translation
		}
		if _, err := jpdbAPI(r.Context(), "/set-card-sentence", sb); err != nil {
			logger.Log("WARN set-card-sentence: %v", err)
		}
	}

	// Explicit false from client overrides config; missing Forq falls back to config
	doForq := cfg.ForqOnMine
	if body.Forq != nil {
		doForq = *body.Forq
	}
	if doForq {
		form := fmt.Sprintf("v=%s&s=%s&origin=/", vid, sid)
		if _, _, err := jpdbScrape(r.Context(), "POST", "/prioritize", form, ""); err != nil {
			logger.Log("WARN FORQ: %v", err)
		}
	}

	parseCache.Clear()
	sendJSON(w, 200, map[string]any{"ok": true})
}

// ─── Lookup handler ───────────────────────────────────────────────────────────

func handleLookup(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	var body struct {
		VID any `json:"vid"`
		SID any `json:"sid"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		sendError(w, 400, "invalid JSON: "+err.Error())
		return
	}

	vid := anyToStr(body.VID)
	sid := anyToStr(body.SID)
	if vid == "" || sid == "" {
		sendError(w, 400, "vid and sid are required")
		return
	}

	raw, err := jpdbAPI(r.Context(), "/lookup-vocabulary", map[string]any{
		"list":   [][]any{{vid, sid}},
		"fields": []string{"card_state"},
	})
	if err != nil {
		sendError(w, 500, err.Error())
		return
	}

	var resp struct {
		VocabularyInfo [][]json.RawMessage `json:"vocabulary_info"`
	}
	json.Unmarshal(raw, &resp)

	state := json.RawMessage(`["not-in-deck"]`)
	if len(resp.VocabularyInfo) > 0 && len(resp.VocabularyInfo[0]) > 0 {
		state = resp.VocabularyInfo[0][0]
	}

	result, _ := json.Marshal(map[string]any{"state": state})
	sendRaw(w, 200, result)
}

// ─── HTTP helpers ─────────────────────────────────────────────────────────────

func sendJSON(w http.ResponseWriter, status int, v any) {
	data, _ := json.Marshal(v)
	sendRaw(w, status, data)
}

func sendRaw(w http.ResponseWriter, status int, data []byte) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(status)
	w.Write(data)
}

func sendError(w http.ResponseWriter, status int, msg string) {
	sendJSON(w, status, map[string]string{"error": msg})
}

func anyToStr(v any) string {
	if v == nil {
		return ""
	}
	switch val := v.(type) {
	case string:
		return val
	case float64:
		return strconv.FormatInt(int64(val), 10)
	case int:
		return strconv.Itoa(val)
	}
	return fmt.Sprintf("%v", v)
}

func anyToInt64(v any) (int64, bool) {
	switch val := v.(type) {
	case float64:
		return int64(val), true
	case int:
		return int64(val), true
	case int64:
		return val, true
	case string:
		if n, err := strconv.ParseInt(val, 10, 64); err == nil {
			return n, true
		}
	}
	return 0, false
}

func truncate(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n])
}

// ─── Config watcher ───────────────────────────────────────────────────────────

func watchConfig(path string) {
	var lastMod time.Time
	for {
		time.Sleep(2 * time.Second)
		fi, err := os.Stat(path)
		if err != nil {
			continue
		}
		if !lastMod.IsZero() && fi.ModTime().After(lastMod) {
			if cfg, err := loadConfig(path); err == nil {
				currentConfig.Store(cfg)
				parseCache.Clear()
				logger.setDebug(cfg.Debug, filepath.Join(filepath.Dir(path), "debug-server.log"))
				logger.Log("Config hot-reloaded (debug=%v)", cfg.Debug)
			} else {
				logger.Log("Config reload failed: %v", err)
			}
		}
		lastMod = fi.ModTime()
	}
}

// ─── Middleware ───────────────────────────────────────────────────────────────

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == "OPTIONS" {
			w.WriteHeader(204)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func logMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		logger.Log("%s %s  %v", r.Method, r.URL.Path, time.Since(start).Round(time.Millisecond))
	})
}

// ─── Word Audio Proxy ─────────────────────────────────────────────────────────

func handleWordAudio(w http.ResponseWriter, r *http.Request) {
	vid := r.URL.Query().Get("vid")
	spelling := r.URL.Query().Get("spelling")
	reading := r.URL.Query().Get("reading")

	if vid == "" {
		http.Error(w, "missing vid", http.StatusBadRequest)
		return
	}

	// Check audio cache
	audioCacheMu.RLock()
	if cached, ok := audioCache[vid]; ok {
		audioCacheMu.RUnlock()
		w.Header().Set("Content-Type", cached.contentType)
		w.Header().Set("Cache-Control", "public, max-age=31536000")
		w.Write(cached.data)
		return
	}
	audioCacheMu.RUnlock()

	// 1. Fetch vocabulary page to find the audio hash
	vocabUrl := fmt.Sprintf("https://jpdb.io/vocabulary/%s/%s/%s", vid, spelling, reading)
	if spelling == "" {
		vocabUrl = fmt.Sprintf("https://jpdb.io/vocabulary/%s/a/a", vid)
	}

	req, err := http.NewRequestWithContext(r.Context(), "GET", vocabUrl, nil)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
	if cookie := getStoredCookie(); cookie != "" {
		req.Header.Set("Cookie", cookie)
	}

	res, err := jpdbClient.Do(req)
	if err != nil {
		http.Error(w, fmt.Sprintf("jpdb vocab fetch failed: %v", err), http.StatusBadGateway)
		return
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		http.Error(w, fmt.Sprintf("vocab page returned %d", res.StatusCode), res.StatusCode)
		return
	}

	body, err := io.ReadAll(io.LimitReader(res.Body, 2<<20)) // 2 MB limit
	if err != nil {
		http.Error(w, "failed to read HTML", http.StatusInternalServerError)
		return
	}

	// 2. Extract data-audio hash
	matches := dataAudioRE.FindAllStringSubmatch(string(body), -1)
	if len(matches) == 0 {
		http.Error(w, "no audio hash found", http.StatusNotFound)
		return
	}
	hash := matches[0][1]

	// 3. Fetch the actual encrypted audio
	audioUrl := "https://jpdb.io/static/v/" + hash
	req2, err := http.NewRequestWithContext(r.Context(), "GET", audioUrl, nil)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	req2.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
	req2.Header.Set("X-Access", "please don't steal these files")

	res2, err := jpdbClient.Do(req2)
	if err != nil {
		http.Error(w, fmt.Sprintf("audio fetch failed: %v", err), http.StatusBadGateway)
		return
	}
	defer res2.Body.Close()

	if res2.StatusCode != http.StatusOK {
		http.Error(w, fmt.Sprintf("audio returned %d", res2.StatusCode), res2.StatusCode)
		return
	}

	// 4. Decrypt XOR'd OGG header (first 4 bytes) and stream
	audioBytes, err := io.ReadAll(io.LimitReader(res2.Body, 10<<20)) // 10 MB limit
	if err != nil {
		http.Error(w, "failed to read audio", http.StatusInternalServerError)
		return
	}

	if len(audioBytes) > 4 {
		audioBytes[0] ^= 0x06
		audioBytes[1] ^= 0x23
		audioBytes[2] ^= 0x54
		audioBytes[3] ^= 0x0f
	}

	// Cache the decoded audio
	if len(audioCache) < 50 {
		audioCacheMu.Lock()
		audioCache[vid] = &audioCacheEntry{data: audioBytes, contentType: "audio/ogg"}
		audioCacheMu.Unlock()
	}

	w.Header().Set("Content-Type", "audio/ogg")
	w.Header().Set("Cache-Control", "public, max-age=31536000") // 1 year
	w.Write(audioBytes)
}

// ─── main ─────────────────────────────────────────────────────────────────────

func main() {
	// Use os.Executable() — reliable even when invoked via symlink or PATH
	exe, err := os.Executable()
	if err != nil {
		log.Fatalf("Cannot resolve executable path: %v", err)
	}
	execDir := filepath.Dir(exe)
	if strings.Contains(execDir, "go-build") || strings.Contains(execDir, "Temp") || strings.Contains(execDir, "tmp") {
		execDir, _ = os.Getwd()
	}

	configPath := filepath.Join(execDir, "config.json")
	logPath := filepath.Join(execDir, "debug-server.log")

	// Load config first so we know whether debug logging is enabled
	cfg, err := loadConfig(configPath)
	if err != nil {
		log.Fatalf("Config error: %v", err)
	}
	currentConfig.Store(cfg)

	logger = newAsyncLogger(logPath, cfg.Debug)
	logger.Log("=== jpdb-server (Go) starting ===")

	if cfg.APIToken == "" || cfg.APIToken == "YOUR_JPDB_API_TOKEN_HERE" {
		logger.Log("WARNING: apiToken not set in config.json — API calls will fail!")
	}
	logger.Log("miningDeckId=%s  forqOnMine=%v  port=%d  cookiePath=%s",
		cfg.MiningDeckID, cfg.ForqOnMine, cfg.ServerPort, cfg.CookiePath)

	go watchConfig(configPath)
	loadCookieFile()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /status", func(w http.ResponseWriter, r *http.Request) {
		sendJSON(w, 200, map[string]any{"ok": true, "version": "2.0.0-go"})
	})
	mux.HandleFunc("GET /config", func(w http.ResponseWriter, r *http.Request) {
		c := getConfig()
		tok := "not set"
		if c.APIToken != "" {
			tok = "***configured***"
		}
		sendJSON(w, 200, map[string]any{
			"apiToken":     tok,
			"miningDeckId": c.MiningDeckID,
			"serverPort":   c.ServerPort,
			"forqOnMine":   c.ForqOnMine,
		})
	})
	mux.HandleFunc("POST /parse", handleParse)
	mux.HandleFunc("POST /review", handleReview)
	mux.HandleFunc("POST /set-flag", handleSetFlag)
	mux.HandleFunc("POST /mine", handleMine)
	mux.HandleFunc("POST /lookup", handleLookup)
	mux.HandleFunc("POST /register", handleRegister)
	mux.HandleFunc("POST /unregister", handleUnregister)
	mux.HandleFunc("GET /word-audio", handleWordAudio)

	handler := logMiddleware(corsMiddleware(mux))

	addr := fmt.Sprintf("127.0.0.1:%d", cfg.ServerPort)
	srv := &http.Server{
		Addr:         addr,
		Handler:      handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown on Ctrl+C / SIGTERM / last MPV closes
	go func() {
		quit := make(chan os.Signal, 1)
		signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
		select {
		case <-quit:
			logger.Log("Signal received — shutting down gracefully...")
		case <-shutdownCh:
			logger.Log("All MPV instances closed — shutting down gracefully...")
		}
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		srv.Shutdown(ctx)
	}()

	logger.Log("Listening at http://%s", addr)
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatalf("Server error: %v", err)
	}
	logger.Log("Server stopped.")
	logger.Close()
}
