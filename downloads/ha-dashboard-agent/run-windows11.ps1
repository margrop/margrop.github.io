$ErrorActionPreference = 'Stop'
$core = Join-Path $PSScriptRoot 'ha_dashboard.py'
if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 $core @args
} elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
    & python3 $core @args
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    & python $core @args
} else {
    throw 'Python 3.11+ is required. No software was installed and HA was not changed.'
}
exit $LASTEXITCODE
