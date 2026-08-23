$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputDir = Join-Path $ScriptDir "lab-output"
$Lab = Join-Path $ScriptDir "ai_gateway_fault_lab.py"

if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 $Lab --scenario all --output-dir $OutputDir --clean
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    & python $Lab --scenario all --output-dir $OutputDir --clean
} else {
    throw "Python 3 was not found. Install Python 3, then run this script again."
}

if ($LASTEXITCODE -ne 0) {
    throw "AI Gateway fault lab failed with exit code $LASTEXITCODE"
}

$Summary = Get-Content (Join-Path $OutputDir "summary.json") -Raw | ConvertFrom-Json
if ($Summary.outbound_attempts -ne 0 -or $Summary.results.acceptance.passed -ne 7) {
    throw "Acceptance or zero-network verification failed."
}

Write-Host "PASS: 7/7 checks; outbound network attempts: 0"
