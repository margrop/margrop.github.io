# Windows 11 PowerShell 7 / Windows PowerShell Automation Script
# Home Assistant Midea AC LAN Offline Dependency Upgrade Toolkit
[CmdletBinding()]
param (
    [switch]$Apply,
    [switch]$NonInteractive,
    [string]$Url,
    [string]$Token,
    [string]$PythonVer = "python3.14"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Home Assistant Midea AC LAN Offline Deps Toolkit (Win11)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonExe = (Get-Command py.exe -ErrorAction SilentlyContinue) ? "py -3" : "python"

$ArgsList = @("$ScriptDir\midea_deps_toolkit.py", "--python-ver", $PythonVer)
if ($Apply) { $ArgsList += "--apply" }
if ($NonInteractive) { $ArgsList += "--non-interactive" }
if ($Url) { $ArgsList += @("--url", $Url) }
if ($Token) { $ArgsList += @("--token", $Token) }

& $PythonExe $ArgsList
