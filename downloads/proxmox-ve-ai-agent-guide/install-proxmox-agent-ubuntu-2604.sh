#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/.local/share/mcp-proxmox"
CONFIG_FILE="${HOME}/.config/Claude/claude_desktop_config.json"

sudo apt-get update
sudo apt-get install -y git nodejs npm python3 ca-certificates

read -r -p "Proxmox 地址（不含 https://）: " PROXMOX_HOST
read -r -p "Proxmox 用户 [ai-agent@pve]: " PROXMOX_USER
PROXMOX_USER="${PROXMOX_USER:-ai-agent@pve}"
read -r -p "Token 名称 [mcp]: " PROXMOX_TOKEN_NAME
PROXMOX_TOKEN_NAME="${PROXMOX_TOKEN_NAME:-mcp}"
read -r -s -p "Token Secret: " PROXMOX_TOKEN_VALUE
echo
export PROXMOX_HOST PROXMOX_USER PROXMOX_TOKEN_NAME PROXMOX_TOKEN_VALUE

mkdir -p "$(dirname "${INSTALL_DIR}")" "$(dirname "${CONFIG_FILE}")"
if [[ -d "${INSTALL_DIR}/.git" ]]; then
  git -C "${INSTALL_DIR}" pull --ff-only
else
  git clone https://github.com/gilby125/mcp-proxmox.git "${INSTALL_DIR}"
fi
npm --prefix "${INSTALL_DIR}" install --omit=dev

python3 - "${CONFIG_FILE}" "${INSTALL_DIR}" <<'PY'
import json, os, sys
path, install = sys.argv[1:]
try:
    data = json.load(open(path, encoding="utf-8"))
except (FileNotFoundError, json.JSONDecodeError):
    data = {}
data.setdefault("mcpServers", {})["proxmox"] = {
    "command": "node",
    "args": [os.path.join(install, "index.js")],
    "env": {
        "PROXMOX_HOST": os.environ["PROXMOX_HOST"],
        "PROXMOX_USER": os.environ["PROXMOX_USER"],
        "PROXMOX_TOKEN_NAME": os.environ["PROXMOX_TOKEN_NAME"],
        "PROXMOX_TOKEN_VALUE": os.environ["PROXMOX_TOKEN_VALUE"],
        "PROXMOX_ALLOW_ELEVATED": "false",
        "PROXMOX_VERIFY_TLS": "false"
    }
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY
chmod 600 "${CONFIG_FILE}"
echo "完成。重启 AI Agent 后先做只读查询。"
