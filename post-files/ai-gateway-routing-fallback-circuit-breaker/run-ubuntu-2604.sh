#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/lab-output"

command -v python3 >/dev/null 2>&1 || {
  echo "Python 3 was not found. Install the Ubuntu python3 package and retry." >&2
  exit 1
}

python3 "${SCRIPT_DIR}/ai_gateway_fault_lab.py" \
  --scenario all \
  --output-dir "${OUTPUT_DIR}" \
  --clean

python3 - "${OUTPUT_DIR}/summary.json" <<'PY'
import json
import pathlib
import sys

summary = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert summary["outbound_attempts"] == 0
assert summary["results"]["acceptance"]["passed"] == 7
print("PASS: 7/7 checks; outbound network attempts: 0")
PY
