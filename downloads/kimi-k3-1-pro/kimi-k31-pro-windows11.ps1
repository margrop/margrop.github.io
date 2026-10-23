<#
.SYNOPSIS
  Kimi K3.1 Pro & Highspeed One-Click Migration, Probe & Agent Config Script
  Target OS : Windows 11 (PowerShell 5.1+ / PowerShell 7+, zero dependencies)
#>
[CmdletBinding()]
param(
    [ValidateSet("kimi-k3.1-pro", "kimi-k3.1-pro-highspeed")]
    [string]$Model = "kimi-k3.1-pro",

    [ValidateSet("cn", "global")]
    [string]$Region = "cn",

    [string]$ApiKey = $env:MOONSHOT_API_KEY,
    [string]$ScanDir = "",
    [switch]$VerifyApi,
    [switch]$ApplyClaude,
    [switch]$ApplyCodex,
    [switch]$Clean,
    [switch]$AgentMode,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    Write-Output "Usage: powershell -ExecutionPolicy Bypass -File .\kimi-k31-pro-windows11.ps1 [-Model kimi-k3.1-pro|kimi-k3.1-pro-highspeed] [-Region cn|global] [-ScanDir <path>] [-VerifyApi] [-ApplyClaude] [-ApplyCodex] [-Clean] [-AgentMode]"
    exit 0
}

$BaseHost = if ($Region -eq "global") { "api.moonshot.ai" } else { "api.moonshot.cn" }
$OpenAiBase = "https://$BaseHost/v1"
$AnthropicBase = "https://$BaseHost/anthropic"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

function Get-MaskedKey([string]$Key) {
    if ([string]::IsNullOrEmpty($Key)) { return "not-set" }
    if ($Key.Length -le 10) { return "***masked***" }
    return "$($Key.Substring(0,6))...$($Key.Substring($Key.Length - 4))"
}

function Write-Info([string]$Msg) {
    if (-not $AgentMode) {
        Write-Host "[INFO] $Msg"
    }
}

$ScanK2Hits = 0
$ScanTempHits = 0
$ScanThinkingHits = 0
$ScanImageUrlHits = 0

if ($ScanDir -and (-not $Clean)) {
    if (Test-Path $ScanDir) {
        Write-Info "Scanning directory for K2 -> K3.1 Pro migration risks: $ScanDir"
        $files = Get-ChildItem -Path $ScanDir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch "(\\.git|node_modules|dist|build|public|\\.venv|venv)" -and $_.Length -lt 2097152 }
        if ($files) {
            $ScanK2Hits = ($files | Select-String -Pattern "kimi-k2(\.[0-9]+|-thinking|-turbo)?|moonshot-v1-(8k|32k|128k)" -ErrorAction SilentlyContinue | Measure-Object).Count
            $ScanTempHits = ($files | Select-String -Pattern "\"temperature\"\s*:\s*0\.[0-9]+" -ErrorAction SilentlyContinue | Measure-Object).Count
            $ScanThinkingHits = ($files | Select-String -Pattern "\"thinking\"\s*:\s*\{" -ErrorAction SilentlyContinue | Measure-Object).Count
            $ScanImageUrlHits = ($files | Select-String -Pattern "\"image_url\"\s*:\s*\{[^}]*https?://" -ErrorAction SilentlyContinue | Measure-Object).Count
        }
        Write-Info "  - Legacy K2 / moonshot-v1 model IDs : $ScanK2Hits"
        Write-Info "  - Locked temperature != 1.0 hits    : $ScanTempHits"
        Write-Info "  - Deprecated thinking dict hits     : $ScanThinkingHits"
        Write-Info "  - Remote HTTP image_url hits        : $ScanImageUrlHits"
    }
}

$ProbeHttpCode = "skipped"
$ProbeLatencyMs = 0
$ApiTestStatus = "skipped"

if ($VerifyApi -and (-not $Clean)) {
    Write-Info "Probing TLS connectivity to $OpenAiBase/models ..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-WebRequest -Uri "$OpenAiBase/models" -Method Get -TimeoutSec 8 -UseBasicParsing -ErrorAction Stop
        $ProbeHttpCode = [string][int]$resp.StatusCode
    } catch {
        if ($_.Exception.Response) {
            $ProbeHttpCode = [string][int]$_.Exception.Response.StatusCode
        } else {
            $ProbeHttpCode = "000"
        }
    }
    $sw.Stop()
    $ProbeLatencyMs = [int]$sw.ElapsedMilliseconds
    Write-Info "Endpoint $BaseHost responded with HTTP $ProbeHttpCode ($ProbeLatencyMs ms)"

    if (-not [string]::IsNullOrEmpty($ApiKey)) {
        Write-Info "Testing live chat completion on $Model (reasoning_effort=low) ..."
        try {
            $body = @{
                model = $Model
                messages = @(@{ role = "user"; content = "Reply with OK" })
                reasoning_effort = "low"
                max_tokens = 32
            } | ConvertTo-Json -Depth 5
            $apiResp = Invoke-RestMethod -Uri "$OpenAiBase/chat/completions" -Method Post -Headers @{ Authorization = "Bearer $ApiKey" } -ContentType "application/json" -Body $body -TimeoutSec 15
            if ($null -ne $apiResp.choices) {
                $ApiTestStatus = "ok"
                Write-Info "Live API test succeeded for $Model."
            } else {
                $ApiTestStatus = "error"
            }
        } catch {
            $ApiTestStatus = "error"
            Write-Info "Live API test failed or returned error payload."
        }
    }
}

$ClaudeStatus = "unchanged"
$CodexStatus = "unchanged"
$ClaudeDir = Join-Path $HOME ".claude"
$ClaudeSettings = Join-Path $ClaudeDir "settings.json"
$CodexDir = Join-Path $HOME ".codex"
$CodexConfig = Join-Path $CodexDir "config.toml"

if ($Clean) {
    $latestClaudeBak = Get-ChildItem -Path $ClaudeDir -Filter "settings.json.bak.*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestClaudeBak) {
        Copy-Item $latestClaudeBak.FullName $ClaudeSettings -Force
        $ClaudeStatus = "restored_backup"
        Write-Info "Restored Claude settings from $($latestClaudeBak.FullName)"
    }
    $latestCodexBak = Get-ChildItem -Path $CodexDir -Filter "config.toml.bak.*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestCodexBak) {
        Copy-Item $latestCodexBak.FullName $CodexConfig -Force
        $CodexStatus = "restored_backup"
        Write-Info "Restored Codex config from $($latestCodexBak.FullName)"
    }
} else {
    if ($ApplyClaude) {
        New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
        if (Test-Path $ClaudeSettings) {
            Copy-Item $ClaudeSettings "$ClaudeSettings.bak.$Timestamp" -Force
            Write-Info "Backed up existing Claude config to $ClaudeSettings.bak.$Timestamp"
        }
        $keyVal = if ([string]::IsNullOrEmpty($ApiKey)) { "YOUR_MOONSHOT_API_KEY" } else { $ApiKey }
        $claudeObj = @{
            env = @{
                ANTHROPIC_BASE_URL = $AnthropicBase
                ANTHROPIC_AUTH_TOKEN = $keyVal
                ANTHROPIC_MODEL = $Model
                ANTHROPIC_DEFAULT_OPUS_MODEL = $Model
                ANTHROPIC_DEFAULT_SONNET_MODEL = $Model
                ANTHROPIC_DEFAULT_HAIKU_MODEL = $Model
                CLAUDE_CODE_SUBAGENT_MODEL = $Model
                CLAUDE_CODE_AUTO_COMPACT_WINDOW = "1000000"
                ENABLE_TOOL_SEARCH = "false"
            }
        }
        $claudeObj | ConvertTo-Json -Depth 5 | Set-Content -Path $ClaudeSettings -Encoding UTF8
        $ClaudeStatus = "configured"
        Write-Info "Updated $ClaudeSettings for $Model (1M context window enabled)."
    }

    if ($ApplyCodex) {
        New-Item -ItemType Directory -Path $CodexDir -Force | Out-Null
        if (Test-Path $CodexConfig) {
            Copy-Item $CodexConfig "$CodexConfig.bak.$Timestamp" -Force
            Write-Info "Backed up existing Codex config to $CodexConfig.bak.$Timestamp"
        }
        $toml = @"
# KIMI-K31-PRO-BEGIN
model_provider = "kimi"
model = "$Model"
model_context_window = 1048576
model_auto_compact_token_limit = 900000

[model_providers.kimi]
name = "Kimi K3.1 Pro ($Region)"
base_url = "$OpenAiBase"
env_key = "MOONSHOT_API_KEY"
wire_api = "responses"
# KIMI-K31-PRO-END
"@
        Set-Content -Path $CodexConfig -Value $toml -Encoding UTF8
        $CodexStatus = "configured"
        Write-Info "Updated $CodexConfig for $Model (wire_api=responses, 1M context)."
    }
}

if ($AgentMode) {
    $report = @{
        status = "ok"
        os = "windows-11"
        model = $Model
        region = $Region
        endpoint = $BaseHost
        api_key_masked = (Get-MaskedKey $ApiKey)
        scan = @{
            k2_model_hits = $ScanK2Hits
            locked_temperature_hits = $ScanTempHits
            deprecated_thinking_hits = $ScanThinkingHits
            http_image_url_hits = $ScanImageUrlHits
        }
        probe = @{
            http_code = $ProbeHttpCode
            latency_ms = $ProbeLatencyMs
            live_api_status = $ApiTestStatus
        }
        config = @{
            claude_code = $ClaudeStatus
            codex_cli = $CodexStatus
        }
    }
    Write-Output ($report | ConvertTo-Json -Compress -Depth 5)
} else {
    Write-Info "Done. Model=$Model, Region=$Region ($BaseHost), Key=$(Get-MaskedKey $ApiKey)"
}
