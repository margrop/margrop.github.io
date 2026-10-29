#!/usr/bin/env zsh
# HACS Beginner Automation Toolkit - macOS 27 Launcher (Zsh)
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
COMMAND="${1:-install}"
shift || true

echo -e "\033[36m>>> [macOS 27] Initializing HACS Automated Toolkit...\033[0m"

if ! command -v python3 >/dev/null 2>&1; then
    echo "Python3 not found. Please install via Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

python3 "$SCRIPT_DIR/hacs_toolkit.py" "$COMMAND" "$@"
