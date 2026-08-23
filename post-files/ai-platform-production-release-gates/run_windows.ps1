$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new()
$Lab = Join-Path $PSScriptRoot "release_gate_lab.py"
$Out = Join-Path $PSScriptRoot "release-gate-output"

if (Get-Command py.exe -ErrorAction SilentlyContinue) {
    & py.exe -3 $Lab --clean --output $Out
} elseif (Get-Command python.exe -ErrorAction SilentlyContinue) {
    & python.exe $Lab --clean --output $Out
} elseif (Get-Command python3.exe -ErrorAction SilentlyContinue) {
    & python3.exe $Lab --clean --output $Out
} else {
    throw "Python 3 was not found. Install Python 3, then rerun this script."
}
if ($LASTEXITCODE -ne 0) { throw "AI Platform release is blocked" }
Get-Content (Join-Path $Out "07-release-summary.txt")
