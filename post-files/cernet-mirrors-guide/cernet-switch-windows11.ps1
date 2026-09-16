<#
.SYNOPSIS
    Windows 11 CERNET Campus Network Joint Mirror Migration Script
.DESCRIPTION
    Configures Windows Package Manager (winget) and Python pip to use the CERNET
    aggregator. Built for native PowerShell 5.1/7+ with zero package dependencies.
.PARAMETER Check
    Performs system inspection only without altering settings.
.PARAMETER Apply
    Applies the mirror configuration (default action).
.PARAMETER Json
    Outputs structured JSON for AI Agent automation.
#>

[CmdletBinding()]
param (
    [switch]$Check,
    [switch]$Apply = $true,
    [switch]$Json
)

$ErrorActionPreference = "SilentlyContinue"
$cernetPypi = "https://mirrors.cernet.edu.cn/pypi/web/simple/"
$cernetWinget = "https://mirrors.cernet.edu.cn/winget-source"

# Probe connection and 302 redirection
$redirectNode = "unreachable"
try {
    $req = [System.Net.WebRequest]::Create($cernetPypi)
    $req.Method = "HEAD"
    $req.AllowAutoRedirect = $false
    $res = $req.GetResponse()
    if ($res.StatusCode -eq 302 -or $res.StatusCode -eq 301) {
        $redirectNode = $res.GetResponseHeader("Location")
    } else {
        $redirectNode = "direct"
    }
    $res.Close()
} catch {
    $redirectNode = "probe_failed"
}

$pipCurrent = (python -m pip config get global.index-url 2>$null)
$pipConfigured = ($pipCurrent -like "*mirrors.cernet.edu.cn*")
$wingetInstalled = ($null -ne (Get-Command "winget" -ErrorAction SilentlyContinue))

if ($Check) {
    $checkReport = [PSCustomObject]@{
        Platform = "Windows 11"
        PipConfigured = $pipConfigured
        CurrentPipSource = $pipCurrent
        WingetAvailable = $wingetInstalled
        RedirectNode = $redirectNode
    }

    if ($Json) {
        $checkReport | ConvertTo-Json -Compress
    } else {
        Write-Host "=== Windows 11 CERNET Mirror Inspection ===" -ForegroundColor Cyan
        Write-Host "Pip Status: $(if ($pipConfigured) { 'Configured for CERNET' } else { 'Other Mirror' })" -ForegroundColor White
        Write-Host "Current Pip URL: $pipCurrent" -ForegroundColor Gray
        Write-Host "Winget Available: $wingetInstalled" -ForegroundColor White
        Write-Host "Redirect Target: $redirectNode" -ForegroundColor Yellow
    }
    exit 0
}

$pipStatus = "skipped"
if ($null -ne (Get-Command "python" -ErrorAction SilentlyContinue)) {
    python -m pip config set global.index-url $cernetPypi | Out-Null
    python -m pip config set global.trusted-host "mirrors.cernet.edu.cn" | Out-Null
    $pipStatus = "success"
}

$wingetStatus = "skipped"
if ($wingetInstalled) {
    winget source remove winget 2>$null | Out-Null
    winget source add winget $cernetWinget --type "Microsoft.Rest" 2>$null | Out-Null
    $wingetStatus = "success"
}

$applyReport = [PSCustomObject]@{
    Status = "success"
    Platform = "Windows 11"
    PipConfig = $pipStatus
    WingetConfig = $wingetStatus
    RedirectTarget = $redirectNode
}

if ($Json) {
    $applyReport | ConvertTo-Json -Compress
} else {
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "[SUCCESS] Windows 11 environment configured to CERNET!" -ForegroundColor Green
    Write-Host "• Python pip Mirror: $pipStatus ($cernetPypi)" -ForegroundColor White
    Write-Host "• Winget Source: $wingetStatus" -ForegroundColor White
    Write-Host "• Dynamic Target: $redirectNode" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
}
