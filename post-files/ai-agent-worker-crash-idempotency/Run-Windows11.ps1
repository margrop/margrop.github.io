# One-click entry point for Windows 11. No network or third-party service is used.
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$LabDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LabScript = Join-Path $LabDir "worker_crash_lab.py"

$PythonCommand = $null
if (Get-Command py.exe -ErrorAction SilentlyContinue) {
    $PythonCommand = @("py.exe", "-3")
} elseif (Get-Command python.exe -ErrorAction SilentlyContinue) {
    $PythonCommand = @("python.exe")
} else {
    throw "Python 3 is required. Install it from the official Python distribution, then rerun."
}

Write-Host "Running the isolated Worker crash and idempotency lab..." -ForegroundColor Cyan
if ($PythonCommand.Count -eq 2) {
    & $PythonCommand[0] $PythonCommand[1] $LabScript --clean
} else {
    & $PythonCommand[0] $LabScript --clean
}
if ($LASTEXITCODE -ne 0) {
    throw "The lab failed. Review lab-output\results\06-acceptance-summary.txt."
}

$Summary = Join-Path $LabDir "lab-output\results\06-acceptance-summary.txt"
$PassCount = (Select-String -Path $Summary -Pattern '^\[PASS\]' -AllMatches).Count
if ($PassCount -ne 7 -or (Select-String -Path $Summary -Pattern '^result=PASS$').Count -ne 1) {
    throw "Acceptance output is incomplete or contains a failure."
}
Write-Host "PASS: 7/7 checks. Evidence is in $LabDir\lab-output" -ForegroundColor Green
