# JPDB MPV Plugin

Replicates [jpdb-breader](https://github.com/hmry/jpdb-breader) Chrome extension functionality inside mpv — color-coded Japanese subtitles, interactive hover popup, review buttons, and sentence mining — **all within mpv, no browser required**.

> **Zero manual setup** — the server starts and stops automatically with mpv. Open mpv, watch, close mpv. That's it.

## Features

- 🎨 **Color-coded subtitles** — words colored by jpdb state (known / new / due / failed / etc.)
- 💬 **Hover popup** — hover any word to see its dictionary entry, reading, and part of speech
- ⭐ **Never Forget button** — mark important words to never forget (clickable in popup)
- ⌨️ **Keyboard shortcuts** — N for Never Forget, ESC to close
- 🚀 **Auto server lifecycle** — server starts when the first mpv opens, stops when the last mpv closes. Multiple mpv windows share one server automatically.
- 🎯 **Optimized UI** — compact, clean design with maximum readability and efficient space usage

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
  "miningDeckId": null,
  "forqOnMine": true,
  "contextWidth": 1,
  "serverPort": 9726,
  "cookiePath": "./jpdb-cookie.txt",
  "debug": false
}
```

**`apiToken`** — your jpdb.io API token (required for parsing subtitles)

**`miningDeckId`** — optional, set to `null` (mining features are disabled in this version)

**`cookiePath`** — path to your jpdb.io session cookie file (for Never Forget actions). See [Cookie Setup](#cookie-setup) below.

**`debug`** — set to `true` to enable verbose logging in `debug-server.log`

### 5. Done — just open mpv

The server starts automatically when mpv launches and stops when you close the last mpv window. No terminal to keep open.

## Usage

### Mouse

| Action | Result |
|---|---|
| **Hover** a colored word | Opens popup with dictionary entry |
| **Click** Never Forget button | Toggles Never Forget status for the word |
| **Left-click** outside popup | Closes popup, resumes playback |
| **Right-click** | Closes popup |

### Keyboard

| Key | Action |
|---|---|
| `n` | Toggle Never Forget |
| `ESC` | Close popup |
| `Shift` | Show/hide popup for hovered word |

## Cookie Setup

The Never Forget feature requires a jpdb.io session cookie to work.

1. Log into [jpdb.io](https://jpdb.io) in your browser
2. Export your cookies for `jpdb.io` to `jpdb-cookie.txt` in the plugin folder (Netscape format — use a browser extension like [Cookie-Editor](https://cookie-editor.com/))
3. The server will keep the cookie up-to-date automatically

## Configuration

You can customize the popup appearance by editing `jpdb-config.lua`:

- Font sizes for kanji, readings, and meanings
- Colors for different card states
- Popup dimensions and spacing
- Button sizes and gaps

The default configuration is optimized for readability and compact space usage.

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
  ├── jpdb-config.lua       # UI configuration (colors, sizes, spacing)
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
  ├── jpdb-debug.log        # Lua plugin log (when DEBUG_LOG=true)
  └── debug-server.log      # Go server log (when debug=true)
```
