#!/usr/bin/env bash
# HACS Beginner Automation Toolkit - Ubuntu 26.04 LTS Launcher (Bash)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="${1:-install}"
shift || true

echo -e "\033[36m>>> [Ubuntu 26.04] Initializing HACS Automated Toolkit...\033[0m"

if ! command -v python3 >/dev/null 2>&1; then
    echo "Python3 not found. Installing via apt..."
    sudo apt-get update && sudo apt-get install -y python3 python3-pip
fi

python3 "$SCRIPT_DIR/hacs_toolkit.py" "$COMMAND" "$@"
