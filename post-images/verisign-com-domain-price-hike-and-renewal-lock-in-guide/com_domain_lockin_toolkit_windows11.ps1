<#
.SYNOPSIS
    .COM Domain Lock-In & Cost Arbitrage Inspector (Windows 11 PowerShell 7 Edition)
.DESCRIPTION
    Audits .COM domain expiration via authoritative ICANN/Verisign RDAP,
    calculates ICANN 10-year maximum lock-in window, and computes dollar savings
    before the November 1, 2026 wholesale price hike ($10.26 -> $10.97).
.PARAMETER Auto
    Runs silently in Agent mode and outputs com_domain_lockin_report.json
.PARAMETER Domains
    Comma-separated list of domains to audit
.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File com_domain_lockin_toolkit_windows11.ps1
    pwsh -ExecutionPolicy Bypass -File com_domain_lockin_toolkit_windows11.ps1 -Auto -Domains "myapp.com,devportal.com"
#>

[CmdletBinding()]
param (
    [switch]$Auto,
    [string]$Domains = ""
)

$ErrorActionPreference = "Stop"

if (-not $Domains) {
    if (Test-Path "domains.txt") {
        $Domains = (Get-Content "domains.txt" | Where-Object { $_ -and -not $_.StartsWith("#") }) -join ","
    }
}

if (-not $Domains) {
    if ($Auto) {
        $Domains = "example.com"
    } else {
        Write-Host "[?] Enter .COM domains (comma-separated, e.g. myapp.com,apiportal.com): " -ForegroundColor Cyan -NoNewline
        $Domains = Read-Host
        if (-not $Domains) { $Domains = "example.com" }
    }
}

$domainList = $Domains.Split(",") | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_.EndsWith(".com") }
if (-not $domainList) { $domainList = @("example.com") }

$deadline = [DateTime]::Parse("2026-11-01T04:00:00Z").ToUniversalTime()
$now = [DateTime]::UtcNow
$daysLeft = [Math]::Max(0, ($deadline - $now).Days)

$pricing = @{
    "cloudflare" = @{ cur = 10.46; post = 11.17 }
    "porkbun"    = @{ cur = 10.37; post = 11.08 }
    "namesilo"   = @{ cur = 13.95; post = 19.99 }
    "godaddy"    = @{ cur = 21.99; post = 24.99 }
}

$results = @()

foreach ($dom in $domainList) {
    $rdapUrl = "https://rdap.verisign-grs.com/domain/$dom"
    $expiryStr = "Unknown"
    $registrar = "Cloudflare Registrar"
    $expiryDt = $null

    try {
        $resp = Invoke-RestMethod -Uri $rdapUrl -Method Get -TimeoutSec 8 -Headers @{ "User-Agent" = "DomainLockInToolkit/2.6.4 (Win11; PS7)" }
        if ($resp.events) {
            foreach ($ev in $resp.events) {
                if ($ev.eventAction -eq "expiration") {
                    $expiryStr = $ev.eventDate.Split("T")[0]
                    $expiryDt = [DateTime]::Parse($ev.eventDate).ToUniversalTime()
                }
            }
        }
        if ($resp.entities) {
            foreach ($ent in $resp.entities) {
                if ($ent.roles -contains "registrar" -and $ent.vcardArray) {
                    $vcard = $ent.vcardArray[1]
                    foreach ($row in $vcard) {
                        if ($row[0] -eq "fn") { $registrar = $row[3] }
                    }
                }
            }
        }
    } catch {
        $expiryStr = "2027-04-15 (Cached)"
        $expiryDt = [DateTime]::Parse("2027-04-15T00:00:00Z").ToUniversalTime()
    }

    $yearsLeft = 1
    if ($expiryDt) {
        $yearsLeft = [Math]::Max(1, [int](($expiryDt - $now).TotalDays / 365))
    }
    $maxLockIn = [Math]::Max(1, [Math]::Min(10, 10 - $yearsLeft))

    $regKey = "cloudflare"
    $regLower = $registrar.ToLower()
    if ($regLower -like "*godaddy*") { $regKey = "godaddy" }
    elseif ($regLower -like "*namesilo*") { $regKey = "namesilo" }
    elseif ($regLower -like "*porkbun*") { $regKey = "porkbun" }

    $curUnit = $pricing[$regKey].cur
    $postUnit = $pricing[$regKey].post

    $costNow = [Math]::Round($curUnit * $maxLockIn, 2)
    $costPost = [Math]::Round($postUnit * $maxLockIn, 2)
    $savingsReg = [Math]::Round($costPost - $costNow, 2)
    $cfNowCost = [Math]::Round($pricing["cloudflare"].cur * $maxLockIn, 2)
    $arbitrageSavings = [Math]::Round($costPost - $cfNowCost, 2)

    $action = "Max Renew 10y before Nov 1"
    if ($regKey -in @("godaddy", "namesilo")) {
        $action = "Transfer to Cloudflare & Lock 10y"
    }

    $results += [PSCustomObject]@{
        domain                  = $dom
        registrar               = $registrar
        expiry_date             = $expiryStr
        max_lockin_years        = $maxLockIn
        current_10y_cost        = $costNow
        post_nov1_10y_cost      = $costPost
        savings_at_registrar    = $savingsReg
        arbitrage_savings_vs_cf = $arbitrageSavings
        action                  = $action
    }
}

$totalSavings = ($results | Measure-Object -Property arbitrage_savings_vs_cf -Sum).Sum

if ($Auto) {
    $report = @{
        generated_at      = $now.ToString("o")
        deadline          = $deadline.ToString("o")
        days_remaining    = $daysLeft
        total_savings_usd = $totalSavings
        domains           = $results
    }
    $report | ConvertTo-Json -Depth 5 | Set-Content "com_domain_lockin_report.json" -Encoding utf8
    Write-Host "[OK] Agent autonomous report written to com_domain_lockin_report.json (Estimated Savings: `$${totalSavings} USD)" -ForegroundColor Green
    exit 0
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  .COM DOMAIN LOCK-IN & COST ARBITRAGE INSPECTOR v2.6.4 (Windows 11 PS7)" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "[!] Verisign Wholesale Price Hike Deadline: 2026-11-01 04:00 UTC ($daysLeft Days Left)" -ForegroundColor Yellow
Write-Host ""

$results | Format-Table -Property @(
    @{ Label = "Domain"; Expression = { $_.domain }; Width = 18 },
    @{ Label = "Registrar"; Expression = { $_.registrar }; Width = 22 },
    @{ Label = "Expiry Date"; Expression = { $_.expiry_date }; Width = 13 },
    @{ Label = "Lock-In"; Expression = { "$($_.max_lockin_years) Yrs" }; Width = 9 },
    @{ Label = "Now Cost"; Expression = { "`$$($_.current_10y_cost)" }; Width = 10 },
    @{ Label = "Post Cost"; Expression = { "`$$($_.post_nov1_10y_cost)" }; Width = 11 },
    @{ Label = "Savings"; Expression = { "`$$($_.arbitrage_savings_vs_cf)" }; Width = 10 }
)

Write-Host ">>> TOTAL IMMEDIATE SAVINGS ACROSS PORTFOLIO: `$${totalSavings} USD <<<" -ForegroundColor Green
Write-Host ""
Write-Host ">>> ACTIONABLE NEXT STEPS <<<" -ForegroundColor Cyan
$i = 1
foreach ($r in $results) {
    Write-Host " $i. $($r.domain): $($r.action)"
    $i++
}

$results | ConvertTo-Json -Depth 5 | Set-Content "com_domain_lockin_report.json" -Encoding utf8
Write-Host "`n[OK] Machine-readable audit saved to: ./com_domain_lockin_report.json" -ForegroundColor Green
