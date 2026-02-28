# JPDB MPV Plugin

Replicates [jpdb-breader](https://github.com/hmry/jpdb-breader) Chrome extension functionality inside mpv — color-coded Japanese subtitles, interactive hover popup, review buttons, and sentence mining — **all within mpv, no browser required**.

> **Zero manual setup** — the server starts and stops automatically with mpv. Open mpv, watch, close mpv. That's it.

## Features

- 🎨 **Color-coded subtitles** — words colored by jpdb state (known / new / due / failed / etc.)
- 💬 **Hover popup** — hover any word to see its dictionary entry, reading, and part of speech
- ✅ **Review buttons** — Nothing / Something / Hard / Good / Easy (clickable in popup)
- ⛏️ **Mine buttons** — Add to deck, Blacklist, Never Forget (clickable in popup)
- ⌨️ **Keyboard shortcuts** — 1–5 for review grades, A / B / N for actions
- 🚀 **Auto server lifecycle** — server starts when the first mpv opens, stops when the last mpv closes. Multiple mpv windows share one server automatically.

## Color Coding

| State | Color |
|---|---|
| Known / Never Forget | 🟢 Green |
| Learning | 🟩 Teal |
| New / Not in Deck | 🟠 Orange |
| Due | 🔵 Blue |
| Failed | 🔴 Red |
| Locked / Suspended / Blacklisted | ⚫ Gray |

## Requirements

- [mpv](https://mpv.io/) (any recent version)
- [Go](https://go.dev/) 1.22+ (only needed to build `jpdb-server.exe`)
- A [jpdb.io](https://jpdb.io) account with an API token
- `curl` in your PATH (built-in on Windows 10+, macOS, Linux)

## Installation

### 1. Get your jpdb API token

Go to [jpdb.io/settings](https://jpdb.io/settings) → scroll to **API** → copy your token.

### 2. Place the plugin folder

Copy the entire `jpdb-mpv-plugin/` folder into your mpv scripts directory:

| OS | Scripts directory |
|---|---|
| Windows | `%APPDATA%\mpv\scripts\` or `C:\Program Files\mpv\mpv\scripts\` |


The result should be:
```
scripts/
  └── jpdb-mpv-plugin/
       ├── main.lua
       ├── jpdb-server.exe   ← build this (step 3)
       ├── config.json       ← create this (step 4)
       └── ...
```

### 3. Build the server

In the `jpdb-mpv-plugin/` folder, run:

```bash
go build -o jpdb-server.exe .
```

> On macOS/Linux: `go build -o jpdb-server .`  
> Cross-compile for Windows from Linux: `GOOS=windows go build -o jpdb-server.exe .`

### 4. Configure

Copy `config.example.json` → `config.json` and fill in your details:

```json
{
  "apiToken": "YOUR_JPDB_API_TOKEN_HERE",
  "miningDeckId": 12345,
  "forqOnMine": true,
  "contextWidth": 1,
  "serverPort": 9726,
  "cookiePath": "./jpdb-cookie.txt"
}
```

**`miningDeckId`** — go to your deck on jpdb.io; the number in the URL (`/deck/12345`) is the ID. Set to `null` to disable mining.

**`cookiePath`** — path to your jpdb.io session cookie file (for review/mining actions that use the web scraper). See [Review Setup](#review-setup) below.

### 5. Done — just open mpv

The server starts automatically when mpv launches and stops when you close the last mpv window. No terminal to keep open.

## Usage

### Mouse

| Action | Result |
|---|---|
| **Hover** a colored word | Opens popup with dictionary entry |
| **Click** review button | Submits review to jpdb |
| **Click** Add button | Mines word to your deck |
| **Left-click** outside popup | Closes popup, resumes playback |
| **Right-click** | Closes popup |

### Keyboard

| Key | Action |
|---|---|
| `1` | Review: Nothing |
| `2` | Review: Something |
| `3` | Review: Hard |
| `4` | Review: Good |
| `5` | Review: Easy |
| `a` | Add word to deck |
| `b` | Toggle Blacklist |
| `n` | Toggle Never Forget |
| `ESC` | Close popup |

## Review Setup

Review and mining actions that use the web scraper (review, forq, blacklist) require a jpdb.io session cookie.

1. Log into [jpdb.io](https://jpdb.io) in your browser
2. Export your cookies for `jpdb.io` to `jpdb-cookie.txt` in the plugin folder (Netscape format — use a browser extension like [Cookie-Editor](https://cookie-editor.com/))
3. The server will keep the cookie up-to-date automatically

## Troubleshooting

| Problem | Solution |
|---|---|
| No colored subtitles | Check `debug-server.log` in the plugin folder for errors |
| "API token not configured" | Set `apiToken` in `config.json` |
| "Not logged in to jpdb.io" | Export your jpdb.io cookies to `jpdb-cookie.txt` |
| Server doesn't start | Make sure `jpdb-server.exe` was built and is in the plugin folder |
| Wrong port | Change `serverPort` in `config.json` and `SERVER_URL` in `main.lua` to match |

## Project Structure

```
jpdb-mpv-plugin/
  ├── main.lua              # MPV Lua plugin (entry point)
  ├── server.go             # Go HTTP server source
  ├── go.mod                # Go module file
  ├── config.example.json   # Config template (copy → config.json)
  └── README.md
```

Files created at runtime (gitignored):
```
  ├── jpdb-server.exe       # Built from server.go
  ├── config.json           # Your private config (never commit!)
  ├── jpdb-cookie.txt       # Your session cookie
  ├── jpdb-debug.log        # Lua plugin log
  └── debug-server.log      # Go server log
```
