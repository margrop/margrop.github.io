#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
/usr/bin/env python3 "$script_dir/release_gate_lab.py" --clean --output "$script_dir/release-gate-output"
sed -n '1,120p' "$script_dir/release-gate-output/07-release-summary.txt"
