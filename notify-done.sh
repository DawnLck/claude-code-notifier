#!/usr/bin/env bash
# notify-done.sh — Claude Code "Stop" hook
#
# Sends a macOS native notification when Claude finishes a task.
# • Extracts the session's first user message as the task title.
# • Clicking the notification activates the originating terminal/editor.
# • Supports English and Chinese (auto-detected from $LANG / $LC_ALL).
#
# Requirements: macOS, terminal-notifier (brew install terminal-notifier)
# Install:      See README.md or run install.sh

set -euo pipefail

# ─── 1. Read hook input (session_id lives here) ───────────────────────────────

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)

# ─── 2. Extract task name from transcript ─────────────────────────────────────

TASK_NAME=""
if [[ -n "$SESSION_ID" ]]; then
  TRANSCRIPT=$(find ~/.claude/projects -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)
  if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
    RAW=$(jq -r 'select(.type == "user") | .message.content |
                 if type == "array" then .[0].text // ""
                 else . // ""
                 end' "$TRANSCRIPT" 2>/dev/null \
          | grep -v '^$' | tail -1 || true)
    # Collapse whitespace and strip basic markdown formatting
    CLEANED=$(printf '%s' "$RAW" \
      | tr '\n\r\t' ' ' \
      | sed 's/[[:space:]]\+/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//' \
      | sed "s/\`\`\`[^\`]*\`\`\`//g; s/\`[^\`]*\`//g" \
      | sed 's/\*\*\([^*]*\)\*\*/\1/g; s/\*//g; s/^#\+[[:space:]]*//')
    # Extract first complete sentence; fall back to 80-char truncation
    SENTENCE=$(printf '%s' "$CLEANED" | sed 's/\([.?!。？！]\).*/\1/')
    if [[ "$SENTENCE" != "$CLEANED" && ${#SENTENCE} -ge 5 ]]; then
      TASK_NAME=$(printf '%s' "$SENTENCE" | cut -c1-80)
    else
      TASK_NAME=$(printf '%s' "$CLEANED" | cut -c1-80)
    fi
  fi
fi

# ─── 3. Detect which terminal/editor opened this session ──────────────────────

detect_bundle_id() {
  # Method 1: $TERM_PROGRAM (set by virtually every terminal/editor)
  case "${TERM_PROGRAM:-}" in
    Apple_Terminal)  printf 'com.apple.Terminal';            return ;;
    iTerm.app)       printf 'com.googlecode.iterm2';         return ;;
    WarpTerminal)    printf 'dev.warp.Warp-Stable';          return ;;
    vscode)
      # VS Code and Cursor both set TERM_PROGRAM=vscode — walk the tree
      local pid=$$
      for _ in $(seq 1 10); do
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        [[ -z "$pid" || "$pid" == 0 || "$pid" == 1 ]] && break
        local name
        name=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')
        case "$name" in
          *Cursor*) printf 'com.todesktop.230313mzl4w4u92'; return ;;
          *Code*)   printf 'com.microsoft.VSCode';          return ;;
        esac
      done
      printf 'com.microsoft.VSCode'
      return ;;
  esac

  # Method 2: Walk up the process tree (catches Alacritty, Hyper, Ghostty…)
  local pid=$$
  for _ in $(seq 1 10); do
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [[ -z "$pid" || "$pid" == 0 || "$pid" == 1 ]] && break
    local name
    name=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')
    case "$name" in
      *Terminal)   printf 'com.apple.Terminal';            return ;;
      *iTerm*)     printf 'com.googlecode.iterm2';         return ;;
      *Warp*)      printf 'dev.warp.Warp-Stable';          return ;;
      *Cursor*)    printf 'com.todesktop.230313mzl4w4u92'; return ;;
      *Code*)      printf 'com.microsoft.VSCode';          return ;;
      *Hyper*)     printf 'co.zeit.hyper';                 return ;;
      *Alacritty*) printf 'org.alacritty';                 return ;;
      *kitty*)     printf 'net.kovidgoyal.kitty';          return ;;
      *ghostty*)   printf 'com.mitchellh.ghostty';         return ;;
    esac
  done

  # Method 3: Dynamically resolve bundle ID for running apps (last resort)
  for app_name in "Warp" "iTerm" "Terminal"; do
    local bid
    bid=$(osascript -e "id of app \"$app_name\"" 2>/dev/null) || continue
    pgrep -f "$app_name" &>/dev/null && { printf '%s' "$bid"; return; }
  done

  printf ''  # unknown
}

BUNDLE_ID=$(detect_bundle_id)

case "$BUNDLE_ID" in
  com.apple.Terminal)            APP_NAME="Terminal"   ;;
  com.googlecode.iterm2)         APP_NAME="iTerm2"     ;;
  dev.warp.Warp-Stable)          APP_NAME="Warp"       ;;
  com.microsoft.VSCode)          APP_NAME="VS Code"    ;;
  com.todesktop.230313mzl4w4u92) APP_NAME="Cursor"     ;;
  co.zeit.hyper)                 APP_NAME="Hyper"      ;;
  org.alacritty)                 APP_NAME="Alacritty"  ;;
  net.kovidgoyal.kitty)          APP_NAME="kitty"      ;;
  com.mitchellh.ghostty)         APP_NAME="Ghostty"    ;;
  *)                             APP_NAME="Terminal"   ;;
esac

# ─── 4. Build notification strings ───────────────────────────────────────────

# Language: NOTIFY_DONE_LANG env var overrides auto-detection (set "zh" or "en")
# Configure in ~/.claude/settings.json under "env": { "NOTIFY_DONE_LANG": "zh" }
_lang_src="${NOTIFY_DONE_LANG:-}"
if [[ -z "$_lang_src" ]]; then
  [[ "${LANG:-}${LC_ALL:-}" == *zh* ]] && _lang_src="zh" || _lang_src="en"
fi

if [[ "$_lang_src" == "zh" ]]; then
  TITLE="✅ Claude Code 已完成"
  MSG="${TASK_NAME:-任务已完成}"
  SUB="点击返回 $APP_NAME"
else
  TITLE="✅ Claude Code — Done"
  MSG="${TASK_NAME:-Task completed}"
  SUB="Click to return to $APP_NAME"
fi
unset _lang_src

# ─── 5. Send notification ─────────────────────────────────────────────────────

NOTIFIER="$(command -v terminal-notifier 2>/dev/null || true)"

if [[ -n "$NOTIFIER" ]]; then
  ARGS=(-title "$TITLE" -message "$MSG" -subtitle "$SUB" -sound "Glass")
  [[ -n "$BUNDLE_ID" ]] && ARGS+=(-activate "$BUNDLE_ID")
  "$NOTIFIER" "${ARGS[@]}"
else
  # Fallback: basic osascript (no click-to-focus, no app detection)
  osascript -e "display notification \"$MSG\" with title \"$TITLE\" subtitle \"$SUB\" sound name \"Glass\""
fi
