#!/usr/bin/env bash
# install.sh — Cross-platform installer for claude-code-notifier
#
# Usage:
#   bash install.sh
#   bash install.sh --uninstall

set -euo pipefail

HOOK_DIR="$HOME/.claude/hooks"
HOOK_FILE="$HOOK_DIR/claude-code-notify.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"
REPO_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/claude-code-notify.sh"
REPO_CONFIG_SERVER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config_server.py"
CONFIG_SERVER_FILE="$HOME/.claude/config_server.py"
CLAUDE_DIR="$HOME/.claude"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CLAUDE='\033[38;2;217;119;88m'; NC='\033[0m'

info()    { printf "${CLAUDE}  →${NC} %s\n" "$*"; }
success() { printf "${GREEN}  ✓${NC} %s\n" "$*"; }
warn()    { printf "${YELLOW}  ⚠${NC} %s\n" "$*"; }
die()     { printf "${RED}  ✗${NC} %s\n" "$*" >&2; exit 1; }

# ── Platform detection ────────────────────────────────────────────────────────
OS="$(uname -s)"
IS_WSL=false
[[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true

# ── Uninstall ─────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" ]]; then
  printf "\n${RED}Uninstalling claude-code-notifier…${NC}\n\n"

  [[ -f "$HOOK_FILE" ]] && { rm "$HOOK_FILE"; success "Removed $HOOK_FILE"; }

  if [[ -f "$SETTINGS_FILE" ]] && command -v jq &>/dev/null; then
    if jq -e '.hooks.Stop' "$SETTINGS_FILE" &>/dev/null; then
      TMP=$(mktemp)
      jq 'del(.hooks.Stop) | if .hooks == {} then del(.hooks) else . end' \
        "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
      success "Removed Stop hook from $SETTINGS_FILE"
    fi
    if jq -e '.hooks.Notification' "$SETTINGS_FILE" &>/dev/null; then
      TMP=$(mktemp)
      jq 'del(.hooks.Notification) | if .hooks == {} then del(.hooks) else . end' \
        "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
      success "Removed Notification hook from $SETTINGS_FILE"
    fi
  fi

  printf "\n${GREEN}Done. The notification hook has been removed.${NC}\n\n"
  exit 0
fi

# ── Install ───────────────────────────────────────────────────────────────────
printf "\n${CLAUDE}claude-code-notifier — installer${NC}\n"
printf "${CLAUDE}  Platform: %s%s${NC}\n\n" "$OS" "$([[ "$IS_WSL" == true ]] && echo ' (WSL)' || echo '')"

# ── 1. Install dependencies (platform-specific) ──────────────────────────────

_install_deps_macos() {
  # jq
  if ! command -v jq &>/dev/null; then
    warn "jq not found. Attempting to install via Homebrew…"
    command -v brew &>/dev/null || die "Homebrew not found. Install jq manually: https://stedolan.github.io/jq/"
    brew install jq
  fi
  success "jq: $(jq --version)"

  # terminal-notifier (enables click-to-focus)
  if ! command -v terminal-notifier &>/dev/null; then
    warn "terminal-notifier not found. Installing via Homebrew…"
    command -v brew &>/dev/null || die "Homebrew not found. Install terminal-notifier manually: brew install terminal-notifier"
    brew install terminal-notifier
  fi
  success "terminal-notifier: $(terminal-notifier 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
}

_install_deps_linux() {
  # Detect package manager
  local pm=""
  local pm_install=""
  if command -v apt-get &>/dev/null; then
    pm="apt"; pm_install="sudo apt-get install -y"
  elif command -v dnf &>/dev/null; then
    pm="dnf"; pm_install="sudo dnf install -y"
  elif command -v pacman &>/dev/null; then
    pm="pacman"; pm_install="sudo pacman -S --noconfirm"
  elif command -v zypper &>/dev/null; then
    pm="zypper"; pm_install="sudo zypper install -y"
  elif command -v apk &>/dev/null; then
    pm="apk"; pm_install="sudo apk add"
  fi

  # jq
  if ! command -v jq &>/dev/null; then
    if [[ -n "$pm_install" ]]; then
      warn "jq not found. Installing via $pm…"
      $pm_install jq
    else
      die "jq not found and no supported package manager detected. Install jq manually: https://stedolan.github.io/jq/"
    fi
  fi
  success "jq: $(jq --version)"

  # notify-send (libnotify)
  if ! command -v notify-send &>/dev/null; then
    if [[ -n "$pm_install" ]]; then
      warn "notify-send not found. Installing libnotify…"
      case "$pm" in
        apt)     $pm_install libnotify-bin ;;
        dnf)     $pm_install libnotify ;;
        pacman)  $pm_install libnotify ;;
        zypper)  $pm_install libnotify-tools ;;
        apk)     $pm_install libnotify ;;
      esac
    else
      warn "notify-send not found. Install libnotify manually for desktop notifications."
    fi
  fi
  if command -v notify-send &>/dev/null; then
    success "notify-send: available"
  else
    warn "notify-send not available — notifications may not work"
  fi
}

_install_deps_wsl() {
  # jq (inside WSL)
  if ! command -v jq &>/dev/null; then
    if command -v apt-get &>/dev/null; then
      warn "jq not found. Installing via apt…"
      sudo apt-get install -y jq
    else
      die "jq not found. Install jq manually: sudo apt-get install jq"
    fi
  fi
  success "jq: $(jq --version)"

  # Check for powershell.exe (should be available in WSL by default)
  if command -v powershell.exe &>/dev/null; then
    success "powershell.exe: available (Windows Toast notifications)"
  else
    warn "powershell.exe not found — Windows Toast notifications won't work"
  fi

  # Check for WSLg notify-send (optional bonus)
  if command -v notify-send &>/dev/null; then
    success "notify-send: available (WSLg)"
  else
    info "notify-send not available — will use Windows Toast via PowerShell"
  fi
}

case "$OS" in
  Darwin)       _install_deps_macos ;;
  Linux)
    if [[ "$IS_WSL" == true ]]; then
      _install_deps_wsl
    else
      _install_deps_linux
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    # Git Bash / MSYS2 — only need jq
    if ! command -v jq &>/dev/null; then
      die "jq not found. Install via: pacman -S jq (MSYS2) or download from https://stedolan.github.io/jq/"
    fi
    success "jq: $(jq --version)"
    info "Using PowerShell for Windows Toast notifications"
    ;;
  *)
    warn "Unknown platform: $OS — attempting to continue…"
    command -v jq &>/dev/null || die "jq is required but not found."
    success "jq: $(jq --version)"
    ;;
esac

# ── 2. Copy files ─────────────────────────────────────────────────────────────
info "Copying hook files to $CLAUDE_DIR..."
mkdir -p "$HOOK_DIR"
cp "$REPO_SCRIPT" "$HOOK_FILE"
chmod +x "$HOOK_FILE"

# Copy the config server if it exists
if [[ -f "$REPO_CONFIG_SERVER" ]]; then
  cp "$REPO_CONFIG_SERVER" "$CONFIG_SERVER_FILE"
  chmod +x "$CONFIG_SERVER_FILE"
fi

# Copy sounds directory if it exists
SOUNDS_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sounds"
SOUNDS_DEST="$CLAUDE_DIR/sounds"
if [[ -d "$SOUNDS_SOURCE" ]]; then
  info "Copying preset sounds to $SOUNDS_DEST..."
  mkdir -p "$SOUNDS_DEST"
  cp -r "$SOUNDS_SOURCE"/* "$SOUNDS_DEST/"
fi

success "Files copied to $CLAUDE_DIR"

# ── 3. Register hook in Claude Code settings ─────────────────────────────────
if [[ ! -f "$SETTINGS_FILE" ]]; then
  printf '{}' > "$SETTINGS_FILE"
  info "Created $SETTINGS_FILE"
fi

# Check if a Stop hook already exists
if jq -e '.hooks.Stop' "$SETTINGS_FILE" &>/dev/null; then
  # Check if our specific hook is already there
  if jq -e --arg cmd "bash $HOOK_FILE" '.hooks.Stop[]?.hooks[]? | select(.command == $cmd)' "$SETTINGS_FILE" &>/dev/null; then
    success "Stop hook already registered in $SETTINGS_FILE — skipping"
  else
    warn "A Stop hook already exists in $SETTINGS_FILE."
    warn "Adding alongside existing hooks."
    TMP=$(mktemp)
    jq --arg cmd "bash $HOOK_FILE" \
      '.hooks.Stop += [{"hooks": [{"type": "command", "command": $cmd, "async": true}]}]' \
      "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
    success "Stop hook appended to existing Stop hooks"
  fi
else
  TMP=$(mktemp)
  jq --arg cmd "bash $HOOK_FILE" \
    '. + {"hooks": (.hooks // {} | . + {"Stop": [{"hooks": [{"type": "command", "command": $cmd, "async": true}]}]})}' \
    "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
  success "Stop hook registered in $SETTINGS_FILE"
fi

# Check if a Notification hook already exists
if jq -e '.hooks.Notification' "$SETTINGS_FILE" &>/dev/null; then
  if jq -e --arg cmd "bash $HOOK_FILE" '.hooks.Notification[]?.hooks[]? | select(.command == $cmd)' "$SETTINGS_FILE" &>/dev/null; then
    success "Notification hook already registered in $SETTINGS_FILE — skipping"
  else
    warn "A Notification hook already exists in $SETTINGS_FILE."
    warn "Adding alongside existing hooks."
    TMP=$(mktemp)
    jq --arg cmd "bash $HOOK_FILE" \
      '.hooks.Notification += [{"hooks": [{"type": "command", "command": $cmd, "async": true}]}]' \
      "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
    success "Notification hook appended to existing Notification hooks"
  fi
else
  TMP=$(mktemp)
  jq --arg cmd "bash $HOOK_FILE" \
    '.hooks //= {} | .hooks.Notification = [{"hooks": [{"type": "command", "command": $cmd, "async": true}]}]' \
    "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
  success "Notification hook registered in $SETTINGS_FILE"
fi

# ── 4. Interactive configuration ──────────────────────────────────────────────
printf "\n${CLAUDE}  Configuration${NC}\n"
printf "  ${CLAUDE}─────────────────────────────────────────────────${NC}\n"

# Helper: prompt with default value, returns answer in $REPLY
_ask() {
  local prompt="$1" default="$2"
  printf "  ${CLAUDE}?${NC} ${prompt} "
  read -r REPLY </dev/tty
  [[ -z "$REPLY" ]] && REPLY="$default"
}

_ask_yn() {
  local prompt="$1" default="$2"
  local sel_options=("${OPT_YES:-Yes}" "${OPT_NO:-No}")
  [[ "$default" == "n" ]] && _SELECT_DEFAULT=1 || _SELECT_DEFAULT=0
  _select "$prompt" "${sel_options[@]}"
  [[ "$REPLY" -eq 1 ]] && REPLY="true" || REPLY="false"
  unset _SELECT_DEFAULT
}

# Helper: Interactive list selector with arrow keys
_select() {
  local prompt="$1"
  shift
  local options=("$@")
  local current="${_SELECT_DEFAULT:-0}"
  local count=${#options[@]}
  local i

  # Hide cursor and handle interrupts
  printf "\e[?25l"
  trap 'printf "\e[?25h"; exit 1' INT TERM

  # Initial prompt
  printf "  ${CLAUDE}?${NC} ${prompt}\n"

  while true; do
    # Render options
    for i in "${!options[@]}"; do
      if [[ $i -eq $current ]]; then
        printf "\r    ${CLAUDE}❯ %s${NC}\e[K\n" "${options[$i]}"
      else
        printf "\r      %s\e[K\n" "${options[$i]}"
      fi
    done

    # Read key
    read -rsn1 key
    if [[ "$key" == $'\e' ]]; then
      read -rsn2 key
      case "$key" in
        '[A') ((current--)) ;; # Up
        '[B') ((current++)) ;; # Down
      esac
      # Wrap around
      [[ $current -lt 0 ]] && current=$((count - 1))
      [[ $current -ge $count ]] && current=0
    elif [[ "$key" == "" ]]; then # Enter
      break
    fi

    # Move cursor back up to redraw options
    printf "\e[${count}A"
  done

  # Show cursor and cleanup trap
  printf "\e[?25h"
  trap - INT TERM
  REPLY=$((current + 1))
}

# 4a. Language
_select "Language (notification text):" "auto-detect" "English (en)" "中文 (zh)"
case "$REPLY" in
  2) CFG_LANG="en" ;;
  3) CFG_LANG="zh" ;;
  *) CFG_LANG=""   ;; # auto-detect
esac

# Default English texts
Q_SUMMARY="Show Claude's reply summary as notification body?"
Q_DURATION="Show task duration in the subtitle?"
Q_PROJECT="Show project name in the subtitle?"
Q_AWAY="Only notify when you're away (suppress if terminal is focused)?"
OPT_YES="Yes"
OPT_NO="No"

# Switch to Chinese if selected
if [[ "$CFG_LANG" == "zh" ]]; then
  Q_SUMMARY="是否在通知正文中显示 Claude 的回复摘要？"
  Q_DURATION="是否在副标题中显示任务耗时？"
  Q_PROJECT="是否在副标题中显示项目名称？"
  Q_AWAY="仅在离开时通知（如果当前终端窗口已获得焦点则静默）？"
  OPT_YES="是 (Yes)"
  OPT_NO="否 (No)"
fi

[[ -n "$CFG_LANG" ]] && success "Language → $CFG_LANG" || success "Language → auto-detect"

# 4b. Show task summary
_ask_yn "$Q_SUMMARY" "y"
CFG_SUMMARY="$REPLY"
success "$([[ "$CFG_LANG" == "zh" ]] && echo '显示摘要' || echo 'Show summary') → $CFG_SUMMARY"

# 4c. Show task duration
_ask_yn "$Q_DURATION" "y"
CFG_DURATION="$REPLY"
success "$([[ "$CFG_LANG" == "zh" ]] && echo '显示耗时' || echo 'Show duration') → $CFG_DURATION"

# 4d. Show project name
_ask_yn "$Q_PROJECT" "y"
CFG_PROJECT="$REPLY"
success "$([[ "$CFG_LANG" == "zh" ]] && echo '显示项目' || echo 'Show project') → $CFG_PROJECT"

# 4e. Focus-aware mode
_ask_yn "$Q_AWAY" "n"
CFG_AWAY="$REPLY"
success "$([[ "$CFG_LANG" == "zh" ]] && echo '焦点感知' || echo 'Focus-aware') → $CFG_AWAY"

success "$([[ "$CFG_LANG" == "zh" ]] && echo '焦点感知' || echo 'Focus-aware') → $CFG_AWAY"

# Write env config to settings.json
printf "\n"
TMP=$(mktemp)
jq \
  --arg lang        "$CFG_LANG" \
  --arg summary     "$CFG_SUMMARY" \
  --arg duration    "$CFG_DURATION" \
  --arg project     "$CFG_PROJECT" \
  --arg away        "$CFG_AWAY" \
  --arg s_notify    "$CLAUDE_DIR/sounds/minimal_chime.wav" \
  --arg s_stop      "$CLAUDE_DIR/sounds/mario_coin.wav" \
  '
  .env //= {} |
  if $lang != "" then .env.NOTIFY_LANG = $lang else del(.env.NOTIFY_LANG) end |
  .env.NOTIFY_SHOW_SUMMARY   = $summary  |
  .env.NOTIFY_SHOW_DURATION  = $duration |
  .env.NOTIFY_SHOW_PROJECT   = $project  |
  .env.NOTIFY_ONLY_WHEN_AWAY = $away     |
  .env.NOTIFY_SOUND_NOTIFICATION = (.env.NOTIFY_SOUND_NOTIFICATION // $s_notify) |
  .env.NOTIFY_SOUND_END = (.env.NOTIFY_SOUND_END // $s_stop)
  ' "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
success "Configuration saved → $SETTINGS_FILE"


jq empty "$SETTINGS_FILE" && success "settings.json is valid JSON"

# ── 5. Smoke-test ─────────────────────────────────────────────────────────────
printf '\n%s' "Testing notification… "
echo '{"session_id":""}' | bash "$HOOK_FILE" && printf "${GREEN}OK${NC}\n" || printf "${RED}FAILED${NC}\n"

# ── 6. Web Configuration Console ──────────────────────────────────────────────
if [[ -f "$CONFIG_SERVER_FILE" ]] && command -v python3 &>/dev/null; then
  printf "\n"
  if [[ "$CFG_LANG" == "zh" ]]; then
    Q_WEB="是否打开 Web 控制台来进行更多配置？（飞书 Webhook、LLM 摘要、自定义音效等）"
  else
    Q_WEB="Open the Web Configuration Console for advanced settings? (Feishu, LLM summary, custom sounds, etc.)"
  fi
  _ask_yn "$Q_WEB" "y"
  if [[ "$REPLY" == "true" ]]; then
    CONFIG_PORT=8888
    # Find an available port if 8888 is in use
    while lsof -i :"$CONFIG_PORT" &>/dev/null 2>&1; do
      CONFIG_PORT=$((CONFIG_PORT + 1))
    done

    # Start the config server in the background
    NOTIFY_CONFIG_PORT="$CONFIG_PORT" python3 "$CONFIG_SERVER_FILE" &
    CONFIG_PID=$!
    sleep 0.5

    # Open the browser
    case "$OS" in
      Darwin)       open "http://localhost:$CONFIG_PORT" ;;
      Linux)
        if [[ "$IS_WSL" == true ]]; then
          cmd.exe /c start "http://localhost:$CONFIG_PORT" 2>/dev/null || \
            powershell.exe -c "Start-Process 'http://localhost:$CONFIG_PORT'" 2>/dev/null
        else
          xdg-open "http://localhost:$CONFIG_PORT" 2>/dev/null || \
            sensible-browser "http://localhost:$CONFIG_PORT" 2>/dev/null
        fi
        ;;
      MINGW*|MSYS*|CYGWIN*)
        start "http://localhost:$CONFIG_PORT" 2>/dev/null
        ;;
    esac

    if [[ "$CFG_LANG" == "zh" ]]; then
      info "Web 控制台已在浏览器中打开 (http://localhost:$CONFIG_PORT)"
      info "点击 'Save & Close' 后服务将自动关闭。"
    else
      info "Web Console opened at http://localhost:$CONFIG_PORT"
      info "Server will shut down automatically when you click 'Save & Close'."
    fi

    # Wait for the server to exit
    wait "$CONFIG_PID" 2>/dev/null
    success "$([[ "$CFG_LANG" == "zh" ]] && echo 'Web 控制台已关闭' || echo 'Web Console closed')"
  fi
else
  # Fallback: show tips if python3 is not available
  if [[ "$CFG_LANG" == "zh" ]]; then
    printf "\n${CLAUDE}  ✨ 你知道吗？还有更多"隐藏"功能！${NC}"
    printf "\n  ${CLAUDE}• ${NC}飞书通知：配置 NOTIFY_FEISHU_WEBHOOK_URL 即可开启。"
    printf "\n  ${CLAUDE}• ${NC}LLM 摘要：配置 NOTIFY_LLM_API_KEY，让 AI 总结回复内容。"
    printf "\n  ${CLAUDE}• ${NC}自定义音效：配置 NOTIFY_SOUND_FILE 播放你喜欢的提示音。"
    printf "\n  详情请见 README 中的"环境变量"部分。\n"
  else
    printf "\n${CLAUDE}  ✨ Pro Tip: You have more features!${NC}"
    printf "\n  ${CLAUDE}• ${NC}Feishu (Lark): Set NOTIFY_FEISHU_WEBHOOK_URL to enable."
    printf "\n  ${CLAUDE}• ${NC}LLM Summary: Set NOTIFY_LLM_API_KEY to distill responses."
    printf "\n  ${CLAUDE}• ${NC}Custom Sound: Set NOTIFY_SOUND_FILE for custom audio cues."
    printf "\n  Check README's \"Environmental Variables\" section for details.\n"
  fi
fi

printf "\n${GREEN}Installation complete!${NC}\n"
printf "Restart Claude Code (or open /hooks) to activate the hook.\n\n"
