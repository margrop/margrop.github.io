$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new()
$Script = Join-Path $PSScriptRoot "memory_lifecycle_lab.py"
$Output = Join-Path $PSScriptRoot "memory-lab-output"

if (Get-Command py.exe -ErrorAction SilentlyContinue) {
    & py.exe -3 $Script --clean --output $Output
} elseif (Get-Command python.exe -ErrorAction SilentlyContinue) {
    & python.exe $Script --clean --output $Output
} elseif (Get-Command python3.exe -ErrorAction SilentlyContinue) {
    & python3.exe $Script --clean --output $Output
} else {
    throw "Python 3 was not found. Install Python 3, then rerun this script."
}
if ($LASTEXITCODE -ne 0) { throw "Structured-memory lab failed" }
Get-Content (Join-Path $Output "07-acceptance-summary.txt")
