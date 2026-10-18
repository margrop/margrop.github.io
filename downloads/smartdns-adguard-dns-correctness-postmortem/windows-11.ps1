#requires -Version 5.1
param(
    [ValidateSet('Audit','Apply','Rollback')][string]$Mode = 'Audit',
    [string]$Config = "$PSScriptRoot/settings.private.json",
    [string]$RunId = ''
)
$ErrorActionPreference = 'Stop'
$settings = Get-Content -Raw -LiteralPath $Config | ConvertFrom-Json
$router = [string]$settings.router_ssh
$filter = [string]$settings.filter_ssh
foreach ($role in @($router,$filter)) {
    if ($role -notmatch '^[A-Za-z0-9_@.-]+$') { throw 'Use a simple, preconfigured SSH alias.' }
}
foreach ($tool in @('ssh','scp','tar')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing Windows optional component: $tool" }
}
if (-not $RunId) { $RunId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmss') + '-' + (Get-Random -Maximum 999999) }
if ($RunId -notmatch '^[A-Za-z0-9-]+$') { throw 'Invalid run identifier' }
$remote = "/root/dns-care-$RunId"
$sshOptions = @('-o','BatchMode=yes','-o','ConnectTimeout=8')
function Invoke-Ssh([string]$Role,[string]$Command) {
    & ssh @sshOptions $Role $Command
    if ($LASTEXITCODE -ne 0) { throw "Remote step failed (exit $LASTEXITCODE)" }
}
function Copy-Ssh([string[]]$Items) {
    & scp '-O' @sshOptions @Items
    if ($LASTEXITCODE -ne 0) { throw 'File transfer failed' }
}
if ($Mode -eq 'Rollback') {
    Invoke-Ssh $router "sh '$remote/core/router.sh' rollback"
    Invoke-Ssh $filter "python3 '$remote/core/manage_filter.py' rollback"
    exit
}
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('dns-care-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $scratch)
try {
    $archive = Join-Path $scratch 'payload.tar.gz'
    & tar '-czf' $archive '-C' $PSScriptRoot 'core'
    if ($LASTEXITCODE -ne 0) { throw 'Archive creation failed' }
    foreach ($role in @($router,$filter)) {
        Invoke-Ssh $role "umask 077; mkdir -p '$remote'; chmod 700 '$remote'"
        Copy-Ssh @($archive, "${role}:$remote/payload.tar.gz")
        Copy-Ssh @($Config, "${role}:$remote/settings.private.json")
        Invoke-Ssh $role "umask 077; tar -xzf '$remote/payload.tar.gz' -C '$remote'"
    }
    Invoke-Ssh $filter "python3 '$remote/core/manage_filter.py' bootstrap"
    $pins = Join-Path $scratch 'resolved.private.json'
    $records = Join-Path $scratch 'local-records.private.sh'
    Copy-Ssh @("${filter}:$remote/resolved.private.json",$pins)
    Copy-Ssh @("${filter}:$remote/local-records.private.sh",$records)
    Copy-Ssh @($pins,$records,"${router}:$remote/")
    if ($Mode -eq 'Audit') {
        Invoke-Ssh $router "sh '$remote/core/router.sh' audit"
        Invoke-Ssh $filter "python3 '$remote/core/manage_filter.py' audit"
    } else {
        Invoke-Ssh $filter "python3 '$remote/core/manage_filter.py' adapter"
        Invoke-Ssh $router "sh '$remote/core/router.sh' apply"
        Start-Sleep -Seconds 3
        Invoke-Ssh $filter "python3 '$remote/core/manage_filter.py' verify-router"
        Invoke-Ssh $filter "python3 '$remote/core/manage_filter.py' adguard"
        Invoke-Ssh $filter "python3 '$remote/core/manage_filter.py' verify-all"
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Write-Output 'PASS: server profile applied and live DNS checks completed.'
    }
} catch {
    if ($Mode -eq 'Apply') {
        Write-Warning 'Apply failed. Attempting to restore the two original configurations.'
        & ssh @sshOptions $router "test ! -f '$remote/core/router.sh' || sh '$remote/core/router.sh' rollback"
        & ssh @sshOptions $filter "test ! -f '$remote/core/manage_filter.py' || python3 '$remote/core/manage_filter.py' rollback"
    }
    throw
} finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force
    Write-Output "Run ID: $RunId. Remote private receipts: $remote"
}
