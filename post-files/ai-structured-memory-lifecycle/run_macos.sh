#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
/usr/bin/env python3 "$script_dir/memory_lifecycle_lab.py" --clean --output "$script_dir/memory-lab-output"
sed -n '1,120p' "$script_dir/memory-lab-output/07-acceptance-summary.txt"
