#!/usr/bin/env bash
# install.sh — One-command installer for claude-code-done-notifier
#
# Usage:
#   bash install.sh
#   bash install.sh --uninstall

set -euo pipefail

HOOK_DIR="$HOME/.claude/hooks"
HOOK_FILE="$HOOK_DIR/notify-done.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"
REPO_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/notify-done.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { printf "${CYAN}  →${NC} %s\n" "$*"; }
success() { printf "${GREEN}  ✓${NC} %s\n" "$*"; }
warn()    { printf "${YELLOW}  ⚠${NC} %s\n" "$*"; }
die()     { printf "${RED}  ✗${NC} %s\n" "$*" >&2; exit 1; }

# ── Uninstall ─────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" ]]; then
  printf "\n${RED}Uninstalling claude-code-done-notifier…${NC}\n\n"

  [[ -f "$HOOK_FILE" ]] && { rm "$HOOK_FILE"; success "Removed $HOOK_FILE"; }

  if [[ -f "$SETTINGS_FILE" ]] && command -v jq &>/dev/null; then
    if jq -e '.hooks.Stop' "$SETTINGS_FILE" &>/dev/null; then
      TMP=$(mktemp)
      jq 'del(.hooks.Stop) | if .hooks == {} then del(.hooks) else . end' \
        "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
      success "Removed Stop hook from $SETTINGS_FILE"
    fi
  fi

  printf "\n${GREEN}Done. The notification hook has been removed.${NC}\n\n"
  exit 0
fi

# ── Install ───────────────────────────────────────────────────────────────────
printf "\n${CYAN}claude-code-done-notifier — installer${NC}\n\n"

# 1. Platform check
[[ "$(uname)" == "Darwin" ]] || die "This hook requires macOS."

# 2. Dependency: jq
if ! command -v jq &>/dev/null; then
  warn "jq not found. Attempting to install via Homebrew…"
  command -v brew &>/dev/null || die "Homebrew not found. Install jq manually: https://stedolan.github.io/jq/"
  brew install jq
fi
success "jq: $(jq --version)"

# 3. Dependency: terminal-notifier (enables click-to-focus)
if ! command -v terminal-notifier &>/dev/null; then
  warn "terminal-notifier not found. Installing via Homebrew…"
  command -v brew &>/dev/null || die "Homebrew not found. Install terminal-notifier manually: brew install terminal-notifier"
  brew install terminal-notifier
fi
success "terminal-notifier: $(terminal-notifier 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"

# 4. Copy hook script
mkdir -p "$HOOK_DIR"
cp "$REPO_SCRIPT" "$HOOK_FILE"
chmod +x "$HOOK_FILE"
success "Hook script installed → $HOOK_FILE"

# 5. Register hook in Claude Code settings
if [[ ! -f "$SETTINGS_FILE" ]]; then
  printf '{}' > "$SETTINGS_FILE"
  info "Created $SETTINGS_FILE"
fi

# Check if a Stop hook already exists
if jq -e '.hooks.Stop' "$SETTINGS_FILE" &>/dev/null; then
  # Check if our specific hook is already there
  if jq -e --arg cmd "bash $HOOK_FILE" '.hooks.Stop[]?.hooks[]? | select(.command == $cmd)' "$SETTINGS_FILE" &>/dev/null; then
    success "Hook already registered in $SETTINGS_FILE — skipping"
  else
    warn "A Stop hook already exists in $SETTINGS_FILE."
    warn "Adding alongside existing hooks."
    TMP=$(mktemp)
    jq --arg cmd "bash $HOOK_FILE" \
      '.hooks.Stop += [{"hooks": [{"type": "command", "command": $cmd, "async": true}]}]' \
      "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
    success "Hook appended to existing Stop hooks"
  fi
else
  TMP=$(mktemp)
  jq --arg cmd "bash $HOOK_FILE" \
    '. + {"hooks": (.hooks // {} | . + {"Stop": [{"hooks": [{"type": "command", "command": $cmd, "async": true}]}]})}' \
    "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
  success "Hook registered in $SETTINGS_FILE"
fi

# 6. Validate JSON
jq empty "$SETTINGS_FILE" && success "settings.json is valid JSON"

# 7. Smoke-test
printf '\n%s' "Testing notification… "
echo '{"session_id":""}' | bash "$HOOK_FILE" && printf "${GREEN}OK${NC}\n" || printf "${RED}FAILED${NC}\n"

printf "\n${GREEN}Installation complete!${NC}\n"
printf "Restart Claude Code (or open /hooks) to activate the hook.\n\n"
