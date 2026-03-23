#!/usr/bin/env bash
# claude-code-notify.sh — Claude Code "Stop" hook
#
# Sends a native desktop notification when Claude finishes a task.
# • Shows first sentence of Claude's last reply as the task summary.
# • Shows session duration and project name in the subtitle.
# • On macOS: clicking the notification activates the originating terminal.
# • Supports English and Chinese (auto-detected or configured via env var).
#
# Platforms: macOS, Linux (X11/Wayland), Windows (WSL2)
# Requirements:
#   macOS  — terminal-notifier (brew install terminal-notifier)
#   Linux  — notify-send (libnotify)
#   WSL2   — powershell.exe (built-in) or notify-send via WSLg
#
# Install:      See README.md or run install.sh
#
# ── Configuration (set in ~/.claude/settings.json → "env": { … }) ─────────────
#   NOTIFY_DONE_LANG            "zh" or "en"  (default: auto-detect from $LANG)
#   NOTIFY_DONE_SHOW_SUMMARY    "true"/"false" (default: "true")  — Claude's reply
#   NOTIFY_DONE_SHOW_DURATION   "true"/"false" (default: "true")  — task duration
#   NOTIFY_DONE_SHOW_PROJECT    "true"/"false" (default: "true")  — project name
#   NOTIFY_DONE_ONLY_WHEN_AWAY  "true"/"false" (default: "false") — skip notification
#                                              if the terminal is already focused
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─── 0. Platform detection ────────────────────────────────────────────────────

OS="$(uname -s)"
IS_WSL=false
[[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true

# ─── 1. Read hook input (session_id lives here) ───────────────────────────────

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)

# ─── 2. Platform-aware helpers ────────────────────────────────────────────────

# Convert ISO 8601 timestamp to epoch seconds (platform-safe)
_to_epoch() {
  local ts="${1%%.*}"  # strip fractional seconds
  case "$OS" in
    Darwin) date -j -f "%Y-%m-%dT%H:%M:%S" "$ts" "+%s" 2>/dev/null || echo 0 ;;
    *)      date -d "${ts/T/ }" "+%s" 2>/dev/null || echo 0 ;;
  esac
}

_play_sound() {
  local file="$1"
  [[ -z "$file" || ! -f "$file" ]] && return

  case "$OS" in
    Darwin) afplay "$file" & ;;
    Linux)
      if [[ "$IS_WSL" == true ]] && command -v powershell.exe &>/dev/null; then
        local win_path="$file"
        command -v wslpath &>/dev/null && win_path=$(wslpath -w "$file")
        powershell.exe -NoProfile -NonInteractive -Command "(New-Object Media.SoundPlayer '$win_path').Play()" &
      else
        if   command -v paplay  &>/dev/null; then paplay  "$file" &
        elif command -v pw-play &>/dev/null; then pw-play "$file" &
        elif command -v aplay   &>/dev/null; then aplay   "$file" &
        fi
      fi
      ;;
  esac
}

# ─── 3. Extract info from transcript ─────────────────────────────────────────

SUMMARY=""
DETAILS=""
DURATION=""
PROJECT=""

if [[ -n "$SESSION_ID" ]]; then
  # Give the FS a moment to flush the transcript (prevents stale message bug)
  sleep 0.5

  TRANSCRIPT=$(find ~/.claude/projects -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)
  if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then

    # 3a. Task duration: last user message → last assistant message
    _user_ts=$(jq -r 'select(.type == "user") | .timestamp // empty' \
               "$TRANSCRIPT" 2>/dev/null | tail -1 || true)
    _asst_ts=$(jq -r 'select(.type == "assistant") | .timestamp // empty' \
               "$TRANSCRIPT" 2>/dev/null | tail -1 || true)
    if [[ -n "$_user_ts" && -n "$_asst_ts" ]]; then
      _s=$(_to_epoch "$_user_ts")
      _e=$(_to_epoch "$_asst_ts")
      _elapsed=$(( _e - _s ))
      if   [[ $_elapsed -ge 60 ]]; then DURATION="$(( _elapsed/60 ))m $(( _elapsed%60 ))s"
      elif [[ $_elapsed -gt  0 ]]; then DURATION="${_elapsed}s"
      fi
    fi
    unset _user_ts _asst_ts _s _e _elapsed

    # 3b. Project name — decode the sanitized directory name
    _pdir=$(basename "$(dirname "$TRANSCRIPT")")
    PROJECT=$(printf '%s' "$_pdir" | sed 's/^-//' | awk -F'--+' '{print $NF}')
    unset _pdir

    # 3c. Task summary & details — Extracts both a brief summary and multi-line details
    _raw=$(jq -rs '[.[] | select(.type == "assistant") |
                   select(.message.content | arrays |
                     map(select(.type == "text")) | length > 0)] |
                   last |
                   .message.content |
                   if type == "array" then
                     map(select(.type == "text")) | .[0].text // ""
                   else . // ""
                   end' "$TRANSCRIPT" 2>/dev/null || true)

    SUMMARY=""
    DETAILS=""
    if [[ -n "$_raw" ]]; then
      # Extract summary (first sentence)
      _cleaned_for_sum=$(printf '%s' "$_raw" | tr '\n\r\t' ' ' | sed 's/[[:space:]]\+/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//' | sed "s/\`\`\`[^\`]*\`\`\`//g; s/\`[^\`]*\`//g" | sed 's/\*\*\([^*]*\)\*\*/\1/g' | sed 's/^#\+[[:space:]]*//')
      _sentence=$(printf '%s' "$_cleaned_for_sum" | sed 's/\([.?!。？！]\).*/\1/')
      if [[ "$_sentence" != "$_cleaned_for_sum" && ${#_sentence} -ge 20 ]]; then
        SUMMARY=$(printf '%s' "$_sentence" | cut -c1-100)
      else
        SUMMARY=$(printf '%s' "$_cleaned_for_sum" | cut -c1-100)
      fi
      unset _cleaned_for_sum _sentence

      # Extract details (remaining text, cleaned up)
      _remaint=$(printf '%s' "$_raw" | sed "s/^\s*//" | sed "s/^${SUMMARY//\//\\/}//" | sed "s/^\s*//" || echo "")
      DETAILS=$(printf '%s' "$_remaint" \
        | sed "s/\`\`\`[^\`]*\`\`\`//g; s/\`[^\`]*\`//g" \
        | sed 's/^[[:space:]]*[*-][[:space:]]/• /g' \
        | head -c 800)
      unset _remaint
    fi
    unset _raw
  fi
fi

# ─── 4. Detect which terminal/editor opened this session ──────────────────────

# For macOS: returns Bundle ID;  For Linux/WSL: returns terminal name string
TERMINAL_ID=""
TERMINAL_APP=""

_detect_terminal_macos() {
  # Method 1: $TERM_PROGRAM (set by virtually every terminal/editor)
  case "${TERM_PROGRAM:-}" in
    Apple_Terminal)  TERMINAL_ID='com.apple.Terminal';            TERMINAL_APP='Terminal';   return ;;
    iTerm.app)       TERMINAL_ID='com.googlecode.iterm2';         TERMINAL_APP='iTerm2';     return ;;
    WarpTerminal)    TERMINAL_ID='dev.warp.Warp-Stable';          TERMINAL_APP='Warp';       return ;;
    vscode)
      # VS Code and Cursor both set TERM_PROGRAM=vscode — walk the tree
      local pid=$$
      for _ in $(seq 1 10); do
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        [[ -z "$pid" || "$pid" == 0 || "$pid" == 1 ]] && break
        local name
        name=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')
        case "$name" in
          *Cursor*) TERMINAL_ID='com.todesktop.230313mzl4w4u92'; TERMINAL_APP='Cursor'; return ;;
          *Code*)   TERMINAL_ID='com.microsoft.VSCode';          TERMINAL_APP='VS Code'; return ;;
        esac
      done
      TERMINAL_ID='com.microsoft.VSCode'; TERMINAL_APP='VS Code'
      return ;;
  esac

  # Method 2: Walk up the process tree
  local pid=$$
  for _ in $(seq 1 10); do
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [[ -z "$pid" || "$pid" == 0 || "$pid" == 1 ]] && break
    local name
    name=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')
    case "$name" in
      *Terminal)   TERMINAL_ID='com.apple.Terminal';            TERMINAL_APP='Terminal';   return ;;
      *iTerm*)     TERMINAL_ID='com.googlecode.iterm2';         TERMINAL_APP='iTerm2';     return ;;
      *Warp*)      TERMINAL_ID='dev.warp.Warp-Stable';          TERMINAL_APP='Warp';       return ;;
      *Cursor*)    TERMINAL_ID='com.todesktop.230313mzl4w4u92'; TERMINAL_APP='Cursor';     return ;;
      *Code*)      TERMINAL_ID='com.microsoft.VSCode';          TERMINAL_APP='VS Code';    return ;;
      *Hyper*)     TERMINAL_ID='co.zeit.hyper';                 TERMINAL_APP='Hyper';      return ;;
      *Alacritty*) TERMINAL_ID='org.alacritty';                 TERMINAL_APP='Alacritty';  return ;;
      *kitty*)     TERMINAL_ID='net.kovidgoyal.kitty';          TERMINAL_APP='kitty';      return ;;
      *ghostty*)   TERMINAL_ID='com.mitchellh.ghostty';         TERMINAL_APP='Ghostty';    return ;;
    esac
  done

  # Method 3: Dynamically resolve bundle ID for running apps (last resort)
  for app_name in "Warp" "iTerm" "Terminal"; do
    local bid
    bid=$(osascript -e "id of app \"$app_name\"" 2>/dev/null) || continue
    pgrep -f "$app_name" &>/dev/null && { TERMINAL_ID="$bid"; TERMINAL_APP="$app_name"; return; }
  done

  TERMINAL_APP="Terminal"
}

_detect_terminal_linux() {
  # Method 1: $TERM_PROGRAM
  case "${TERM_PROGRAM:-}" in
    vscode)      TERMINAL_APP="VS Code";    return ;;
    iTerm.app)   TERMINAL_APP="iTerm2";     return ;;
    WarpTerminal) TERMINAL_APP="Warp";      return ;;
    Hyper)       TERMINAL_APP="Hyper";      return ;;
  esac

  # Method 2: known terminal emulators via environment
  [[ -n "${KITTY_WINDOW_ID:-}" ]]       && { TERMINAL_APP="kitty";     return; }
  [[ -n "${ALACRITTY_WINDOW_ID:-}" ]]   && { TERMINAL_APP="Alacritty"; return; }
  [[ "${GHOSTTY_RESOURCES_DIR:-}" ]]    && { TERMINAL_APP="Ghostty";   return; }

  # Method 3: Walk up /proc/$PPID/exe
  local pid=$$
  for _ in $(seq 1 10); do
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [[ -z "$pid" || "$pid" == 0 || "$pid" == 1 ]] && break
    local exe_name
    exe_name=$(basename "$(readlink -f "/proc/$pid/exe" 2>/dev/null)" 2>/dev/null || true)
    case "$exe_name" in
      gnome-terminal*) TERMINAL_APP="GNOME Terminal"; return ;;
      konsole*)        TERMINAL_APP="Konsole";        return ;;
      xfce4-terminal*) TERMINAL_APP="Xfce Terminal";  return ;;
      alacritty*)      TERMINAL_APP="Alacritty";      return ;;
      kitty*)          TERMINAL_APP="kitty";           return ;;
      wezterm*)        TERMINAL_APP="WezTerm";         return ;;
      foot*)           TERMINAL_APP="foot";            return ;;
      tilix*)          TERMINAL_APP="Tilix";           return ;;
      *code*|*Code*)   TERMINAL_APP="VS Code";         return ;;
      *cursor*|*Cursor*) TERMINAL_APP="Cursor";        return ;;
      ghostty*)        TERMINAL_APP="Ghostty";         return ;;
    esac
  done

  TERMINAL_APP="Terminal"
}

case "$OS" in
  Darwin) _detect_terminal_macos ;;
  *)      _detect_terminal_linux ;;
esac

# ─── 5. Focus check (opt-in) ──────────────────────────────────────────────────
# Set NOTIFY_DONE_ONLY_WHEN_AWAY=true to suppress the notification when the
# originating terminal/editor is already the frontmost app.

if [[ "${NOTIFY_DONE_ONLY_WHEN_AWAY:-false}" == "true" ]]; then
  _is_focused=false

  case "$OS" in
    Darwin)
      if [[ -n "$TERMINAL_ID" ]]; then
        _front=$(osascript -e \
          'bundle identifier of (info for (path to frontmost application))' \
          2>/dev/null || true)
        [[ "$_front" == "$TERMINAL_ID" ]] && _is_focused=true
        unset _front
      fi
      ;;
    Linux)
      if [[ "$IS_WSL" == false ]]; then
        # X11: xdotool
        if command -v xdotool &>/dev/null; then
          _win_name=$(xdotool getactivewindow getwindowname 2>/dev/null || true)
          if [[ -n "$_win_name" && -n "$TERMINAL_APP" ]]; then
            # Case-insensitive match of terminal app name in window title
            [[ "${_win_name,,}" == *"${TERMINAL_APP,,}"* ]] && _is_focused=true
          fi
          unset _win_name
        fi
        # Wayland/Sway
        if [[ "$_is_focused" == false ]] && command -v swaymsg &>/dev/null; then
          _focused_app=$(swaymsg -t get_tree 2>/dev/null \
            | jq -r '.. | select(.focused? == true) | .name // ""' 2>/dev/null || true)
          [[ -n "$_focused_app" && "${_focused_app,,}" == *"${TERMINAL_APP,,}"* ]] && _is_focused=true
          unset _focused_app
        fi
      fi
      # WSL: skip focus detection (not reliably supported)
      ;;
  esac

  [[ "$_is_focused" == true ]] && exit 0
  unset _is_focused
fi

# ─── 6. Build notification strings ───────────────────────────────────────────

# Language: NOTIFY_DONE_LANG overrides auto-detection ("zh" or "en")
_lang="${NOTIFY_DONE_LANG:-}"
if [[ -z "$_lang" ]]; then
  [[ "${LANG:-}${LC_ALL:-}" == *zh* ]] && _lang="zh" || _lang="en"
fi

# Subtitle: project · duration · click to return
_sub_parts=()
[[ "${NOTIFY_DONE_SHOW_PROJECT:-true}"  == "true" && -n "$PROJECT"  ]] && _sub_parts+=("$PROJECT")
[[ "${NOTIFY_DONE_SHOW_DURATION:-true}" == "true" && -n "$DURATION" ]] && _sub_parts+=("$DURATION")

if [[ "$_lang" == "zh" ]]; then
  TITLE="✅ Claude Code 已完成任务"
  _body="${SUMMARY:-任务已完成}"
  [[ -n "$DETAILS" ]] && MSG="$_body"$'\n\n'"$DETAILS" || MSG="$_body"
  if [[ "$OS" == "Darwin" ]]; then
    _sub_parts+=("点击返回 $TERMINAL_APP")
  else
    _sub_parts+=("$TERMINAL_APP")
  fi
else
  TITLE="✅ Claude Code — Task Done"
  _body="${SUMMARY:-Task completed}"
  [[ -n "$DETAILS" ]] && MSG="$_body"$'\n\n'"$DETAILS" || MSG="$_body"
  if [[ "$OS" == "Darwin" ]]; then
    _sub_parts+=("↩ $TERMINAL_APP")
  else
    _sub_parts+=("$TERMINAL_APP")
  fi
fi

SUB=""
for _p in "${_sub_parts[@]}"; do
  [[ -n "$SUB" ]] && SUB="$SUB · $_p" || SUB="$_p"
done
unset _lang _sub_parts _p

_sound_file="${NOTIFY_DONE_SOUND_FILE:-}"
[[ -z "$_sound_file" ]] && _sound_file=$(printf '%s' "$INPUT" | jq -r '.env.NOTIFY_DONE_SOUND_FILE // ""' 2>/dev/null || true)
_play_sound "$_sound_file"

# ─── 7. Send notification (platform-dispatched) ──────────────────────────────

_send_macos() {
  local notifier
  notifier="$(command -v terminal-notifier 2>/dev/null || true)"
  if [[ -n "$notifier" ]]; then
    local args=(-title "$TITLE" -message "$MSG" -subtitle "$SUB" -sound "Glass")
    [[ -n "$TERMINAL_ID" ]] && args+=(-activate "$TERMINAL_ID")
    "$notifier" "${args[@]}"
  else
    # Fallback: basic osascript (no click-to-focus)
    osascript -e "display notification \"$MSG\" with title \"$TITLE\" subtitle \"$SUB\" sound name \"Glass\""
  fi
}

_send_linux() {
  local notifier
  notifier="$(command -v notify-send 2>/dev/null || true)"
  if [[ -n "$notifier" ]]; then
    "$notifier" "$TITLE" "$MSG\n$SUB" \
      --app-name="Claude Code" \
      --icon=dialog-information \
      --expire-time=10000
  fi
}

_send_wsl() {
  # Strategy A: WSLg — notify-send works natively
  if command -v notify-send &>/dev/null; then
    notify-send "$TITLE" "$MSG\n$SUB" \
      --app-name="Claude Code" \
      --icon=dialog-information \
      --expire-time=10000
    return
  fi

  # Strategy B: PowerShell Windows Toast notification
  local ps
  ps="$(command -v powershell.exe 2>/dev/null || true)"
  [[ -z "$ps" ]] && return

  # Escape double quotes for PowerShell string embedding
  local ps_title="${TITLE//\"/\`\"}"
  local ps_msg="${MSG//\"/\`\"}"
  local ps_sub="${SUB//\"/\`\"}"

  "$ps" -NoProfile -NonInteractive -Command "
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

\$template = @\"
<toast>
  <visual>
    <binding template='ToastGeneric'>
      <text>$ps_title</text>
      <text>$ps_msg</text>
      <text placement='attribution'>$ps_sub</text>
    </binding>
  </visual>
  <audio src='ms-winsoundevent:Notification.Default'/>
</toast>
\"@

\$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
\$xml.LoadXml(\$template)
\$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code')
\$notifier.Show([Windows.UI.Notifications.ToastNotification]::new(\$xml))
" 2>/dev/null || true
}

case "$OS" in
  Darwin) _send_macos ;;
  Linux)
    if [[ "$IS_WSL" == true ]]; then
      _send_wsl
    else
      _send_linux
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    # Git Bash / MSYS2 on Windows — try PowerShell toast
    IS_WSL=true _send_wsl
    ;;
  *)
    # Unknown OS — silent fallback
    ;;
esac
