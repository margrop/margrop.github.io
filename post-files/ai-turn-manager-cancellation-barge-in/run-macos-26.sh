#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
lab_file="${script_dir}/turn_manager_lab.py"
output_dir="${script_dir}/lab-output"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 was not found. Install Python 3, then rerun this script." >&2
  exit 1
fi

if [[ "${1:-}" == "--agent" ]]; then
  python3 "${lab_file}" --clean --output "${output_dir}" --agent
else
  python3 "${lab_file}" --clean --output "${output_dir}"
fi

python3 - "${output_dir}/report.json" <<'PY'
import json
import pathlib
import sys

report = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
if report["status"] != "PASS":
    raise SystemExit("Release gate did not pass; inspect lab-output/report.json")
print(f"Verified: {report['assertions']['passed']}/{report['assertions']['total']} assertions PASS")
PY

printf 'Evidence: %s\n' "${output_dir}"
