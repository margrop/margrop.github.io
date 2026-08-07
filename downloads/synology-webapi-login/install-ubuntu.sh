#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"

if ! command -v python3 >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y python3 python3-venv
elif ! python3 -m venv --help >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y python3-venv
fi

python3 -m venv "${VENV_DIR}"
"${VENV_DIR}/bin/python" -m pip install --upgrade pip
"${VENV_DIR}/bin/python" -m pip install -r "${SCRIPT_DIR}/requirements.txt"

if [[ "${SYNOLOGY_SETUP_ONLY:-0}" == "1" ]]; then
  exec "${VENV_DIR}/bin/python" "${SCRIPT_DIR}/synology_login.py" --help
fi

read -r -p "DSM URL (for example https://nas.example.test:5001): " DSM_URL
read -r -p "Account: " DSM_ACCOUNT
read -r -p "Session name [DSM]: " DSM_SESSION
DSM_SESSION="${DSM_SESSION:-DSM}"

exec "${VENV_DIR}/bin/python" "${SCRIPT_DIR}/synology_login.py" \
  --url "${DSM_URL}" \
  --account "${DSM_ACCOUNT}" \
  --session "${DSM_SESSION}"
