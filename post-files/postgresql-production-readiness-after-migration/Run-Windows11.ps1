# One-click entry point for Windows 11.
# Prerequisite: Docker Desktop with WSL 2 integration enabled for one distro.
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$LabDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Get-Command docker.exe -ErrorAction SilentlyContinue)) {
    throw "Docker Desktop is required. Install it from the official Docker site first."
}
docker.exe info | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Docker Desktop is installed but its Linux-container engine is not ready."
}
docker.exe compose version | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose v2 is required."
}
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw "WSL 2 is required so Windows can execute the bundled Bash lab without downloading helper scripts."
}

$WslLabDir = (& wsl.exe wslpath -a -u $LabDir).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($WslLabDir)) {
    throw "Could not translate the lab directory into a WSL path."
}

Write-Host "Starting the isolated PostgreSQL readiness lab..." -ForegroundColor Cyan
& wsl.exe --cd $WslLabDir /usr/bin/env bash ./run-lab.sh
if ($LASTEXITCODE -ne 0) {
    throw "The lab failed. Review the last section above and the results directory."
}

Write-Host "PASS: results are in $LabDir\results" -ForegroundColor Green
