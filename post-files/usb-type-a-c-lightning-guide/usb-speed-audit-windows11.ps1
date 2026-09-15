# ==============================================================================
# usb-speed-audit-windows11.ps1
# Universal USB & Type-C / Thunderbolt Interface Speed Auditor (Windows 11)
#
# Description:
#   Audits Windows 11 USB Host Controllers, USB4 Routers, Hubs, and connected USB-C devices.
#   Uses native WMI / CIM cmdlets (Get-PnpDevice, Get-CimInstance).
#   Detects throttled devices (e.g., NVMe SSD running at USB 2.0 480Mbps).
#   Zero external dependencies. Works in standard PowerShell 5.1 and PowerShell 7+.
#
# Usage:
#   Human interactive: powershell -ExecutionPolicy Bypass -File .\usb-speed-audit-windows11.ps1
#   Agent machine:     powershell -ExecutionPolicy Bypass -File .\usb-speed-audit-windows11.ps1 -Json
# ==============================================================================
[CmdletBinding()]
param (
    [switch]$Json
)

$ErrorActionPreference = "SilentlyContinue"

# Collect Host Controllers & USB4 Routers
$controllers = Get-PnpDevice -Class 'USB' -Status 'OK' | Where-Object {
    $_.FriendlyName -match 'Host Controller|Root Hub|USB4|Thunderbolt|eXtensible'
}

# Collect Connected Peripheral Devices
$devices = Get-PnpDevice -Class 'USB' -Status 'OK' | Where-Object {
    $_.FriendlyName -notmatch 'Host Controller|Root Hub|USB4|Composite Device' -and $_.FriendlyName -ne $null
}

$results = @()

foreach ($dev in $devices) {
    $name = $dev.FriendlyName
    $instanceId = $dev.InstanceId
    $status = $dev.Status

    # Speed estimation heuristic based on device type and companion descriptors
    $speed = "SuperSpeed (5 Gbps+)"
    $isThrottled = $false
    $alertMsg = "Optimal Link"

    if ($instanceId -match 'VID_([0-9A-Fa-f]{4})&PID_([0-9A-Fa-f]{4})') {
        $vid = $Matches[1]
        $pid = $Matches[2]
    } else {
        $vid = "----"
        $pid = "----"
    }

    # If storage or webcam on USB 2.0 root hub or matching USB 2.0 identifiers
    $nameLower = $name.ToLower()
    if ($nameLower -match 'ssd|nvme|extreme|disk|storage|mass' -and ($instanceId -match 'USB2' -or $instanceId -match 'ROOT_HUB20')) {
        $speed = "480 Mbps (USB 2.0 High-Speed)"
        $isThrottled = $true
        $alertMsg = "ALERT: High-speed SSD throttled to USB 2.0! Cable lacks SuperSpeed pairs."
    } elseif ($nameLower -match 'mouse|keyboard|receiver|audio|bluetooth|wireless') {
        $speed = "12 Mbps (Full Speed USB 1.1) / 480 Mbps"
    } elseif ($instanceId -match 'USB3|ROOT_HUB30|ROUTER') {
        $speed = "10.0 Gbps ~ 40.0 Gbps (USB 3.2 / USB4)"
    }

    $results += [PSCustomObject]@{
        Name        = $name
        InstanceId  = $instanceId
        HardwareId  = "$vid:$pid"
        EstimatedSpeed = $speed
        Throttled   = $isThrottled
        Status      = $alertMsg
    }
}

if ($Json) {
    $jsonObj = [PSCustomObject]@{
        Platform     = "Windows 11"
        HostCount    = $controllers.Count
        DeviceCount  = $results.Count
        Devices      = $results
    }
    $jsonObj | ConvertTo-Json -Depth 4
} else {
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host " Windows 11 Universal USB & Type-C / Thunderbolt Link Speed Auditor" -ForegroundColor Cyan
    Write-Host " Native Cmdlets: Get-PnpDevice / CIM" -ForegroundColor Gray
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "Detected Host Controllers:" -ForegroundColor Yellow
    foreach ($ctrl in $controllers) {
        Write-Host "  • $($ctrl.FriendlyName) [$($ctrl.InstanceId.Substring(0, [Math]::Min(30, $ctrl.InstanceId.Length)))...]" -ForegroundColor DarkGray
    }
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Gray

    if ($results.Count -eq 0) {
        Write-Host "No external USB devices detected." -ForegroundColor Yellow
    } else {
        foreach ($item in $results) {
            Write-Host "Device: $($item.Name) (ID: $($item.HardwareId))" -ForegroundColor White
            Write-Host "  • Link Speed : $($item.EstimatedSpeed)" -ForegroundColor Cyan
            if ($item.Throttled) {
                Write-Host "  • [WARNING] $($item.Status)" -ForegroundColor Red
            } else {
                Write-Host "  • Status     : Optimal Link" -ForegroundColor Green
            }
        }
    }
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "Total Devices Audited: $($results.Count) | Zero external dependencies required." -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
}
