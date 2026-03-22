#!/usr/bin/env bash
# notify-done.sh — Claude Code "Stop" hook
#
# Sends a macOS native notification when Claude finishes a task.
# • Shows first sentence of Claude's last reply as the task summary.
# • Shows session duration and project name in the subtitle.
# • Clicking the notification activates the originating terminal/editor.
# • Supports English and Chinese (auto-detected or configured via env var).
#
# Requirements: macOS, terminal-notifier (brew install terminal-notifier)
# Install:      See README.md or run install.sh
#
# ── Configuration (set in ~/.claude/settings.json → "env": { … }) ─────────────
#   NOTIFY_DONE_LANG            "zh" or "en"  (default: auto-detect from $LANG)
#   NOTIFY_DONE_ONLY_WHEN_AWAY  "true"        (default: "false") — skip notification
#                                              if the terminal is already focused
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─── 1. Read hook input (session_id lives here) ───────────────────────────────

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)

# ─── 2. Extract info from transcript ─────────────────────────────────────────

SUMMARY=""
DURATION=""
PROJECT=""

if [[ -n "$SESSION_ID" ]]; then
  TRANSCRIPT=$(find ~/.claude/projects -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)
  if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then

    # 2a. Session duration (first → last timestamp in the JSONL)
    _first_ts=$(jq -r '.timestamp // empty' "$TRANSCRIPT" 2>/dev/null | head -1 || true)
    _last_ts=$(jq -r '.timestamp // empty'  "$TRANSCRIPT" 2>/dev/null | tail -1 || true)
    if [[ -n "$_first_ts" && -n "$_last_ts" ]]; then
      _s=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${_first_ts%%.*}" "+%s" 2>/dev/null || echo 0)
      _e=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${_last_ts%%.*}"  "+%s" 2>/dev/null || echo 0)
      _elapsed=$(( _e - _s ))
      if   [[ $_elapsed -ge 60 ]]; then DURATION="$(( _elapsed/60 ))m $(( _elapsed%60 ))s"
      elif [[ $_elapsed -gt  0 ]]; then DURATION="${_elapsed}s"
      fi
    fi
    unset _first_ts _last_ts _s _e _elapsed

    # 2b. Project name — decode the sanitized directory name
    #   e.g. "-Users-echo-…--PromptMiner-prompt-miner" → "prompt-miner"
    _pdir=$(basename "$(dirname "$TRANSCRIPT")")
    PROJECT=$(printf '%s' "$_pdir" | sed 's/^-//' | awk -F'--+' '{print $NF}')
    unset _pdir

    # 2c. Task summary — first sentence of the last assistant message that
    #     contains actual text (skips thinking-only / mid-stream entries)
    _raw=$(jq -rs '[.[] | select(.type == "assistant") |
                   select(.message.content | arrays |
                     map(select(.type == "text")) | length > 0)] |
                   last |
                   .message.content |
                   if type == "array" then
                     map(select(.type == "text")) | .[0].text // ""
                   else . // ""
                   end' "$TRANSCRIPT" 2>/dev/null || true)
    if [[ -n "$_raw" ]]; then
      _cleaned=$(printf '%s' "$_raw" \
        | tr '\n\r\t' ' ' \
        | sed 's/[[:space:]]\+/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//' \
        | sed "s/\`\`\`[^\`]*\`\`\`//g; s/\`[^\`]*\`//g" \
        | sed 's/\*\*\([^*]*\)\*\*/\1/g; s/\*//g; s/^#\+[[:space:]]*//')
      _sentence=$(printf '%s' "$_cleaned" | sed 's/\([.?!。？！]\).*/\1/')
      if [[ "$_sentence" != "$_cleaned" && ${#_sentence} -ge 5 ]]; then
        SUMMARY=$(printf '%s' "$_sentence" | cut -c1-100)
      else
        SUMMARY=$(printf '%s' "$_cleaned"  | cut -c1-100)
      fi
      unset _cleaned _sentence
    fi
    unset _raw
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

# ─── 4. Focus check (opt-in) ──────────────────────────────────────────────────
# Set NOTIFY_DONE_ONLY_WHEN_AWAY=true to suppress the notification when the
# originating terminal/editor is already the frontmost app.

if [[ "${NOTIFY_DONE_ONLY_WHEN_AWAY:-false}" == "true" && -n "$BUNDLE_ID" ]]; then
  _front=$(osascript -e \
    'bundle identifier of (info for (path to frontmost application))' \
    2>/dev/null || true)
  [[ "$_front" == "$BUNDLE_ID" ]] && exit 0
  unset _front
fi

# ─── 5. Build notification strings ───────────────────────────────────────────

# Language: NOTIFY_DONE_LANG overrides auto-detection ("zh" or "en")
_lang="${NOTIFY_DONE_LANG:-}"
if [[ -z "$_lang" ]]; then
  [[ "${LANG:-}${LC_ALL:-}" == *zh* ]] && _lang="zh" || _lang="en"
fi

# Subtitle: project · duration · click to return
_sub_parts=()
[[ -n "$PROJECT"  ]] && _sub_parts+=("$PROJECT")
[[ -n "$DURATION" ]] && _sub_parts+=("$DURATION")

if [[ "$_lang" == "zh" ]]; then
  TITLE="✅ Claude Code 已完成"
  MSG="${SUMMARY:-任务已完成}"
  _sub_parts+=("点击返回 $APP_NAME")
else
  TITLE="✅ Claude Code — Done"
  MSG="${SUMMARY:-Task completed}"
  _sub_parts+=("↩ $APP_NAME")
fi

SUB=""
for _p in "${_sub_parts[@]}"; do
  [[ -n "$SUB" ]] && SUB="$SUB · $_p" || SUB="$_p"
done
unset _lang _sub_parts _p

# ─── 6. Send notification ─────────────────────────────────────────────────────

NOTIFIER="$(command -v terminal-notifier 2>/dev/null || true)"

if [[ -n "$NOTIFIER" ]]; then
  ARGS=(-title "$TITLE" -message "$MSG" -subtitle "$SUB" -sound "Glass")
  [[ -n "$BUNDLE_ID" ]] && ARGS+=(-activate "$BUNDLE_ID")
  "$NOTIFIER" "${ARGS[@]}"
else
  # Fallback: basic osascript (no click-to-focus)
  osascript -e "display notification \"$MSG\" with title \"$TITLE\" subtitle \"$SUB\" sound name \"Glass\""
fi

