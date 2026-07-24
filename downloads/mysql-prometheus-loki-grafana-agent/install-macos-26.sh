#!/usr/bin/env bash
set -euo pipefail
if ! command -v docker >/dev/null; then
  command -v brew >/dev/null || { echo "Install Homebrew or Docker Desktop first."; exit 1; }
  brew install --cask docker
  open -a Docker
fi
until docker info >/dev/null 2>&1; do echo "Waiting for Docker Desktop..."; sleep 4; done
cd "$(dirname "$0")"
if [[ ! -f .env ]]; then
  umask 077
  cat > .env <<EOF
MYSQL_ROOT_PASSWORD=$(openssl rand -hex 18)
MYSQL_AGENT_PASSWORD=$(openssl rand -hex 18)
GRAFANA_ADMIN_PASSWORD=$(openssl rand -hex 18)
GRAFANA_SERVICE_TOKEN=
EOF
fi
docker compose up -d --build
docker compose run --rm --entrypoint python agent-bridge /app/seed_demo.py
cat > agent-mcp.json <<EOF
{"mcpServers":{"observability-lab":{"command":"docker","args":["compose","-f","$PWD/docker-compose.yml","run","--rm","-T","agent-bridge"]}}}
EOF
open http://127.0.0.1:13000
echo "Agent MCP config: $PWD/agent-mcp.json"
