#!/bin/zsh
set -euo pipefail
TASK_DIR="${0:A:h}"
if ! command -v python3 >/dev/null 2>&1; then
  print -u2 'Python 3.11+ is required. No software was installed and HA was not changed.'
  exit 1
fi
exec python3 "$TASK_DIR/ha_dashboard.py" "$@"
