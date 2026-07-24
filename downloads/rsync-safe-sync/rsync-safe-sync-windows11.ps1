param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [ValidateSet("Plan", "Apply")][string]$Mode = "Plan",
    [switch]$AllowDelete
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw "WSL is required. Run 'wsl --install' in an elevated PowerShell window, restart, then rerun this script."
}

$deleteValue = if ($AllowDelete) { "1" } else { "0" }
$escapedSource = $Source.Replace("'", "'\"'\"'")
$escapedDestination = $Destination.Replace("'", "'\"'\"'")
$bashScript = @"
set -euo pipefail
if ! command -v rsync >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y rsync openssh-client
fi
source_path='${escapedSource}'
destination_path='${escapedDestination}'
source_path="`${source_path%/}/"
args=(-aiv --human-readable --partial --itemize-changes '--out-format=%i|%n%L')
if [[ '$deleteValue' == '1' ]]; then args+=(--delete-delay); fi
plan_file="rsync-plan-`$(date +%Y%m%d-%H%M%S).txt"
rsync --dry-run "`${args[@]}" "`$source_path" "`$destination_path" | tee "`$plan_file"
echo "Plan saved to `$plan_file"
"@

if ($Mode -eq "Apply") {
    $confirmation = Read-Host "Review the plan. Type APPLY to continue"
    if ($confirmation -ne "APPLY") { throw "Cancelled." }
    $bashScript += @"
rsync "`${args[@]}" "`$source_path" "`$destination_path"
echo 'Post-sync verification:'
rsync --dry-run "`${args[@]}" "`$source_path" "`$destination_path"
"@
}

$bashScript | wsl.exe bash
