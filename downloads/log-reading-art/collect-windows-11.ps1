[CmdletBinding()]
param(
    [ValidateRange(1, 168)]
    [int]$Hours = 4,

    [string]$OutputDirectory = (Join-Path (Get-Location) "log-report-windows")
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Protect-PrivateData {
    param([string]$Text)

    $redacted = $Text
    $redacted = $redacted -replace '(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])', '[IP-REDACTED]'
    $redacted = $redacted -replace '(?i)([a-z0-9_-]+\.)+(local|lan|internal|home)', '[DOMAIN-REDACTED]'
    $redacted = $redacted -replace '(?i)C:\\Users\\[^\\\s]+', 'C:\Users\[USER-REDACTED]'
    $redacted = $redacted -replace '(?i)(Bearer|token|secret|password|apikey|api_key)[=: ]+\S+', '$1=[SECRET-REDACTED]'
    if ($env:COMPUTERNAME) {
        $redacted = $redacted.Replace($env:COMPUTERNAME, '[HOST-REDACTED]')
    }
    if ($env:USERNAME) {
        $redacted = $redacted.Replace($env:USERNAME, '[USER-REDACTED]')
    }
    return $redacted
}

function Add-Section {
    param(
        [string]$Title,
        [scriptblock]$Command
    )

    Add-Content -Path $script:RawPath -Value "`n===== $Title =====" -Encoding utf8
    try {
        $result = & $Command 2>&1 | Out-String -Width 220
        Add-Content -Path $script:RawPath -Value $result -Encoding utf8
    }
    catch {
        Add-Content -Path $script:RawPath -Value "[command unavailable or returned non-zero] $($_.Exception.Message)" -Encoding utf8
    }
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$script:RawPath = Join-Path $env:TEMP ("log-reading-windows-{0}.txt" -f ([guid]::NewGuid()))
$reportPath = Join-Path $OutputDirectory "windows-log-report.txt"
$startTime = (Get-Date).AddHours(-$Hours)

@(
    "Windows troubleshooting evidence report"
    "Generated: $((Get-Date).ToString('o'))"
    "Window: last $Hours hour(s)"
    "Mode: read-only, local-only, redacted"
) | Set-Content -Path $script:RawPath -Encoding utf8

try {
    Add-Section "OS AND CLOCK" { Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsBuildNumber, OsArchitecture, TimeZone }
    Add-Section "DISK" { Get-Volume | Select-Object DriveLetter, FileSystemLabel, FileSystemType, HealthStatus, SizeRemaining, Size }
    Add-Section "SYSTEM ERRORS" {
        Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2, 3; StartTime = $startTime } -MaxEvents 300 |
            Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message
    }
    Add-Section "APPLICATION ERRORS" {
        Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Level = 1, 2, 3; StartTime = $startTime } -MaxEvents 300 |
            Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message
    }
    Add-Section "STOPPED AUTOMATIC SERVICES" {
        Get-CimInstance Win32_Service |
            Where-Object { $_.StartMode -eq 'Auto' -and $_.State -ne 'Running' } |
            Select-Object Name, DisplayName, State, StartMode, ExitCode
    }
    Add-Section "LISTENING SOCKETS" {
        Get-NetTCPConnection -State Listen | Select-Object LocalAddress, LocalPort, OwningProcess
    }
    Add-Section "NETWORK CONFIGURATION" { Get-NetIPConfiguration }
    Add-Section "DNS RESOLUTION" { Resolve-DnsName -Name example.com -Type A }
    Add-Section "RECENT HIGH-CPU PROCESSES" {
        Get-Process | Sort-Object CPU -Descending | Select-Object -First 25 Id, ProcessName, CPU, WorkingSet64
    }

    $raw = Get-Content -Path $script:RawPath -Raw -Encoding utf8
    Protect-PrivateData -Text $raw | Set-Content -Path $reportPath -Encoding utf8
    Write-Output "Report written to $reportPath"
}
finally {
    [System.IO.File]::Delete($script:RawPath)
}
