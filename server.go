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
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
)

// ─── Config ───────────────────────────────────────────────────────────────────

type Config struct {
	APIToken     string `json:"apiToken"`
	MiningDeckID string `json:"miningDeckId"`
	ServerPort   int    `json:"serverPort"`
	ForqOnMine   bool   `json:"forqOnMine"`
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

// ─── Async buffered logger ────────────────────────────────────────────────────
// Log calls never block request handlers — writes go to a buffered channel
// and a single background goroutine flushes them to disk every 500ms.

type AsyncLogger struct {
	ch  chan string
	f   *os.File
	buf *bufio.Writer
}

func newAsyncLogger(path string) *AsyncLogger {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil {
		log.Fatalf("Cannot open log file: %v", err)
	}
	al := &AsyncLogger{
		ch:  make(chan string, 4096),
		f:   f,
		buf: bufio.NewWriterSize(f, 64*1024),
	}
	go al.drain()
	return al
}

func (al *AsyncLogger) drain() {
	ticker := time.NewTicker(500 * time.Millisecond)
	for {
		select {
		case line := <-al.ch:
			al.buf.WriteString(line)
		case <-ticker.C:
			al.buf.Flush()
		}
	}
}

func (al *AsyncLogger) Log(format string, args ...any) {
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
	c.mu.RLock()
	e, ok := c.items[key]
	c.mu.RUnlock()
	if !ok {
		return nil, false
	}
	c.mu.Lock()
	c.remove(e)
	c.pushFront(e)
	c.mu.Unlock()
	return e.val, true
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

	respData, err := io.ReadAll(resp.Body)
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

	bodyBytes, err := io.ReadAll(resp.Body)
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
	var body struct {
		Text string `json:"text"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Text == "" {
		sendError(w, 400, "text is required")
		return
	}

	if cached, ok := parseCache.Get(body.Text); ok {
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

	result, _ := json.Marshal(map[string]any{"tokens": tokens, "cards": cards})
	parseCache.Set(body.Text, result)
	logger.Log("PARSE ok: %d tokens, %d cards", len(tokens), len(cards))
	sendRaw(w, 200, result)
}

// ─── Review handler ───────────────────────────────────────────────────────────

var reviewNoRE = regexp.MustCompile(`name="r"\s+value="(\d+)"`)

var grades = map[string]string{
	"nothing": "1", "something": "2", "hard": "3",
	"good": "4", "easy": "5", "pass": "p",
	"fail": "f", "known": "k", "unknown": "n",
}

func handleReview(w http.ResponseWriter, r *http.Request) {
	var body struct {
		VID    any    `json:"vid"`
		SID    any    `json:"sid"`
		Rating string `json:"rating"`
	}
	json.NewDecoder(r.Body).Decode(&body)

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

	page, cookie, err := jpdbScrape(r.Context(), "GET",
		fmt.Sprintf("/review?c=vf%%2C%s%%2C%s", vid, sid), "", "")
	if err != nil {
		sendError(w, 500, err.Error())
		return
	}

	matches := reviewNoRE.FindStringSubmatch(page)
	if matches == nil {
		sendError(w, 500, "could not find review number — is the word in a deck?")
		return
	}

	form := fmt.Sprintf("c=vf%%2C%s%%2C%s&r=%s&g=%s", vid, sid, matches[1], grade)
	if _, _, err = jpdbScrape(r.Context(), "POST", "/review", form, cookie); err != nil {
		sendError(w, 500, err.Error())
		return
	}

	parseCache.Clear()
	sendJSON(w, 200, map[string]any{"ok": true})
}

// ─── Set-flag handler ─────────────────────────────────────────────────────────

func handleSetFlag(w http.ResponseWriter, r *http.Request) {
	var body struct {
		VID   any    `json:"vid"`
		SID   any    `json:"sid"`
		Flag  string `json:"flag"`
		State *bool  `json:"state"` // *bool distinguishes false from missing
	}
	json.NewDecoder(r.Body).Decode(&body)

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
		_, _, err = jpdbScrape(r.Context(), "POST", ep,
			fmt.Sprintf("v=%s&s=%s&origin=/", vid, sid), "")
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
		_, err = jpdbAPI(r.Context(), ep, map[string]any{
			"id":         deckID,
			"vocabulary": [][]any{{vid, sid}},
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
	var body struct {
		VID         any    `json:"vid"`
		SID         any    `json:"sid"`
		Sentence    string `json:"sentence"`
		Translation string `json:"translation"`
		Forq        *bool  `json:"forq"` // *bool distinguishes false from missing
	}
	json.NewDecoder(r.Body).Decode(&body)

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

	if _, err := jpdbAPI(r.Context(), "/deck/add-vocabulary", map[string]any{
		"id":         cfg.MiningDeckID,
		"vocabulary": [][]any{{vid, sid}},
	}); err != nil {
		sendError(w, 500, err.Error())
		return
	}

	if body.Sentence != "" {
		sb := map[string]any{"vid": vid, "sid": sid, "sentence": body.Sentence}
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
	var body struct {
		VID any `json:"vid"`
		SID any `json:"sid"`
	}
	json.NewDecoder(r.Body).Decode(&body)

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
				logger.Log("Config hot-reloaded.")
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

	logger = newAsyncLogger(logPath)
	logger.Log("=== jpdb-server (Go) starting ===")

	cfg, err := loadConfig(configPath)
	if err != nil {
		log.Fatalf("Config error: %v", err)
	}
	currentConfig.Store(cfg)

	if cfg.APIToken == "" || cfg.APIToken == "YOUR_JPDB_API_TOKEN_HERE" {
		logger.Log("WARNING: apiToken not set in config.json — API calls will fail!")
	}
	logger.Log("miningDeckId=%s  forqOnMine=%v  port=%d",
		cfg.MiningDeckID, cfg.ForqOnMine, cfg.ServerPort)

	go watchConfig(configPath)

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

	handler := logMiddleware(corsMiddleware(mux))

	addr := fmt.Sprintf("127.0.0.1:%d", cfg.ServerPort)
	srv := &http.Server{
		Addr:         addr,
		Handler:      handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown on Ctrl+C / SIGTERM
	go func() {
		quit := make(chan os.Signal, 1)
		signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
		<-quit
		logger.Log("Shutting down gracefully...")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		srv.Shutdown(ctx)
	}()

	logger.Log("Listening at http://%s", addr)
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatalf("Server error: %v", err)
	}
	logger.Log("Server stopped.")
}
