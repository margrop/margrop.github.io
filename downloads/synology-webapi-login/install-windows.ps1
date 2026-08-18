$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvDir = Join-Path $ScriptDir ".venv"
$Python = Get-Command py -ErrorAction SilentlyContinue

if ($Python) {
    & py -3 -m venv $VenvDir
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    & python -m venv $VenvDir
} else {
    throw "Python 3 is required. Install it from python.org or with: winget install Python.Python.3.13"
}

$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
& $VenvPython -m pip install --upgrade pip
& $VenvPython -m pip install -r (Join-Path $ScriptDir "requirements.txt")

if ($env:SYNOLOGY_SETUP_ONLY -eq "1") {
    & $VenvPython (Join-Path $ScriptDir "synology_login.py") --help
    exit $LASTEXITCODE
}

$DsmUrl = Read-Host "DSM URL (for example https://nas.example.test:5001)"
$Account = Read-Host "Account"
$SessionName = Read-Host "Session name [DSM]"
if ([string]::IsNullOrWhiteSpace($SessionName)) {
    $SessionName = "DSM"
}

& $VenvPython (Join-Path $ScriptDir "synology_login.py") `
    --url $DsmUrl `
    --account $Account `
    --session $SessionName
