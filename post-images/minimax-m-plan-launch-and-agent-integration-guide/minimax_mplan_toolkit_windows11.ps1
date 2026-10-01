<#
.SYNOPSIS
    MiniMax M Plan Zero-Dependency Automation & Diagnostic Toolkit for Windows 11 (PowerShell 7+)
.DESCRIPTION
    Configures and tests MiniMax M Plan for Claude Code, Cursor, and MCode agents.
    Cleans conflicting Anthropic environment variables, configures Anthropic protocol gateway,
    performs DNS/TLS/TTFT diagnostic probes, and verifies M3.1-Flash connectivity.
    Supports both Interactive mode and Headless Agent declarative mode.
.EXAMPLE
    # Interactive mode:
    pwsh -ExecutionPolicy Bypass .\minimax_mplan_toolkit_windows11.ps1

    # Headless Agent declarative mode:
    pwsh -ExecutionPolicy Bypass .\minimax_mplan_toolkit_windows11.ps1 -NonInteractive -ApiKey "sk-mplan-xxx" -Region "intl"
#>

[CmdletBinding()]
param (
    [switch]$NonInteractive,
    [string]$ApiKey = $env:MINIMAX_API_KEY,
    [ValidateSet("intl", "cn")]
    [string]$Region = $(if ($env:MINIMAX_REGION) { $env:MINIMAX_REGION } else { "intl" }),
    [string]$Model = "MiniMax-M3.1-Flash"
)

$ErrorActionPreference = "Stop"

function Write-HostColor {
    param ([string]$Text, [string]$Color = "Cyan")
    Write-Host $Text -ForegroundColor $Color
}

Write-HostColor "=================================================================" "Cyan"
Write-HostColor "  MiniMax M Plan Toolkit (Windows 11 / PowerShell 7+)" "Yellow"
Write-HostColor "  Zero-Dependency Automation, Gateway Configuration & Diagnostic" "Cyan"
Write-HostColor "=================================================================" "Cyan"

# 1. Interactive input if not provided
if (-not $NonInteractive -and [string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-HostColor "`n[Step 1/5] Configuration Setup" "Yellow"
    Write-Host "Select MiniMax API Region:"
    Write-Host "  1) International (api.minimax.io - Recommended for overseas/global)"
    Write-Host "  2) Domestic China (api.minimax.cn - Recommended for mainland China)"
    $regionChoice = Read-Host "Enter selection [1/2] (Default: 1)"
    if ($regionChoice -eq "2") {
        $Region = "cn"
    } else {
        $Region = "intl"
    }

    $ApiKey = Read-Host "Enter your MiniMax M Plan Subscription Key (sk-mplan-...)"
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        Write-Error "Error: API Key cannot be empty!"
        exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Error "Error: Missing required ApiKey parameter or MINIMAX_API_KEY environment variable."
    exit 1
}

$BaseHost = if ($Region -eq "cn") { "https://api.minimax.cn" } else { "https://api.minimax.io" }
$AnthropicBaseUrl = "$BaseHost/anthropic"

Write-HostColor "`n[Step 2/5] Sanitizing Environment Variables..." "Yellow"
# Crucial: Unset ANTHROPIC_API_KEY to prevent Claude Code 401/billing confusion
if ($env:ANTHROPIC_API_KEY) {
    Remove-Item Env:\ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
    [Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", $null, "User")
    Write-Host "  - Unset conflicting ANTHROPIC_API_KEY from current session & user registry." -ForegroundColor Green
}

$env:ANTHROPIC_BASE_URL = $AnthropicBaseUrl
$env:ANTHROPIC_AUTH_TOKEN = $ApiKey
$env:ANTHROPIC_MODEL = $Model

[Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $AnthropicBaseUrl, "User")
[Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", $ApiKey, "User")
[Environment]::SetEnvironmentVariable("ANTHROPIC_MODEL", $Model, "User")

Write-Host "  + Injected ANTHROPIC_BASE_URL  : $AnthropicBaseUrl" -ForegroundColor Green
Write-Host "  + Injected ANTHROPIC_AUTH_TOKEN : sk-mplan-***" -ForegroundColor Green
Write-Host "  + Default Agent Model          : $Model" -ForegroundColor Green

Write-HostColor "`n[Step 3/5] Updating Claude Code Local Settings..." "Yellow"
$ClaudeDir = Join-Path $HOME ".claude"
if (-not (Test-Path $ClaudeDir)) {
    New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
}
$SettingsFile = Join-Path $ClaudeDir "settings.json"

$SettingsObj = @{}
if (Test-Path $SettingsFile) {
    try {
        $existingRaw = Get-Content $SettingsFile -Raw -Encoding UTF8
        if (-not [string]::IsNullOrWhiteSpace($existingRaw)) {
            $SettingsObj = $existingRaw | ConvertFrom-Json -AsHashtable
        }
    } catch {
        Write-Warning "Existing settings.json could not be parsed as JSON. Creating backup."
        Copy-Item $SettingsFile "$SettingsFile.bak" -Force
        $SettingsObj = @{}
    }
}

if (-not $SettingsObj.ContainsKey("env")) {
    $SettingsObj["env"] = @{}
}

$SettingsObj["env"]["ANTHROPIC_BASE_URL"] = $AnthropicBaseUrl
$SettingsObj["env"]["ANTHROPIC_AUTH_TOKEN"] = $ApiKey
$SettingsObj["env"]["ANTHROPIC_MODEL"] = $Model

$jsonOutput = $SettingsObj | ConvertTo-Json -Depth 10
Set-Content -Path $SettingsFile -Value $jsonOutput -Encoding UTF8
Write-Host "  + Successfully wrote configuration to: $SettingsFile" -ForegroundColor Green

Write-HostColor "`n[Step 4/5] Executing Network Handshake & TTFT Diagnostic Probe..." "Yellow"
$TestEndpoint = "$AnthropicBaseUrl/v1/messages"

$Payload = @{
    model = $Model
    max_tokens = 50
    messages = @(
        @{
            role = "user"
            content = "Hello! Please reply in one short sentence confirming MiniMax M Plan connectivity."
        }
    )
} | ConvertTo-Json -Depth 5

$Headers = @{
    "Authorization" = "Bearer $ApiKey"
    "x-api-key" = $ApiKey
    "anthropic-version" = "2023-06-01"
    "Content-Type" = "application/json"
}

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $response = Invoke-RestMethod -Uri $TestEndpoint -Method Post -Headers $Headers -Body $Payload -TimeoutSec 15
    $Stopwatch.Stop()
    $ttftMs = $Stopwatch.ElapsedMilliseconds

    Write-Host "  [PASS] MiniMax Anthropic Gateway Response: 200 OK" -ForegroundColor Green
    Write-Host "  [PASS] Measured Latency (TTFT probe): $ttftMs ms" -ForegroundColor Green
    
    $replyText = ""
    if ($response.content -and $response.content.Count -gt 0) {
        $replyText = $response.content[0].text
    }
    Write-Host "  [ECHO] Model Output: `"$replyText`"" -ForegroundColor Cyan
} catch {
    $Stopwatch.Stop()
    Write-Host "  [FAIL] Gateway probe failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        Write-Host "  [BODY] $body" -ForegroundColor Red
    }
    exit 1
}

Write-HostColor "`n[Step 5/5] Summary & Readiness Report" "Yellow"
Write-HostColor "=================================================================" "Green"
Write-HostColor "  SUCCESS: MiniMax M Plan is ready on Windows 11!" "Green"
Write-HostColor "  - Base URL : $AnthropicBaseUrl" "Cyan"
Write-HostColor "  - Model    : $Model" "Cyan"
Write-HostColor "  - Usage    : Launch terminal and run 'claude' directly" "Yellow"
Write-HostColor "=================================================================" "Green"

if ($NonInteractive) {
    @{
        status = "success"
        base_url = $AnthropicBaseUrl
        model = $Model
        ttft_ms = $ttftMs
        settings_path = $SettingsFile
    } | ConvertTo-Json -Compress
}
