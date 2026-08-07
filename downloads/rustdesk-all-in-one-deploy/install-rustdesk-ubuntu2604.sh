#!/usr/bin/env bash
set -euo pipefail

PUBLIC_HOST="${1:-}"
API_URL="${2:-}"
WS_URL="${3:-}"
INSTALL_DIR="${RUSTDESK_INSTALL_DIR:-/opt/rustdesk-all-in-one}"
IMAGE="${RUSTDESK_IMAGE:-lejianwen/rustdesk-server-s6:latest}"

if [[ -z "$PUBLIC_HOST" || "$PUBLIC_HOST" == *"://"* || "$PUBLIC_HOST" == *"/"* ]]; then
  echo "Usage: sudo bash $0 rustdesk.example.com [https://api.example.com] [wss://ws.example.com]" >&2
  exit 2
fi

API_URL="${API_URL:-http://${PUBLIC_HOST}:21114}"
WS_URL="${WS_URL:-ws://${PUBLIC_HOST}:21114}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this installer with sudo so it can use ${INSTALL_DIR}." >&2
  exit 3
fi

if ! command -v docker >/dev/null 2>&1; then
  apt-get update
  if ! DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-v2; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-plugin
  fi
  systemctl enable --now docker
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 is required." >&2
  exit 4
fi

install -d -m 0750 "$INSTALL_DIR/data/server" "$INSTALL_DIR/data/api" "$INSTALL_DIR/logs"

cat >"$INSTALL_DIR/.env" <<EOF
PUBLIC_HOST=${PUBLIC_HOST}
API_URL=${API_URL}
WS_URL=${WS_URL}
RUSTDESK_IMAGE=${IMAGE}
EOF
chmod 0600 "$INSTALL_DIR/.env"

cat >"$INSTALL_DIR/compose.yaml" <<'YAML'
services:
  rustdesk:
    image: ${RUSTDESK_IMAGE}
    container_name: rustdesk-server-s6
    restart: unless-stopped
    ports:
      - "21114:21114/tcp"
      - "21115:21115/tcp"
      - "21116:21116/tcp"
      - "21116:21116/udp"
      - "21117:21117/tcp"
      - "21118:21118/tcp"
      - "21119:21119/tcp"
    environment:
      RELAY: ${PUBLIC_HOST}:21117
      ENCRYPTED_ONLY: "1"
      MUST_LOGIN: "N"
      TZ: Asia/Shanghai
      RUSTDESK_API_LANG: zh-CN
      RUSTDESK_API_ADMIN_TITLE: RustDesk Console
      RUSTDESK_API_RUSTDESK_ID_SERVER: ${PUBLIC_HOST}:21116
      RUSTDESK_API_RUSTDESK_RELAY_SERVER: ${PUBLIC_HOST}:21117
      RUSTDESK_API_RUSTDESK_API_SERVER: ${API_URL}
      RUSTDESK_API_RUSTDESK_WS_HOST: ${WS_URL}
      RUSTDESK_API_KEY_FILE: /data/id_ed25519.pub
      RUSTDESK_API_APP_TOKEN_EXPIRE: 168h
    volumes:
      - ./data/server:/data
      - ./data/api:/app/data
      - ./logs:/app/runtime
YAML

cd "$INSTALL_DIR"
docker compose config >/dev/null
docker compose pull
docker compose up -d
docker compose ps

echo
echo "Deployment directory: $INSTALL_DIR"
echo "Admin/API URL: $API_URL"
echo "ID server: ${PUBLIC_HOST}:21116"
echo "Relay server: ${PUBLIC_HOST}:21117"
echo "Public key file: $INSTALL_DIR/data/server/id_ed25519.pub"
echo "Review the initial password in: docker compose logs --tail=200 rustdesk"
echo "Open only the required firewall ports and change the initial admin password immediately."
