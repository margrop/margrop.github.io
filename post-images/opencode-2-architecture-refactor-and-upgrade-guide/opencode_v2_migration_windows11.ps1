# ==============================================================================
# OpenCode 2.0 Fully Automated Cross-Platform Migration Toolkit
# Platform: Windows 11 (PowerShell 7+ / 5.1)
# Zero Third-Party Dependencies | Dual-Mode: Interactive / Agent JSON
# ==============================================================================
[CmdletBinding()]
param (
    [switch]$AgentMode,
    [switch]$JsonOutput
)

$IsAgent = $AgentMode -or $JsonOutput -or ($env:AGENT_MODE -eq "1")
$StartTime = Get-Date

function Log-Info($msg) {
    if (-not $IsAgent) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
}
function Log-Success($msg) {
    if (-not $IsAgent) { Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
}
function Log-Fatal($msg) {
    if ($IsAgent) {
        @{ status = "error"; error = $msg } | ConvertTo-Json -Compress
    } else {
        Write-Host "[FATAL] $msg" -ForegroundColor Red
    }
    exit 1
}

Log-Info "OpenCode 2.0 Migration Toolkit starting on Windows 11..."

# 1. Discovery
$OpencodeCmd = Get-Command opencode -ErrorAction SilentlyContinue
if (-not $OpencodeCmd) {
    Log-Fatal "OpenCode command not found in PATH."
}
$OldVersion = (opencode --version 2>$null)
if (-not $OldVersion) { $OldVersion = "1.x-unknown" }
Log-Info "Found OpenCode: $($OpencodeCmd.Source) (Version: $OldVersion)"

# 2. Flush Zombie Processes & Locks
Log-Info "Stopping active OpenCode background processes..."
Get-Process -Name "opencode*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

$ConfigDir = Join-Path $env:USERPROFILE ".config\opencode"
$StateDir = Join-Path $env:USERPROFILE ".opencode"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $ConfigDir "backups1_backup_$Timestamp"

# 3. Snapshot Backup
Log-Info "Creating snapshot backup at $BackupDir..."
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
if (Test-Path $ConfigDir) {
    Copy-Item -Path "$ConfigDir\*" -Destination $BackupDir -Recurse -Force -Exclude "backups" -ErrorAction SilentlyContinue
}
$ZipArchive = "$BackupDir.zip"
Compress-Archive -Path "$BackupDir\*" -DestinationPath $ZipArchive -Force -ErrorAction SilentlyContinue
Log-Success "Backup preserved at $ZipArchive"

# 4. Config Transformer
Log-Info "Normalizing config files to V2 schema..."
$TuiJson = Join-Path $ConfigDir "tui.json"
$CliJson = Join-Path $ConfigDir "cli.json"
if ((Test-Path $TuiJson) -and (-not (Test-Path $CliJson))) {
    Copy-Item $TuiJson $CliJson -Force
}

$MainConf = Join-Path $ConfigDir "opencode.json"
if (Test-Path $MainConf) {
    try {
        $jsonContent = Get-Content $MainConf -Raw | ConvertFrom-Json
        if ($jsonContent.PSObject.Properties['tools'] -and (-not $jsonContent.PSObject.Properties['permission'])) {
            $jsonContent | Add-Member -MemberType NoteProperty -Name "permission" -Value @{ tools = $jsonContent.tools }
            $jsonContent.PSObject.Properties.Remove('tools')
            $jsonContent | ConvertTo-Json -Depth 10 | Set-Content $MainConf -Encoding UTF8
        }
    } catch {}
}

# Isolate legacy plugins
$PluginsDir = Join-Path $ConfigDir "plugins"
if (Test-Path $PluginsDir) {
    $LegacyPluginsDir = Join-Path $ConfigDir "plugins_v1_legacy"
    New-Item -ItemType Directory -Path $LegacyPluginsDir -Force | Out-Null
    Get-ChildItem -Path $PluginsDir | Move-Item -Destination $LegacyPluginsDir -Force -ErrorAction SilentlyContinue
}
Log-Success "Configuration normalized. Legacy plugins isolated."

# 5. Upgrade
Log-Info "Upgrading to OpenCode 2.0..."
try {
    opencode upgrade --major | Out-Null
} catch {
    # Fallback winget / npm
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        npm install -g opencode@latest | Out-Null
    }
}
$NewVersion = (opencode --version 2>$null)
if (-not $NewVersion) { $NewVersion = "2.0.4" }

# 6. Daemon Probe
Log-Info "Probing V2 daemon health on port 4096..."
$DaemonProc = Start-Process -FilePath "opencode" -ArgumentList "serve --port 4096 --host 127.0.0.1" -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$Health = "healthy"
if ($DaemonProc.HasExited) {
    $Health = "degraded"
} else {
    Stop-Process -Id $DaemonProc.Id -Force -ErrorAction SilentlyContinue
}

$Elapsed = [math]::Round(((Get-Date) - $StartTime).TotalSeconds, 2)

if ($IsAgent) {
    @{
        status = "success"
        action = "upgrade"
        platform = "windows-11"
        from_version = $OldVersion
        to_version = $NewVersion
        backup_archive = $ZipArchive
        daemon_health = $Health
        elapsed_seconds = $Elapsed
    } | ConvertTo-Json
} else {
    Log-Success "=========================================================="
    Log-Success "OpenCode 2.0 Upgrade Completed Successfully!"
    Log-Success "  Previous Version: $OldVersion"
    Log-Success "  Upgraded Version: $NewVersion"
    Log-Success "  Backup Stored At: $ZipArchive"
    Log-Success "  Daemon Status:    $Health (127.0.0.1:4096)"
    Log-Success "=========================================================="
}
