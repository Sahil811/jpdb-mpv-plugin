# JPDB MPV Plugin

Replicates [jpdb-breader](https://github.com/hmry/jpdb-breader) Chrome extension functionality inside mpv — color-coded Japanese subtitles, interactive hover popup, review buttons, and sentence mining — **all within mpv, no browser required**.

## Features

- 🎨 **Color-coded subtitles** — words colored by jpdb state (known/new/due/failed/etc.)
- 💬 **Hover popup inside mpv** — click any word to see its dictionary entry
- ✅ **Review buttons** — Nothing / Something / Hard / Good / Easy (clickable in popup)
- ⛏️ **Mine buttons** — Add to deck, Blacklist, Never Forget (clickable in popup)
- ⌨️ **Keyboard shortcuts** — for all actions without using the mouse

## Color Coding

| State | Color |
|---|---|
| Known / Never Forget | 🟢 Green |
| Learning | 🟩 Teal |
| New | 🔵 Blue |
| Not In Deck | 🔵 Blue (50%) |
| Due | 🟠 Orange |
| Failed | 🔴 Red |
| Locked / Suspended / Blacklisted | ⚫ Gray |

## Requirements

- [mpv](https://mpv.io/) (any recent version)
- [Node.js](https://nodejs.org/) (v16 or later)
- A [jpdb.io](https://jpdb.io) account with an API token
- `curl` available in your PATH (comes with Windows 10+, macOS, Linux)

## Setup

### 1. Get your jpdb API token

Go to [jpdb.io/settings](https://jpdb.io/settings) → scroll down to **API** → copy your token.

### 2. Configure the plugin

Edit `config.json`:

```json
{
  "apiToken": "PASTE_YOUR_TOKEN_HERE",
  "miningDeckId": 12345,
  "forqOnMine": true,
  "contextWidth": 1,
  "serverPort": 9726
}
```

To find your `miningDeckId`: go to a deck on jpdb.io and look at the URL — the number after `/deck/` is the ID.

### 3. Install the Lua script

Copy `jpdb.lua` to your mpv scripts directory:

| OS | Path |
|---|---|
| Windows | `%APPDATA%\mpv\scripts\jpdb.lua` |
| macOS/Linux | `~/.config/mpv/scripts/jpdb.lua` |

### 4. Start the server

In the plugin directory, run:

```bash
node server.js
```

Keep this terminal open while watching with mpv. For auto-start, see the tips below.

### 5. Open a video in mpv

Japanese subtitles will automatically be color-coded!

## Usage

### Mouse
| Action | Result |
|---|---|
| **Click** a colored word | Opens popup with full dictionary entry |
| **Click** review button in popup | Submits review to jpdb |
| **Click** Add button | Mines word to your deck |
| **Click** outside popup | Closes popup |
| **Right-click** | Closes popup |

### Keyboard (works on hovered or popup word)
| Key | Action |
|---|---|
| `Shift` | Toggle popup for hovered word |
| `1` | Review: Nothing |
| `2` | Review: Something |
| `3` | Review: Hard |
| `4` | Review: Good |
| `5` | Review: Easy |
| `a` | Add hovered word to deck |
| `b` | Toggle Blacklist |
| `n` | Toggle Never Forget |
| `ESC` | Close popup |

## Tips

### Auto-start server with mpv

Add to `%APPDATA%\mpv\scripts\jpdb-autostart.lua`:

```lua
local utils = require('mp.utils')
mp.register_event('file-loaded', function()
    mp.command_native_async({
        name = 'subprocess',
        args = {'cmd', '/c', 'start', '/min', 'node', 'D:\\scripts\\jpdb-mpv-plugin\\server.js'},
        playback_only = false,
    }, function() end)
end)
```

### Review requires jpdb.io login

Review actions scrape jpdb.io (the API has no direct review endpoint). Make sure you are logged into jpdb.io in your default browser session. The server uses the session cookie from your browser automatically.

### Mining deck not configured

If `miningDeckId` is `null`, the **Add** button will fail. Set it to your deck's numeric ID.

## Troubleshooting

| Problem | Solution |
|---|---|
| Subtitles not colored | Make sure `server.js` is running; check terminal for errors |
| "API token not configured" | Edit `config.json` and set `apiToken` |
| "Not logged in to jpdb.io" | Log into jpdb.io in your browser (for review) |
| Popup doesn't appear | Try clicking directly on a colored word |
| Colors wrong/missing | Check `node server.js` console for parse errors |
