$ErrorActionPreference = "Stop"
$InstallDir = Join-Path $env:LOCALAPPDATA "mcp-proxmox"
$ConfigFile = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements }
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

$ProxmoxHost = Read-Host "Proxmox 地址（不含 https://）"
$ProxmoxUser = Read-Host "Proxmox 用户 [ai-agent@pve]"
if ([string]::IsNullOrWhiteSpace($ProxmoxUser)) { $ProxmoxUser = "ai-agent@pve" }
$TokenName = Read-Host "Token 名称 [mcp]"
if ([string]::IsNullOrWhiteSpace($TokenName)) { $TokenName = "mcp" }
$SecureToken = Read-Host "Token Secret" -AsSecureString
$TokenValue = [System.Net.NetworkCredential]::new("", $SecureToken).Password

New-Item -ItemType Directory -Force -Path (Split-Path $InstallDir), (Split-Path $ConfigFile) | Out-Null
if (Test-Path (Join-Path $InstallDir ".git")) { git -C $InstallDir pull --ff-only } else { git clone https://github.com/gilby125/mcp-proxmox.git $InstallDir }
npm --prefix $InstallDir install --omit=dev

$Config = @{}
if (Test-Path $ConfigFile) {
  try { $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json -AsHashtable } catch { $Config = @{} }
}
if (-not $Config.ContainsKey("mcpServers")) { $Config["mcpServers"] = @{} }
$Config["mcpServers"]["proxmox"] = @{
  command = "node"
  args = @((Join-Path $InstallDir "index.js"))
  env = @{
    PROXMOX_HOST = $ProxmoxHost
    PROXMOX_USER = $ProxmoxUser
    PROXMOX_TOKEN_NAME = $TokenName
    PROXMOX_TOKEN_VALUE = $TokenValue
    PROXMOX_ALLOW_ELEVATED = "false"
    PROXMOX_VERIFY_TLS = "false"
  }
}
$Config | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $ConfigFile
icacls $ConfigFile /inheritance:r /grant:r "${env:USERNAME}:(R,W)" | Out-Null
Write-Host "完成。重启 AI Agent 后先做只读查询。" -ForegroundColor Green
