[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SourceDir,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$LocalBackupDir,

    [Parameter(Mandatory = $true, Position = 2)]
    [string]$OffsiteBackupDir,

    [switch]$Execute
)

$source = (Resolve-Path -LiteralPath $SourceDir).Path
$localRoot = [System.IO.Path]::GetFullPath($LocalBackupDir)
$offsiteRoot = [System.IO.Path]::GetFullPath($OffsiteBackupDir)
$timestamp = if ($env:BACKUP_TIMESTAMP) { $env:BACKUP_TIMESTAMP } else { Get-Date -Format 'yyyyMMdd-HHmmss' }
$snapshotName = "photo-backup-$timestamp"

if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "SOURCE_NOT_FOUND=$source"
}

if (($source -eq $localRoot) -or ($source -eq $offsiteRoot) -or ($localRoot -eq $offsiteRoot)) {
    throw 'SOURCE_AND_DESTINATIONS_MUST_DIFFER=1'
}

$localSnapshot = Join-Path $localRoot $snapshotName
$offsiteSnapshot = Join-Path $offsiteRoot $snapshotName

Write-Output "SOURCE=$source"
Write-Output "LOCAL_SNAPSHOT=$localSnapshot"
Write-Output "OFFSITE_SNAPSHOT=$offsiteSnapshot"
Write-Output "COPY_MODE=$(if ($Execute) { '--execute' } else { '--dry-run' })"
Write-Output 'WARNING=Keep the offsite destination on separate media and in a different physical location.'

if (-not $Execute) {
    Write-Output 'PLAN=copy source to local snapshot, copy source to offsite snapshot, write SHA256SUMS, verify both copies'
    Write-Output 'DRY_RUN_ONLY=1'
    exit 0
}

New-Item -ItemType Directory -Force -Path $localSnapshot, $offsiteSnapshot | Out-Null
$sourceFiles = Get-ChildItem -LiteralPath $source -File -Recurse
$manifest = foreach ($file in $sourceFiles) {
    $relative = $file.FullName.Substring($source.Length).TrimStart('\', '/')
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash *$relative"
}
$manifest = @($manifest | Sort-Object)
$manifest | Set-Content -LiteralPath (Join-Path $localSnapshot 'SHA256SUMS') -Encoding utf8
$manifest | Set-Content -LiteralPath (Join-Path $offsiteSnapshot 'SHA256SUMS') -Encoding utf8

foreach ($destination in @($localSnapshot, $offsiteSnapshot)) {
    & robocopy $source $destination /E /COPY:DAT /DCOPY:T /R:2 /W:2 /XJ /NFL /NDL /NP | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "ROBOCOPY_FAILED=$LASTEXITCODE"
    }
    foreach ($entry in $sourceFiles) {
        $relative = $entry.FullName.Substring($source.Length).TrimStart('\', '/')
        $candidate = Join-Path $destination $relative
        $expected = (Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash
        $actual = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
        if ($expected -ne $actual) {
            throw "CHECKSUM_FAILED=$relative"
        }
    }
}

Write-Output 'LOCAL_CHECKSUM=PASS'
Write-Output 'OFFSITE_CHECKSUM=PASS'
Write-Output 'BACKUP_STATUS=PASS'
