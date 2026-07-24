#!/usr/bin/env bash
set -euo pipefail
ELASTIC_VERSION="${ELASTIC_VERSION:-9.2.3}"
INSTALL_DIR="${ELK_HOME:-$HOME/elk-ai-agent}"
if ! command -v docker >/dev/null 2>&1; then
  command -v brew >/dev/null 2>&1 || { echo "Please install Homebrew first."; exit 1; }
  brew install --cask docker
  open -a Docker
  echo "Waiting for Docker Desktop..."
  until docker info >/dev/null 2>&1; do sleep 3; done
fi
mkdir -p "$INSTALL_DIR/pipeline" "$INSTALL_DIR/sample-logs"
cat >"$INSTALL_DIR/compose.yml" <<EOF
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:${ELASTIC_VERSION}
    environment: ["discovery.type=single-node", "xpack.security.enabled=false", "ES_JAVA_OPTS=-Xms768m -Xmx768m"]
    ports: ["127.0.0.1:9200:9200"]
    volumes: ["esdata:/usr/share/elasticsearch/data"]
    healthcheck: {test: ["CMD-SHELL", "curl -fsS http://localhost:9200/_cluster/health"], interval: 10s, timeout: 5s, retries: 30}
  kibana:
    image: docker.elastic.co/kibana/kibana:${ELASTIC_VERSION}
    environment: {ELASTICSEARCH_HOSTS: "http://elasticsearch:9200", XPACK_SECURITY_ENABLED: "false", TELEMETRY_ENABLED: "false"}
    ports: ["127.0.0.1:5601:5601"]
    depends_on: {elasticsearch: {condition: service_healthy}}
  logstash:
    image: docker.elastic.co/logstash/logstash:${ELASTIC_VERSION}
    volumes: ["./pipeline:/usr/share/logstash/pipeline:ro", "./sample-logs:/logs:ro"]
    depends_on: {elasticsearch: {condition: service_healthy}}
  mcp:
    image: docker.elastic.co/mcp/elasticsearch:latest
    command: ["http"]
    environment: {ES_URL: "http://elasticsearch:9200", ES_USERNAME: "elastic", ES_PASSWORD: "unused"}
    ports: ["127.0.0.1:8080:8080"]
    depends_on: {elasticsearch: {condition: service_healthy}}
volumes: {esdata: {}}
EOF
cat >"$INSTALL_DIR/pipeline/logstash.conf" <<'EOF'
input { file { path => "/logs/app.jsonl" start_position => "beginning" sincedb_path => "/dev/null" codec => json mode => "read" exit_after_read => true } }
filter { date { match => ["timestamp", "ISO8601"] target => "@timestamp" } mutate { remove_field => ["timestamp", "host"] } }
output { elasticsearch { hosts => ["http://elasticsearch:9200"] index => "app-logs" } stdout { codec => rubydebug } }
EOF
cat >"$INSTALL_DIR/sample-logs/app.jsonl" <<'EOF'
{"timestamp":"2026-01-01T08:00:00Z","level":"INFO","service":"checkout","message":"order created","duration_ms":82,"status_code":200}
{"timestamp":"2026-01-01T08:01:00Z","level":"ERROR","service":"payment","message":"gateway timeout","duration_ms":3021,"status_code":504}
EOF
chmod 644 "$INSTALL_DIR/pipeline/logstash.conf" "$INSTALL_DIR/sample-logs/app.jsonl"
cat >"$INSTALL_DIR/mcp.json" <<'EOF'
{"mcpServers":{"elasticsearch":{"type":"streamable-http","url":"http://127.0.0.1:8080/mcp"}}}
EOF
cd "$INSTALL_DIR"
docker compose up -d
printf '\nELK started. Kibana: http://127.0.0.1:5601  MCP: http://127.0.0.1:8080/mcp\nGeneric Agent config: %s/mcp.json\n' "$INSTALL_DIR"
