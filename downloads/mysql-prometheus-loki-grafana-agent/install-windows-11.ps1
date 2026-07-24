$ErrorActionPreference = "Stop"
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  winget install --exact --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
  Start-Process "$Env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
}
while (-not (docker info 2>$null)) { Write-Host "Waiting for Docker Desktop..."; Start-Sleep -Seconds 5 }
Set-Location $PSScriptRoot
if (-not (Test-Path .env)) {
  $root = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
  $reader = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
  $grafana = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
  "MYSQL_ROOT_PASSWORD=$root`nMYSQL_AGENT_PASSWORD=$reader`nGRAFANA_ADMIN_PASSWORD=$grafana`nGRAFANA_SERVICE_TOKEN=" | Set-Content -Encoding ascii .env
}
docker compose up -d --build
docker compose run --rm --entrypoint python agent-bridge /app/seed_demo.py
$config = @{ mcpServers = @{ "observability-lab" = @{ command = "docker"; args = @("compose", "-f", "$PSScriptRoot\docker-compose.yml", "run", "--rm", "-T", "agent-bridge") } } }
$config | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 agent-mcp.json
Start-Process "http://127.0.0.1:13000"
Write-Host "Agent MCP config: $PSScriptRoot\agent-mcp.json"
