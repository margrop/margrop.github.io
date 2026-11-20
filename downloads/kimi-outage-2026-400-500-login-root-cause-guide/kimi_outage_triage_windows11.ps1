<#
.SYNOPSIS
  Kimi / Moonshot Outage Triage & Recovery Toolkit (Windows 11)
.DESCRIPTION
  Zero-dependency PowerShell diagnostic & safe self-healing script for Windows 11.
  Directly probes Moonshot public status & API planes without third-party APIs,
  checks local Kimi / Claude / Codex configs and proxy variables, and supports both
  Human Interactive Dashboard and AI Agent JSON modes (-Auto -Json).
#>
[CmdletBinding()]
param(
    [switch]$Auto,
    [switch]$Json,
    [ValidateSet("cn", "intl", "all")]
    [string]$Region = "all",
    [string]$ApiKey = $(if ($env:KIMI_API_KEY) { $env:KIMI_API_KEY } else { $env:MOONSHOT_API_KEY }),
    [switch]$Fix,
    [switch]$Clean,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ($Help) {
    Write-Output "Usage: powershell -ExecutionPolicy Bypass -File .\kimi_outage_triage_windows11.ps1 [-Auto] [-Json] [-Region cn|intl|all] [-ApiKey <key>] [-Fix] [-Clean]"
    exit 0
}

$Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$OsInfo = "Windows 11 (Build $([System.Environment]::OSVersion.Version.Build))"
$BackupRoot = Join-Path $HOME ".kimi-triage-backups"

function Get-MaskedKey([string]$Key) {
    if ([string]::IsNullOrEmpty($Key)) { return "not-set" }
    if ($Key.Length -le 10) { return "***masked***" }
    return "$($Key.Substring(0,6))...$($Key.Substring($Key.Length - 4))"
}

if ($Clean) {
    $Restored = 0
    $LatestDir = Join-Path $BackupRoot "latest"
    if (Test-Path $LatestDir) {
        $Map = @{
            "kimi-config.toml" = (Join-Path $HOME ".kimi\config.toml")
            "claude-settings.json" = (Join-Path $HOME ".claude\settings.json")
            "codex-config.toml" = (Join-Path $HOME ".codex\config.toml")
        }
        foreach ($item in $Map.GetEnumerator()) {
            $bakPath = Join-Path $LatestDir $item.Key
            if (Test-Path $bakPath) {
                $parent = Split-Path -Parent $item.Value
                if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                Copy-Item -Path $bakPath -Destination $item.Value -Force
                $Restored++
            }
        }
    }
    if ($Json) {
        @{ status = "ok"; action = "clean"; restored_files = $Restored } | ConvertTo-Json -Compress
    } else {
        Write-Host "[OK] Restored $Restored backed-up config file(s) from $LatestDir" -ForegroundColor Green
    }
    exit 0
}

$UpstreamIndicator = "unreachable"
$UpstreamDesc = "Unable to fetch status.moonshot.cn"
$Degraded = @()
$LatestIncident = ""

try {
    $sum = Invoke-RestMethod -Uri "https://status.moonshot.cn/api/v2/summary.json" -TimeoutSec 8
    $UpstreamIndicator = $sum.status.indicator
    $UpstreamDesc = $sum.status.description
    foreach ($comp in $sum.components) {
        if ($comp.status -ne "operational") {
            $Degraded += "$($comp.name):$($comp.status)"
        }
    }
} catch {}

try {
    $incs = Invoke-RestMethod -Uri "https://status.moonshot.cn/api/v2/incidents.json" -TimeoutSec 8
    if ($incs.incidents -and $incs.incidents.Count -gt 0) {
        $top = $incs.incidents[0]
        $LatestIncident = "$($top.created_at) | $($top.name) | $($top.status)"
    }
} catch {}

function Invoke-EndpointProbe {
    param([string]$Url, [string]$Method, [string]$Body, [hashtable]$Headers)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $code = "000"
    try {
        $params = @{
            Uri = $Url
            Method = $Method
            TimeoutSec = 8
            Headers = $Headers
            UseBasicParsing = $true
        }
        if ($Method -eq "POST" -and $Body) {
            $params["Body"] = $Body
            $params["ContentType"] = "application/json"
        }
        $resp = Invoke-WebRequest @params
        $code = [string][int]$resp.StatusCode
    } catch {
        if ($_.Exception.Response) {
            $code = [string][int]$_.Exception.Response.StatusCode
        }
    }
    $sw.Stop()
    return @{ http = $code; latency_ms = [int]$sw.ElapsedMilliseconds }
}

$cnHeaders = @{ "User-Agent" = "kimi-triage/1.0" }
if ($ApiKey) { $cnHeaders["Authorization"] = "Bearer $ApiKey" }
$codeHeaders = @{ "User-Agent" = "kimi-triage/1.0" }
if ($ApiKey) { $codeHeaders["x-api-key"] = $ApiKey }

$WebProbe = Invoke-EndpointProbe -Url "https://www.kimi.com/" -Method "GET" -Body "" -Headers @{ "User-Agent" = "Mozilla/5.0" }
$AuthProbe = Invoke-EndpointProbe -Url "https://www.kimi.com/apiv2/kimi.gateway.storage.v1.StorageService/GetUserStorageQuota" -Method "POST" -Body "{}" -Headers @{ "User-Agent" = "Mozilla/5.0" }
$CnApiProbe = Invoke-EndpointProbe -Url "https://api.moonshot.cn/v1/chat/completions" -Method "POST" -Body '{"model":"kimi-k3.1-pro","messages":[{"role":"user","content":"ping"}]}' -Headers $cnHeaders
$CnCodeProbe = Invoke-EndpointProbe -Url "https://api.kimi.com/coding/v1/messages" -Method "POST" -Body '{"model":"kimi-for-coding","max_tokens":4,"messages":[{"role":"user","content":"ping"}]}' -Headers $codeHeaders
$IntlCodeProbe = Invoke-EndpointProbe -Url "https://api.kimi.ai/coding/v1/messages" -Method "POST" -Body '{"model":"kimi-for-coding","max_tokens":4,"messages":[{"role":"user","content":"ping"}]}' -Headers $codeHeaders
$AltStatusProbe = Invoke-EndpointProbe -Url "https://status.kimi.com/" -Method "GET" -Body "" -Headers @{ "User-Agent" = "Mozilla/5.0" }

$ProxySet = [bool]($env:HTTP_PROXY -or $env:HTTPS_PROXY -or $env:http_proxy -or $env:https_proxy)
$K2Hits = 0; $TempHits = 0; $BaseMismatch = 0; $SessionWarn = 0

foreach ($cfg in @((Join-Path $HOME ".kimi\config.toml"), (Join-Path $HOME ".claude\settings.json"), (Join-Path $HOME ".codex\config.toml"))) {
    if (Test-Path $cfg) {
        $txt = Get-Content $cfg -Raw -ErrorAction SilentlyContinue
        if ($txt -match "kimi-k2|moonshot-v1-") { $K2Hits++ }
        if ($txt -match '"temperature"\s*:\s*0\.[0-9]+|temperature\s*=\s*0\.[0-9]+') { $TempHits++ }
        if (($txt -match "api\.kimi\.ai") -and ($txt -match "api\.moonshot\.cn")) { $BaseMismatch++ }
    }
}

$SessDir = Join-Path $HOME ".kimi\sessions"
if (Test-Path $SessDir) {
    $SessionWarn = (Get-ChildItem -Path $SessDir -Recurse -File -Filter "*.jsonl" -ErrorAction SilentlyContinue | Where-Object { $_.Length -eq 0 }).Count
}

$Diagnosis = "HEALTHY"
if ($UpstreamIndicator -notin @("none", "operational", "unreachable")) {
    $Diagnosis = "UPSTREAM_PARTIAL_OUTAGE"
}
if ($CnApiProbe.http -like "5*" -or $CnCodeProbe.http -like "5*") {
    $Diagnosis = "UPSTREAM_5XX_DEGRADED"
} elseif ($IntlCodeProbe.http -eq "403") {
    $Diagnosis = "WAF_OR_UA_BLOCK_1010"
} elseif ($K2Hits -gt 0 -or $TempHits -gt 0 -or $BaseMismatch -gt 0) {
    $Diagnosis = "LOCAL_CLIENT_400_RISK"
}

$ActionsTaken = @()
if ($Fix) {
    $LatestDir = Join-Path $BackupRoot "latest"
    New-Item -ItemType Directory -Path $LatestDir -Force | Out-Null
    $Map = @{
        "kimi-config.toml" = (Join-Path $HOME ".kimi\config.toml")
        "claude-settings.json" = (Join-Path $HOME ".claude\settings.json")
        "codex-config.toml" = (Join-Path $HOME ".codex\config.toml")
    }
    foreach ($item in $Map.GetEnumerator()) {
        if (Test-Path $item.Value) {
            Copy-Item -Path $item.Value -Destination (Join-Path $LatestDir $item.Key) -Force
        }
    }
    try { Clear-DnsClientCache; $ActionsTaken += "flushed_windows_dns_cache" } catch {}
    if ((Test-Path $SessDir) -and $SessionWarn -gt 0) {
        $QuarDir = Join-Path $BackupRoot "empty-sessions"
        New-Item -ItemType Directory -Path $QuarDir -Force | Out-Null
        Get-ChildItem -Path $SessDir -Recurse -File -Filter "*.jsonl" -ErrorAction SilentlyContinue | Where-Object { $_.Length -eq 0 } | Move-Item -Destination $QuarDir -Force
        $ActionsTaken += "quarantined_zero_byte_sessions"
    }
}

$Recs = @()
if ($UpstreamIndicator -notin @("none", "operational")) {
    $Recs += "UPSTREAM_DEGRADED: Monitor https://status.moonshot.cn and avoid rapid blind retries."
}
if ($CnApiProbe.http -like "5*" -or $CnCodeProbe.http -like "5*") {
    $Recs += "RETRY_WITH_BACKOFF: Apply exponential backoff (2s, 4s, 8s) and rotate corrupted session."
}
if ($IntlCodeProbe.http -eq "403") {
    $Recs += "WAF_1010: Do not send generic scripting User-Agent to api.kimi.ai; check proxy/UA headers."
}
if ($K2Hits -gt 0 -or $TempHits -gt 0 -or $BaseMismatch -gt 0) {
    $Recs += "FIX_CLIENT_400: Remove deprecated K2 IDs, non-0.6/1.0 temperature overrides, or CN/Intl key mixups."
}
if ($Recs.Count -eq 0) {
    $Recs += "HEALTHY_OR_UNAUTHENTICATED_OK: Set KIMI_API_KEY and re-run if testing authenticated chat."
}

if ($Json) {
    $out = [ordered]@{
        timestamp = $Timestamp
        os = $OsInfo
        api_key_masked = (Get-MaskedKey $ApiKey)
        upstream_status = [ordered]@{
            indicator = $UpstreamIndicator
            description = $UpstreamDesc
            degraded_components = $Degraded
            latest_incident = $LatestIncident
            status_kimi_com_http = $AltStatusProbe.http
        }
        endpoint_probes = [ordered]@{
            www_kimi_com = $WebProbe
            kimi_auth_probe = @{ http = $AuthProbe.http }
            api_moonshot_cn = $CnApiProbe
            api_kimi_com_coding = $CnCodeProbe
            api_kimi_ai_coding = $IntlCodeProbe
        }
        local_audit = [ordered]@{
            proxy_env_active = $ProxySet
            legacy_k2_config_hits = $K2Hits
            temperature_override_hits = $TempHits
            cn_intl_endpoint_mix = $BaseMismatch
            zero_byte_session_files = $SessionWarn
        }
        diagnosis = $Diagnosis
        actions_taken = $ActionsTaken
        recommended_actions = $Recs
    }
    $out | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   Kimi / Moonshot 400/500/Login Triage Probe (Windows 11)            " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " Check Time : $Timestamp"
Write-Host " OS Info    : $OsInfo"
Write-Host " API Key    : $(Get-MaskedKey $ApiKey)"
Write-Host ""
Write-Host "[1/4] Official Status Planes (status.moonshot.cn vs status.kimi.com)" -ForegroundColor White
Write-Host "  - status.moonshot.cn : $UpstreamIndicator ($UpstreamDesc)" -ForegroundColor Yellow
Write-Host "  - Degraded Comps     : $(if ($Degraded.Count -gt 0) { $Degraded -join ', ' } else { 'none' })" -ForegroundColor Red
Write-Host "  - Latest Incident    : $LatestIncident"
Write-Host "  - status.kimi.com    : HTTP $($AltStatusProbe.http)"
Write-Host ""
Write-Host "[2/4] Live Web / Auth / API Endpoint Probes" -ForegroundColor White
Write-Host "  - www.kimi.com           : HTTP $($WebProbe.http) ($($WebProbe.latency_ms) ms)"
Write-Host "  - Auth StorageQuota      : HTTP $($AuthProbe.http)"
Write-Host "  - api.moonshot.cn        : HTTP $($CnApiProbe.http) ($($CnApiProbe.latency_ms) ms)"
Write-Host "  - api.kimi.com/coding    : HTTP $($CnCodeProbe.http) ($($CnCodeProbe.latency_ms) ms)"
Write-Host "  - api.kimi.ai/coding     : HTTP $($IntlCodeProbe.http) ($($IntlCodeProbe.latency_ms) ms)"
Write-Host ""
Write-Host "[3/4] Local 400 Trap & Proxy Audit" -ForegroundColor White
Write-Host "  - Proxy Env Active       : $ProxySet"
Write-Host "  - Legacy K2 References   : $K2Hits"
Write-Host "  - Temperature Overrides  : $TempHits"
Write-Host "  - CN/Intl URL Mixups     : $BaseMismatch"
Write-Host "  - 0-byte Session Files   : $SessionWarn"
Write-Host ""
Write-Host "[4/4] Overall Diagnosis: $Diagnosis" -ForegroundColor Cyan
if ($Fix) {
    Write-Host "  - Actions Taken: $(if ($ActionsTaken.Count -gt 0) { $ActionsTaken -join ', ' } else { 'none' })" -ForegroundColor Green
}
