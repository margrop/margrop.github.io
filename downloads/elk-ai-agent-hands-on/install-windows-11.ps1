$ErrorActionPreference = "Stop"
$Version = if ($env:ELASTIC_VERSION) { $env:ELASTIC_VERSION } else { "9.2.3" }
$HomeDir = Join-Path $HOME "elk-ai-agent"
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "winget is required" }
  winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
  Start-Process "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
  do { Start-Sleep -Seconds 4 } until (docker info 2>$null)
}
New-Item -ItemType Directory -Force "$HomeDir\pipeline", "$HomeDir\sample-logs" | Out-Null
@"
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:$Version
    environment: ["discovery.type=single-node", "xpack.security.enabled=false", "ES_JAVA_OPTS=-Xms768m -Xmx768m"]
    ports: ["127.0.0.1:9200:9200"]
    volumes: ["esdata:/usr/share/elasticsearch/data"]
    healthcheck: {test: ["CMD-SHELL", "curl -fsS http://localhost:9200/_cluster/health"], interval: 10s, timeout: 5s, retries: 30}
  kibana:
    image: docker.elastic.co/kibana/kibana:$Version
    environment: {ELASTICSEARCH_HOSTS: "http://elasticsearch:9200", XPACK_SECURITY_ENABLED: "false", TELEMETRY_ENABLED: "false"}
    ports: ["127.0.0.1:5601:5601"]
    depends_on: {elasticsearch: {condition: service_healthy}}
  logstash:
    image: docker.elastic.co/logstash/logstash:$Version
    volumes: ["./pipeline:/usr/share/logstash/pipeline:ro", "./sample-logs:/logs:ro"]
    depends_on: {elasticsearch: {condition: service_healthy}}
  mcp:
    image: docker.elastic.co/mcp/elasticsearch:latest
    command: ["http"]
    environment: {ES_URL: "http://elasticsearch:9200", ES_USERNAME: "elastic", ES_PASSWORD: "unused"}
    ports: ["127.0.0.1:8080:8080"]
    depends_on: {elasticsearch: {condition: service_healthy}}
volumes: {esdata: {}}
"@ | Set-Content -Encoding utf8 "$HomeDir\compose.yml"
'input { file { path => "/logs/app.jsonl" start_position => "beginning" sincedb_path => "/dev/null" codec => json mode => "read" exit_after_read => true } } filter { date { match => ["timestamp", "ISO8601"] target => "@timestamp" } } output { elasticsearch { hosts => ["http://elasticsearch:9200"] index => "app-logs" } stdout { codec => rubydebug } }' | Set-Content -Encoding utf8 "$HomeDir\pipeline\logstash.conf"
'{"timestamp":"2026-01-01T08:00:00Z","level":"INFO","service":"checkout","message":"order created","duration_ms":82,"status_code":200}`n{"timestamp":"2026-01-01T08:01:00Z","level":"ERROR","service":"payment","message":"gateway timeout","duration_ms":3021,"status_code":504}' | Set-Content -Encoding utf8 "$HomeDir\sample-logs\app.jsonl"
'{"mcpServers":{"elasticsearch":{"type":"streamable-http","url":"http://127.0.0.1:8080/mcp"}}}' | Set-Content -Encoding utf8 "$HomeDir\mcp.json"
Set-Location $HomeDir
docker compose up -d
Write-Host "Kibana: http://127.0.0.1:5601  MCP: http://127.0.0.1:8080/mcp  Config: $HomeDir\mcp.json"
