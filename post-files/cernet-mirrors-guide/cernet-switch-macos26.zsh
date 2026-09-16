#!/usr/bin/env zsh
# ==============================================================================
# Script Name: cernet-switch-macos26.zsh
# Supported OS: macOS 26 (Tahoe) / macOS 15 (Sequoia) / macOS 14 (Sonoma)
# Description: Configures Homebrew and Python pip to leverage the CERNET Hub,
#              with automatic environment variable injection into ~/.zprofile.
# Dependencies: Built-in macOS Zsh and developer tools, zero external dependencies.
# ==============================================================================

set -e

MODE="apply"
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --apply) MODE="apply"; shift ;;
    --json)  OUTPUT_JSON=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

PROFILE_FILE="${HOME}/.zprofile"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BREW_BOT_URL="https://mirrors.cernet.edu.cn/homebrew-bottles"
PIP_INDEX_URL="https://mirrors.cernet.edu.cn/pypi/web/simple/"

BREW_FOUND=false
command -v brew >/dev/null 2>&1 && BREW_FOUND=true

IS_CONFIGURED=false
if [ -f "$PROFILE_FILE" ] && grep -q "mirrors.cernet.edu.cn/homebrew-bottles" "$PROFILE_FILE"; then
  IS_CONFIGURED=true
fi

REDIRECT_NODE=$(curl -sIL -o /dev/null -w "%{redirect_url}" "$BREW_BOT_URL" 2>/dev/null || echo "unreachable")
[ -z "$REDIRECT_NODE" ] && REDIRECT_NODE="direct"

if [ "$MODE" = "check" ]; then
  if [ "$OUTPUT_JSON" = true ]; then
    printf '{"os":"macos","brew_installed":%s,"configured":%s,"redirect_node":"%s"}\n' \
      "$BREW_FOUND" "$IS_CONFIGURED" "$REDIRECT_NODE"
  else
    echo "=== macOS 26 CERNET Mirror Inspection ==="
    echo "Homebrew Installed: $BREW_FOUND"
    echo "Bottles Injected: $IS_CONFIGURED"
    echo "Redirect Node: $REDIRECT_NODE"
  fi
  exit 0
fi

BACKUP_PATH=""
if [ -f "$PROFILE_FILE" ]; then
  BACKUP_PATH="${PROFILE_FILE}.bak.${TIMESTAMP}"
  cp "$PROFILE_FILE" "$BACKUP_PATH"
fi

[ -f "$PROFILE_FILE" ] && sed -i '' '/HOMEBREW_BOTTLE_DOMAIN/d' "$PROFILE_FILE" || touch "$PROFILE_FILE"

cat << 'EOF' >> "$PROFILE_FILE"
# >>> CERNET MirrorZ Auto Injection >>>
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.cernet.edu.cn/homebrew-bottles"
export HOMEBREW_API_DOMAIN="https://mirrors.cernet.edu.cn/homebrew-bottles/api"
# <<< CERNET MirrorZ Auto Injection <<<
EOF

if [ "$BREW_FOUND" = true ]; then
  git -C "$(brew --repo)" remote set-url origin https://mirrors.cernet.edu.cn/git/homebrew/brew.git 2>/dev/null || true
fi

PIP_STATUS="skipped"
if command -v python3 >/dev/null 2>&1; then
  python3 -m pip config set global.index-url "$PIP_INDEX_URL" >/dev/null 2>&1 || true
  PIP_STATUS="applied"
fi

if [ "$OUTPUT_JSON" = true ]; then
  printf '{"status":"success","os":"macos","backup":"%s","redirect_node":"%s","pip":"%s"}\n' \
    "$BACKUP_PATH" "$REDIRECT_NODE" "$PIP_STATUS"
else
  echo "\033[32m[SUCCESS]\033[0m macOS Homebrew and pip successfully configured to CERNET!"
  echo "• Profile modified: $PROFILE_FILE (Backup: $BACKUP_PATH)"
  echo "• Dynamic redirect target: $REDIRECT_NODE"
  echo "• Run the following to refresh: source ~/.zprofile"
fi
