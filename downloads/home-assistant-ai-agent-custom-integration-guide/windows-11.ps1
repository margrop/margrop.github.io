# Windows 11 PowerShell Automation Wrapper for Home Assistant Custom Integration Toolkit
[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet("probe", "scaffold", "lint", "deploy", "all")]
    [string]$Action,

    [Parameter(Mandatory=$false)]
    [string]$HostName = "192.168.1.100",

    [Parameter(Mandatory=$false)]
    [int]$Port = 8080,

    [Parameter(Mandatory=$false)]
    [string]$Domain = "my_custom_device",

    [Parameter(Mandatory=$false)]
    [string]$Name = "My Custom Smart Device",

    [Parameter(Mandatory=$false)]
    [string]$HaConfig = "/config",

    [Parameter(Mandatory=$false)]
    [switch]$Mock
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonExe = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $PythonExe) {
    $PythonExe = (Get-Command py -ErrorAction SilentlyContinue).Source
}
if (-not $PythonExe) {
    Write-Error "Python 3 is required. Please install Python from https://www.python.org or winget install Python.Python.3.12"
    exit 1
}

$KitPy = Join-Path $ScriptDir "ha_custom_kit.py"

switch ($Action) {
    "probe" {
        Write-Host ">>> Probing target device on local network..." -ForegroundColor Cyan
        $mockFlag = if ($Mock) { "--mock" } else { "" }
        & $PythonExe $KitPy probe --host $HostName --port $Port $mockFlag
    }
    "scaffold" {
        Write-Host ">>> Scaffolding modern Home Assistant integration: $Domain" -ForegroundColor Cyan
        & $PythonExe $KitPy scaffold --domain $Domain --name $Name --out-dir (Join-Path $ScriptDir "custom_components")
    }
    "lint" {
        Write-Host ">>> Linting component syntax and non-blocking rules..." -ForegroundColor Cyan
        $target = Join-Path $ScriptDir "custom_components\$Domain"
        & $PythonExe $KitPy lint --path $target
    }
    "deploy" {
        Write-Host ">>> Deploying component to Home Assistant: $HaConfig" -ForegroundColor Cyan
        $src = Join-Path $ScriptDir "custom_components\$Domain"
        & $PythonExe $KitPy deploy --src $src --ha-config $HaConfig
    }
    "all" {
        Write-Host ">>> Running end-to-end integration build and verification pipeline..." -ForegroundColor Green
        & $PythonExe $KitPy probe --mock
        & $PythonExe $KitPy scaffold --domain $Domain --name $Name --out-dir (Join-Path $ScriptDir "custom_components")
        $target = Join-Path $ScriptDir "custom_components\$Domain"
        & $PythonExe $KitPy lint --path $target
        Write-Host ">>> Custom component is verified and ready for deployment!" -ForegroundColor Green
    }
}
