#!/usr/bin/env bash
# Ubuntu 26.04 LTS Bash Automation Script
# Home Assistant Midea AC LAN Offline Dependency Upgrade Toolkit
set -euo pipefail

echo "=========================================================="
echo " Home Assistant Midea AC LAN Offline Deps Toolkit (Ubuntu)"
echo "=========================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="$(command -v python3 || command -v python)"

if [[ -z "${PYTHON_BIN}" ]]; then
    echo "Error: Python 3 is required but not found in PATH." >&2
    exit 1
fi

exec "${PYTHON_BIN}" "${SCRIPT_DIR}/midea_deps_toolkit.py" "$@"
