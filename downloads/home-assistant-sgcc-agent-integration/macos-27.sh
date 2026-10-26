#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
command -v python3 >/dev/null || { echo 'Install Python 3.11+ before running this kit.' >&2; exit 1; }
exec python3 sgcc_kit.py "$@"
