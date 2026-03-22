# claude-code-done-notifier

A macOS notification hook for [Claude Code](https://claude.ai/code) that fires whenever Claude finishes a task.

**Features:**
- Shows the task name (extracted from the first message of the session) in the notification bubble
- Clicking the notification activates the exact terminal or editor window where Claude is running
- Supports **English** and **Chinese** (auto-detected from your system locale)
- Plays the macOS **Glass** sound on completion
- Works with Terminal, iTerm2, Warp, VS Code, Cursor, Hyper, Alacritty, kitty, Ghostty

---

## Demo

```
╔══════════════════════════════════════╗
║  ✅ Claude Code — Done               ║
║  Pls hide the API Settings, its no…  ║
║  Click to return to Warp             ║
╚══════════════════════════════════════╝
```
*(Clicking the bubble brings your Warp window to the foreground.)*

---

## Requirements

| Requirement | Notes |
|---|---|
| macOS | Notifications use native macOS APIs |
| [Claude Code](https://claude.ai/code) | The CLI tool by Anthropic |
| [Homebrew](https://brew.sh) | Used by the installer to fetch dependencies |
| `jq` | JSON parsing (`brew install jq`) — installer handles this |
| `terminal-notifier` | Click-to-focus support (`brew install terminal-notifier`) — installer handles this |

---

## Installation

### One-command install (recommended)

```bash
git clone https://github.com/YOUR_USERNAME/claude-code-done-notifier.git
cd claude-code-done-notifier
bash install.sh
```

Then **restart Claude Code** or open `/hooks` to activate.

### Manual install

1. Install dependencies:
   ```bash
   brew install jq terminal-notifier
   ```

2. Copy the hook script:
   ```bash
   mkdir -p ~/.claude/hooks
   cp notify-done.sh ~/.claude/hooks/notify-done.sh
   chmod +x ~/.claude/hooks/notify-done.sh
   ```

3. Register the hook in `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "Stop": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "bash ~/.claude/hooks/notify-done.sh",
               "async": true
             }
           ]
         }
       ]
     }
   }
   ```

4. Restart Claude Code.

---

## Uninstall

```bash
bash install.sh --uninstall
```

---

## How It Works

```
Claude finishes a task
        ↓
Stop hook fires → notify-done.sh receives JSON on stdin
        ↓
1. Extract session_id from stdin JSON
2. Find transcript: ~/.claude/projects/**/<session_id>.jsonl
3. Parse first user message → task name (truncated to 60 chars)
        ↓
4. Detect terminal app:
   TERM_PROGRAM env var → process tree walk → osascript fallback
        ↓
5. Detect language from $LANG / $LC_ALL
        ↓
6. Fire notification via terminal-notifier
   -activate <bundle-id>  ← makes it clickable to open the right window
```

### Supported terminals & editors

| App | Detection method | Bundle ID |
|---|---|---|
| Terminal.app | `$TERM_PROGRAM=Apple_Terminal` | `com.apple.Terminal` |
| iTerm2 | `$TERM_PROGRAM=iTerm.app` | `com.googlecode.iterm2` |
| Warp | `$TERM_PROGRAM=WarpTerminal` | `dev.warp.Warp-Stable` |
| VS Code | `$TERM_PROGRAM=vscode` + process tree | `com.microsoft.VSCode` |
| Cursor | `$TERM_PROGRAM=vscode` + process tree | `com.todesktop.230313mzl4w4u92` |
| Hyper | process tree | `co.zeit.hyper` |
| Alacritty | process tree | `org.alacritty` |
| kitty | process tree | `net.kovidgoyal.kitty` |
| Ghostty | process tree | `com.mitchellh.ghostty` |

---

## Customization

### Change the sound

Edit `notify-done.sh` and replace `Glass` with any macOS system sound:

```
Basso  Blow  Bottle  Frog  Funk  Hero  Morse
Ping   Pop   Purr    Sosumi  Submarine  Tink
```

### Change the task name length

Edit the `cut -c1-60` at the end of the extraction pipeline in `notify-done.sh`.

### Add a new terminal

Add a new `case` entry in the `detect_bundle_id()` function. To find any app's bundle ID:
```bash
osascript -e 'id of app "YourApp"'
```

---

## Troubleshooting

**Notification doesn't appear**
- Check System Settings → Notifications → terminal-notifier is allowed
- Run manually: `echo '{}' | bash ~/.claude/hooks/notify-done.sh`

**Clicking the notification doesn't focus the right window**
- Verify `terminal-notifier` is installed: `which terminal-notifier`
- Check System Settings → Notifications → terminal-notifier has permission

**Task name is empty / generic**
- The transcript may not have been written yet at hook fire time (rare race condition)
- The hook falls back to the locale-appropriate generic string

**Hook not firing**
- Open `/hooks` in Claude Code or restart the session
- Validate settings.json: `jq empty ~/.claude/settings.json`

---

## Contributing

PRs welcome! Areas for improvement:
- Linux support (via `notify-send` / `libnotify`)
- More terminal app detection
- Last-message mode (use final user message instead of first)

---

## License

MIT
