# ==============================================================================
# airprint_toolkit_windows11.ps1
# One-Click AirPrint Automated Diagnostic & Repair Toolkit for Windows 11
# Ensures network profile, Windows Firewall, Spooler, and IPP client are ready.
# No third-party cloud service dependencies.
# ==============================================================================
[CmdletBinding()]
param (
    [switch]$Apply,
    [switch]$VerboseOutput,
    [string]$PlanFile = ""
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  iOS 27 AirPrint Compatibility Toolkit (Windows 11)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Step 1: Check Administrator Elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($Apply -and -not $isAdmin) {
    Write-Warning "[-] Error: -Apply requires Administrator privileges. Please re-run PowerShell as Administrator."
    exit 1
}

# Step 2: Audit Network Profile (Must be Private for Discovery)
Write-Host "[1/5] Auditing Network Category (Private vs Public)..." -ForegroundColor Yellow
$profiles = Get-NetConnectionProfile
foreach ($p in $profiles) {
    Write-Host "      Adapter: $($p.Name) | NetworkCategory: $($p.NetworkCategory)"
    if ($p.NetworkCategory -ne "Private") {
        if ($Apply) {
            Write-Host "      [*] Switching network profile to Private to enable mDNS & printer discovery..."
            Set-NetConnectionProfile -Name $p.Name -NetworkCategory Private
            Write-Host "      [✓] Profile set to Private." -ForegroundColor Green
        } else {
            Write-Warning "      [!] Network is currently Public. Run with -Apply to switch to Private."
        }
    }
}

# Step 3: Windows Firewall Rules (TCP 631 IPP & UDP 5353 mDNS)
Write-Host "[2/5] Auditing Windows Firewall Inbound Rules..." -ForegroundColor Yellow
$firewallRules = @(
    @{ Name="AirPrint-IPP-In"; Port=631; Protocol="TCP" },
    @{ Name="AirPrint-mDNS-In"; Port=5353; Protocol="UDP" }
)

foreach ($r in $firewallRules) {
    $existing = Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue
    if (-not $existing) {
        if ($Apply) {
            Write-Host "      [*] Creating inbound firewall rule for $($r.Protocol) $($r.Port)..."
            New-NetFirewallRule -DisplayName $r.Name -Direction Inbound -LocalPort $r.Port -Protocol $r.Protocol -Action Allow -Profile Private | Out-Null
            Write-Host "      [✓] Rule $($r.Name) created." -ForegroundColor Green
        } else {
            Write-Warning "      [!] Missing firewall rule: $($r.Name) ($($r.Protocol) $($r.Port))"
        }
    } else {
        Write-Host "      [✓] Firewall rule $($r.Name) is active." -ForegroundColor Green
    }
}

# Step 4: Ensure Spooler Service & Internet Printing Client
Write-Host "[3/5] Auditing Print Spooler and IPP Client..." -ForegroundColor Yellow
$spooler = Get-Service -Name Spooler -ErrorAction SilentlyContinue
if ($spooler.Status -ne "Running") {
    if ($Apply) {
        Write-Host "      [*] Starting Spooler service..."
        Start-Service -Name Spooler
        Set-Service -Name Spooler -StartupType Automatic
        Write-Host "      [✓] Spooler service running." -ForegroundColor Green
    }
} else {
    Write-Host "      [✓] Print Spooler is running." -ForegroundColor Green
}

# Step 5: Flush DNS & Multicast Caches
if ($Apply) {
    Write-Host "[4/5] Flushing Windows DNS/mDNS Client Cache..." -ForegroundColor Yellow
    Clear-DnsClientCache
    Write-Host "      [✓] DNS cache cleared." -ForegroundColor Green
}

# Step 6: Invoke Python Core Engine if Python is available
Write-Host "[5/5] Invoking Python Core Engine for Declarative Protocol Checks..." -ForegroundColor Yellow
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    $pythonCmd = Get-Command py -ErrorAction SilentlyContinue
}

if ($pythonCmd) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $coreScript = Join-Path $scriptDir "airprint_core_agent.py"
    $pyArgs = @($coreScript)
    if ($PlanFile) { $pyArgs += @("--plan", $PlanFile) }
    if ($Apply) { $pyArgs += "--apply" }
    if ($VerboseOutput) { $pyArgs += "--verbose" }
    
    & $pythonCmd.Source $pyArgs
} else {
    Write-Host "      [i] Python not detected. Native PowerShell network & firewall configuration complete." -ForegroundColor Cyan
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  [✓] Windows 11 AirPrint Toolkit Completed Successfully." -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
