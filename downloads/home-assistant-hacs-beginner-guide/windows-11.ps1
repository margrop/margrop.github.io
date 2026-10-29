# HACS Beginner Automation Toolkit - Windows 11 Launcher (PowerShell 7)
[CmdletBinding()]
param(
    [Parameter(Position=0)][string]$Command = "install",
    [string]$ConfigDir = "",
    [switch]$Mirror
)

$ErrorActionPreference = "Stop"
Write-Host ">>> [Windows 11] Initializing HACS Automated Toolkit..." -ForegroundColor Cyan

# Check Python 3
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Error "Python 3 is required. Please install Python 3.9+ from python.org or Microsoft Store."
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PyScript = Join-Path $ScriptDir "hacs_toolkit.py"

$ArgsList = @($Command)
if ($ConfigDir) { $ArgsList += @("--config-dir", $ConfigDir) }
if ($Mirror) { $ArgsList += @("--mirror") }

python $PyScript @ArgsList
