$ErrorActionPreference = 'Stop'
# Use a real installed Python interpreter, not an app-store alias.
if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)'
    if ($LASTEXITCODE -ne 0) { throw 'Python 3.10+ is required.' }
    & py -3 (Join-Path $PSScriptRoot 'configure_doh.py') @args
    exit $LASTEXITCODE
}
throw 'Install trusted Python 3.10+ with the py launcher first.'
