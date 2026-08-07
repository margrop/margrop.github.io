[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9.-]+$')]
    [string]$PublicHost,

    [string]$ApiUrl = '',
    [string]$WsUrl = '',
    [string]$InstallDir = "$HOME\rustdesk-all-in-one",
    [string]$Image = 'lejianwen/rustdesk-server-s6:latest'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker Desktop is required. Install and start it before running this script.'
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Desktop is installed but its engine is not running.'
}

docker compose version *> $null
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Compose v2 is required.'
}

if ([string]::IsNullOrWhiteSpace($ApiUrl)) {
    $ApiUrl = "http://${PublicHost}:21114"
}
if ([string]::IsNullOrWhiteSpace($WsUrl)) {
    $WsUrl = "ws://${PublicHost}:21114"
}

$null = New-Item -ItemType Directory -Force -Path $InstallDir
$null = New-Item -ItemType Directory -Force -Path "$InstallDir\data\server"
$null = New-Item -ItemType Directory -Force -Path "$InstallDir\data\api"
$null = New-Item -ItemType Directory -Force -Path "$InstallDir\logs"

@"
PUBLIC_HOST=$PublicHost
API_URL=$ApiUrl
WS_URL=$WsUrl
RUSTDESK_IMAGE=$Image
"@ | Set-Content -Encoding utf8 -Path "$InstallDir\.env"

@'
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
'@ | Set-Content -Encoding utf8 -Path "$InstallDir\compose.yaml"

Push-Location $InstallDir
try {
    docker compose config *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Generated Compose configuration is invalid.' }
    docker compose pull
    docker compose up -d
    docker compose ps
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host "Deployment directory: $InstallDir"
Write-Host "Admin/API URL: $ApiUrl"
Write-Host "ID server: ${PublicHost}:21116"
Write-Host "Relay server: ${PublicHost}:21117"
Write-Host 'Use this setup for a lab or an always-on Windows PC. Ubuntu Server is preferable for public production hosting.'
