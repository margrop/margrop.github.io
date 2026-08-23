#!/usr/bin/env bash
# One-click entry point for macOS 26. Uses the local Python 3 standard library.
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v python3 >/dev/null 2>&1; then
  printf '%s\n' 'Python 3 is required. Install an official Python 3 distribution first.' >&2
  exit 1
fi

python3 "$LAB_DIR/worker_crash_lab.py" --clean
SUMMARY="$LAB_DIR/lab-output/results/06-acceptance-summary.txt"
PASS_COUNT="$(grep -c '^\[PASS\]' "$SUMMARY" || true)"
if [[ "$PASS_COUNT" != "7" ]] || ! grep -q '^result=PASS$' "$SUMMARY"; then
  printf '%s\n' 'Acceptance failed. Review the result files in lab-output/results.' >&2
  exit 1
fi
printf '%s\n' "PASS: 7/7 checks. Evidence is in $LAB_DIR/lab-output"
