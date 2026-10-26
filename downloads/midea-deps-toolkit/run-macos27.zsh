#!/usr/bin/env zsh
# macOS 27 Zsh Automation Script
# Home Assistant Midea AC LAN Offline Dependency Upgrade Toolkit
set -eu

echo "=========================================================="
echo " Home Assistant Midea AC LAN Offline Deps Toolkit (macOS)"
echo "=========================================================="

SCRIPT_DIR="${0:A:h}"
PYTHON_BIN="$(command -v python3)"

if [[ -z "${PYTHON_BIN}" ]]; then
    echo "Error: Python 3 is required but not found in PATH." >&2
    exit 1
fi

exec "${PYTHON_BIN}" "${SCRIPT_DIR}/midea_deps_toolkit.py" "$@"
