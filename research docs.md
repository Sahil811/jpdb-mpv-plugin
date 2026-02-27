# JPDB mpv Plugin and `mpv-jpdb.exe` – Technical Details

## Overview of the architecture

The jpdb mpv integration is built on two main pieces:

- An mpv script (typically Lua) that runs **inside mpv** and reacts to subtitle events, draws overlays, and captures audio/screenshots.
- A small **external helper program** on Windows (`mpv-jpdb.exe`) that handles jpdb log‑in, API calls, and sometimes direct communication with mpv through JSON IPC or subprocess pipes.[1][2][3]

These two parts talk to each other over a local channel (named pipe, TCP localhost, or mpv’s `subprocess` interface), and the helper in turn talks to `https://jpdb.io` using https requests and your account session.[4][3][5]

## How mpv exposes data to external programs

mpv provides two mechanisms that integrations like `mpv-jpdb.exe` can use:[6][3][4]

- **JSON IPC** via `--input-ipc-server`:
  - mpv opens a Unix socket or named pipe (on Windows often `\\.\pipe\mpv-something`).
  - Any external process can connect and send JSON objects of the form `{ "command": ["command-name", arg1, ...] }` and receive JSON responses.
  - It can also subscribe to events (for example subtitle changes, property changes) via this IPC channel.
- **Scripting inside mpv**:
  - Lua (or JS) scripts can observe properties like `sub-text`, `sub-start`, `time-pos` and call `mp.command_native` to spawn subprocesses or communicate with sockets.
  - They can render text overlays with ASS and respond to key/mouse events.

The jpdb plugin uses these facilities the same way tools like mpvacious or mpv_websocket do: either by talking to a helper over JSON IPC or by having the Lua script call the helper exe as a subprocess with structured arguments.[7][8][9]

## Data flow from mpv to `mpv-jpdb.exe`

When a subtitle line is shown, the following happens conceptually:[3][8][1]

1. **mpv detects a new subtitle line**
   - A Lua script inside mpv subscribes to subtitle change events or polls properties like `sub-text` and `sub-start`.
   - It now has: the subtitle string, timing (`start`, `end`), current playback position, filename/episode.
2. **Script sends a message to the helper**
   - If the plugin uses JSON IPC, the helper connects to mpv’s IPC pipe and can ask for the current subtitle text, or mpv can be configured to push these events.
   - Alternatively, the Lua script calls `mp.command_native_async({"run", "mpv-jpdb.exe", ...})` and passes the subtitle text and metadata in arguments or via stdin.[10][6][4]
3. **Helper processes and forwards to jpdb**
   - `mpv-jpdb.exe` parses the subtitle text, sends it along with metadata (show, episode, timestamp) to jpdb’s backend API endpoints that were added for sentence mining.[2][11]
   - jpdb responds with tokenization plus knowledge information (known/unknown) for each token.
4. **Highlight data goes back to mpv**
   - The helper returns a structure describing each word: surface form, position in the original string, length, and its jpdb state (known, unknown, learning, etc.).[11]
   - The Lua script receives this and redraws the subtitle overlay so that known words are green and unknown words are blue.[1]

## Technical details of word lookup and highlighting

The sentence‑mining update added internal fields like `position_*` and `length_*` to jpdb’s card/token schema, which the mpv plugin uses for precise mapping between text in the subtitle and jpdb’s dictionary tokens.[11]

On each subtitle change:

- The helper or jpdb backend **tokenizes** the Japanese subtitle text into dictionary words using jpdb’s own parser.
- For each token, jpdb looks up:
  - Dictionary entry id
  - Knowledge state in the current deck (known, new, suspended, etc.)
  - Optional pitch accent or other lexical data.
- The plugin receives a list like: `[ { index: 0, length: 2, status: "known" }, { index: 2, length: 3, status: "unknown" }, ... ]` (conceptually).
- The Lua script then splits or overlays the subtitle string according to these indices and sets ASS styles so that:
  - Known words are rendered in green.
  - Unknown words are rendered in blue.[1]

For **lookup on hover**:

- The Lua script tracks mouse coordinates over the subtitle area and maps the x‑position back to a character index, then finds which token covers that index.
- It then asks the helper (or directly jpdb via the helper) for detailed dictionary info for that token (readings, glosses, etc.).
- The script draws a small overlay box near the cursor with this information.[11][1]

## Technical details of sentence mining (card creation)

When you double‑click a word or press a mining hotkey:

1. **Collect local data**
   - The mpv script reads:
     - Current subtitle text
     - Current playback position and subtitle timing
     - File path (so the card can store media title and episode)
   - It also triggers mpv to:
     - Extract a short audio segment around the subtitle time using `ao` recording or `ffmpeg` via `run`.[12][8]
     - Capture a framegrab (screenshot) at the current frame and save it as `png` or `jpg` to a temp folder.
2. **Send a structured request to the helper**
   - The script packs sentence text, clicked token id, timings, audio path, screenshot path, and show metadata into a JSON or argument list.
   - It invokes `mpv-jpdb.exe` (subprocess) or sends this JSON to the helper over the existing IPC connection.[6][4]
3. **Helper talks to jpdb**
   - The helper authenticates using your jpdb session or an API token.
   - It calls the jpdb “set card sentence / add card with sentence” endpoints that were introduced in the sentence‑mining update.[2][11]
   - Files (audio + image) are uploaded as multipart/form‑data or similar, linked to that card.
4. **Confirmation and UI feedback**
   - After jpdb confirms creation, the helper can send a small “success” message back so the Lua script can briefly flash a “Card added” indicator in mpv.[1]

All jpdb‑specific logic (auth, API endpoints, handling of storage limits, etc.) lives in the helper and server; mpv only knows that it is sending some media and text and receiving highlight/lookup data back.[2][11][1]

## How `mpv-jpdb.exe` is started and kept running

On Windows, integrations that use JSON IPC commonly operate in one of two modes:[7][3][10]

- **Daemon‑style helper**
  - You start `mpv-jpdb.exe` once.
  - It spins up a small HTTP/JSON server on `localhost` (for example `127.0.0.1:PORT`).
  - mpv Lua scripts send HTTP requests to that port whenever a subtitle or mining event occurs.
- **Per‑call subprocess**
  - mpv calls `mpv-jpdb.exe` only when needed (e.g., when you mine a sentence) using `mp.command_native({"run", ...})`.
  - The exe performs a single API call to jpdb and exits.

The Reddit report that the jpdb mpv plugin opens “a small white window for a few seconds, then closes” strongly suggests a helper that either terminates when it cannot find mpv or when it is set up as a short‑lived helper.[13]

In either case, the important technical point is that **mpv and `mpv-jpdb.exe` are decoupled processes** communicating via JSON over sockets/pipes or via subprocess I/O, using mpv’s established IPC system.[4][3][6]

## Summary of how it works technically

- mpv exposes subtitles, timing, and playback information via internal properties and JSON IPC.
- A Lua script inside mpv listens for subtitle changes, user input (mouse/keys), and interacts with `mpv-jpdb.exe`.
- `mpv-jpdb.exe` manages jpdb authentication and calls jpdb’s sentence‑mining APIs.
- Data flows like this:

  `mpv (Lua script) ⇄ local IPC / subprocess ⇄ mpv-jpdb.exe ⇄ HTTPS ⇄ jpdb servers`

- Highlighting, lookup, and card creation are all driven by this pipeline, using jpdb’s own tokenizer and vocabulary state to decide what to color and what to store.[2][11][1]


JPDB-MPV Plugin Architecture and MPV Integration

The JPDB MPV plugin is delivered as a Windows executable (jpdb-mpv.exe) and accompanying MPV scripts. Under the hood, it leverages MPV’s scripting/IPC capabilities. MPV supports an embedded Lua interpreter and a JSON-based IPC (via --input-ipc-server) for external programs. In practice, the JPDB installer drops a Lua script into MPV’s ~/.config/mpv/scripts directory. This script is invoked on playback (e.g. via mp.register_event('file-loaded')) and can spawn the jpdb-mpv.exe process using MPV’s run or subprocess commands. For example, a Lua script might call:

mp.command({"run", "jpdb-mpv.exe", "--mpv-ipc-socket=" .. socket_path})

to launch the JPDB helper and connect it to MPV’s IPC socket. The external exe thus runs in the background alongside MPV, listening for events (subtitle changes, mouse clicks, etc.) over the IPC socket. This split architecture (Lua for UI/hooks + external binary for networking/processing) is common in MPV plugins. (For example, the open-source interSubs script similarly requires a Lua front end and a Python backend.)

Subtitle Processing and Interaction

Once activated, the plugin observes MPV’s subtitle output. The Lua side typically uses mp.observe_property("sub-text", "string", ...) or a similar hook to intercept each subtitle line. Each line is tokenized (often by simple whitespace or a Japanese tokenizer) and compared against the user’s known JPDB vocabulary. The script then re-displays the subtitle with color tags: words already learned are shown in one color (e.g. green), and new words in another (e.g. blue). These colors are usually implemented via ASS override tags or MPV’s OSD (on-screen display).

Hovering and clicking are handled via MPV input bindings. For example, the Lua script can bind mouse events (such as mbtn_left or mbtn_left_dbl for double-click) to custom functions. In this way, moving the mouse over a highlighted word triggers a “popup dictionary” overlay (using mp.osd_message or a custom overlay) showing JPDB’s definition. Likewise, double-clicking a word tells the plugin to “mine” that word: it captures the full subtitle sentence (with audio and a video screenshot) and sends it to JPDB as a new flashcard. In short, the Lua script converts MPV subtitle events into lookups and actions, while the background exe handles the data processing.

Communication with JPDB.io

For lookups and mining, the plugin communicates with the JPDB server via JPDB’s API. Each user has a unique API key (found on their JPDB settings page) which the plugin uses to authenticate. In fact, the downloaded plugin is tied to your account – the installer warns “do not share the extension – it is configured only for your account”. Under the hood, jpdb-mpv.exe makes HTTPS requests (usually JSON) to jpdb.io. These requests fetch word definitions or check “known/unknown” status for the hovered words, and they send POSTs to add new data. For example, on a double-click event the plugin sends the captured sentence text plus the attached screenshot and audio clip to JPDB’s API, effectively creating a new sentence card. (Indeed, the JPDB developer confirms that sentence audio and images can currently only be added via the MPV plugin.) All API communication is secured by the user’s key/token that was bundled by the installer.

Dependencies and Implementation Details

Internally, the plugin uses JSON and common scripting tools. The Lua script component uses MPV’s built-in Lua engine and the player’s IPC interface. The companion executable is a compiled binary (likely written in a language like Rust or Go that can easily be built for Windows/Mac/Linux). It handles HTTP(S) requests, image/audio capture, and any local data. (JPDB even provides a Rust API wrapper crate, suggesting Rust is used.) The executable may invoke system utilities: for example, it can ask MPV to take a screenshot or use ffmpeg to extract the current audio segment.

By analogy, other MPV-language plugins often require Python or similar. For instance, the interSubs MPV script requires Python (with libraries like requests, numpy, etc.) alongside Lua. While JPDB’s plugin is distributed as an .exe (so users needn’t install Python themselves), it likely bundles similar JSON parsing and HTTP libraries internally. In summary, the JPDB plugin stack involves Lua for MPV integration, JSON for data exchange, and a compiled backend (with networking libraries) to talk to JPDB.

Runtime Operation of jpdb-mpv.exe

When you run MPV after installing the plugin, the Lua script will launch or signal the jpdb-mpv.exe process. The exe then runs in the background: it remains alive during playback (sometimes marked as a “playback-only” subprocess) and listens for commands from the Lua script or MPV IPC. It may also register listeners for MPV events via the JSON API. Interaction is asynchronous – the Lua script can mp.command("run", "jpdb-mpv.exe") to fire it off, after which MPV continues playing.

During playback, the plugin does not interrupt the shell – it merely sits in the background, intercepting MPV events (like subtitle changes or mouse events) and handling API calls. When the video ends or MPV exits, the plugin shuts down or detaches. In this way, the jpdb-mpv.exe executable functions as a helper service managed by MPV (not a persistent OS service), integrating tightly with MPV’s hooks and IPC.

Sources: Official JPDB changelogs and community posts describe the MPV plugin’s features (hover definitions, color-coding, double-click mining). MPV’s documentation explains its JSON IPC and scripting model. JPDB’s own guides note that the plugin is obtained via the Labs page and is account-specific. JPDB integration details (API keys, media uploads) are confirmed in JPDB documentation and developer comments. Related MPV scripts (e.g. interSubs) illustrate the use of Lua+Python and JSON for similar tasks. All of these sources show how the jpdb-mpv.exe plugin hooks into MPV and JPDB on a technical level.



