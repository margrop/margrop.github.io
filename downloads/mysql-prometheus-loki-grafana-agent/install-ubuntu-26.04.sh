#!/usr/bin/env bash
set -euo pipefail
if ! command -v docker >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y docker.io docker-compose-v2 openssl
  sudo systemctl enable --now docker
fi
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
DOCKER=(docker)
docker info >/dev/null 2>&1 || DOCKER=(sudo docker)
"${DOCKER[@]}" compose up -d --build
"${DOCKER[@]}" compose run --rm --entrypoint python agent-bridge /app/seed_demo.py
cat > agent-mcp.json <<EOF
{"mcpServers":{"observability-lab":{"command":"docker","args":["compose","-f","$PWD/docker-compose.yml","run","--rm","-T","agent-bridge"]}}}
EOF
"${DOCKER[@]}" compose ps
echo "Grafana: http://127.0.0.1:13000"
echo "Prometheus: http://127.0.0.1:19090"
echo "Agent MCP config: $PWD/agent-mcp.json"
