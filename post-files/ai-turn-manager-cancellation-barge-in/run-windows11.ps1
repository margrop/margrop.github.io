[CmdletBinding()]
param(
    [switch]$Agent
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Lab = Join-Path $ScriptDir "turn_manager_lab.py"
$Output = Join-Path $ScriptDir "lab-output"

if (Get-Command py -ErrorAction SilentlyContinue) {
    $Python = @("py", "-3")
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $Python = @("python")
} else {
    throw "Python 3 was not found. Install Python 3, then rerun this script."
}

$Arguments = @($Lab, "--clean", "--output", $Output)
if ($Agent) {
    $Arguments += "--agent"
}

if ($Python.Count -eq 2) {
    & $Python[0] $Python[1] @Arguments
} else {
    & $Python[0] @Arguments
}

if ($LASTEXITCODE -ne 0) {
    throw "Turn Manager lab failed with exit code $LASTEXITCODE"
}

$Report = Get-Content (Join-Path $Output "report.json") -Raw | ConvertFrom-Json
if ($Report.status -ne "PASS") {
    throw "Release gate did not pass. Inspect lab-output/report.json."
}

Write-Host "Verified: $($Report.assertions.passed)/$($Report.assertions.total) assertions PASS"
Write-Host "Evidence: $Output"
