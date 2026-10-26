#!/usr/bin/env bash
set -euo pipefail
TASK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v python3 >/dev/null 2>&1; then
  echo 'Python 3.11+ is required. No software was installed and HA was not changed.' >&2
  exit 1
fi
exec python3 "$TASK_DIR/ha_dashboard.py" "$@"
