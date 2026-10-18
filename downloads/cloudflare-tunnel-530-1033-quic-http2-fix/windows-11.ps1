# Tunnel Doctor for Windows 11
# Diagnose a cloudflared connector that drops offline (Cloudflare 530 / 1033),
# pin it to the http2 transport, optionally upgrade the image, and roll back.
#
# Usage (elevated PowerShell for service changes):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\windows-11.ps1 -Mode Audit
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\windows-11.ps1 -Mode Apply   [-Target NAME]
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\windows-11.ps1 -Mode Upgrade -Version 2026.10.1 [-Target NAME]
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\windows-11.ps1 -Mode Rollback -RunId RUN_ID
#
# No cloud API, no remote script download. Only the Windows service registry,
# the Application event log, and Docker Desktop if it is installed.
[CmdletBinding()]
param(
  [ValidateSet('Audit', 'Apply', 'Upgrade', 'Rollback')]
  [string]$Mode = 'Audit',
  [string]$Target = '',
  [string]$Version = '',
  [string]$Image = 'cloudflare/cloudflared',
  [string]$RunId = '',
  [int]$WaitSeconds = 25
)
Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

$StateDir  = if ($env:TUNNEL_DOCTOR_STATE) { $env:TUNNEL_DOCTOR_STATE } else { Join-Path $env:ProgramData 'tunnel-doctor' }
$NewRunId  = Get-Date -Format 'yyyyMMdd-HHmmss'
$RunDir    = Join-Path $StateDir "runs\$NewRunId"
$EdgeHosts = @('region1.v2.argotunnel.com', 'region2.v2.argotunnel.com')
$QuicSigns = 'no recent network activity|failed to accept QUIC stream|Switching to fallback protocol|egress UDP to port 7844|UDP Connectivity.*status=fail'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Say($m)  { Write-Host $m }
function Ok($m)   { Write-Host "  [OK]   $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Bad($m)  { Write-Host "  [FAIL] $m" -ForegroundColor Red }
function Mask([string]$s) { return ($s -replace 'eyJ[A-Za-z0-9_=-]{20,}', '<TOKEN>') }
function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  return (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Need-Admin { if (-not (Test-Admin)) { throw "Run this mode from an elevated PowerShell (Run as administrator)." } }
function Has-Docker { return [bool](Get-Command docker -ErrorAction SilentlyContinue) }
function Record($kind, $name, $path, $bak) {
  New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
  Add-Content -Path (Join-Path $RunDir 'manifest.tsv') -Value "$kind`t$name`t$path`t$bak"
}

# ---------- discovery ----------
function Get-ServiceTargets {
  $all = @(Get-CimInstance Win32_Service | Where-Object { $_.Name -like '*cloudflared*' -or $_.PathName -like '*cloudflared*' })
  if ($Target) { $all = @($all | Where-Object { $_.Name -eq $Target }) }
  return $all
}
function Get-DockerTargets {
  if (-not (Has-Docker)) { return @() }
  $rows = @(docker ps -a --format '{{.Names}}|{{.Image}}' 2>$null)
  $names = @($rows | Where-Object { $_ -match '\|.*cloudflared' } | ForEach-Object { $_.Split('|')[0] })
  if ($Target) { $names = @($names | Where-Object { $_ -eq $Target }) }
  return $names
}
function Get-ComposeFile($c) {
  $f = (docker inspect -f '{{index .Config.Labels "com.docker.compose.project.config_files"}}' $c 2>$null)
  if ($f) { $f = $f.Split(',')[0] }
  if ($f -and (Test-Path -LiteralPath $f)) { return $f }
  return $null
}
function Get-ComposeProject($c) { return (docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' $c) }
function Get-ContainerVersion($c) {
  $m = (docker logs $c 2>&1 | Out-String) | Select-String -Pattern 'Version (\d{4}\.\d+\.\d+)' -AllMatches
  if ($m) { return $m.Matches[-1].Groups[1].Value } else { return 'unknown' }
}

# Service environment lives in a REG_MULTI_SZ named Environment under the service key.
function Get-ServiceKey($name) { return "HKLM:\SYSTEM\CurrentControlSet\Services\$name" }
function Get-ServiceEnv($name) {
  $v = (Get-ItemProperty -Path (Get-ServiceKey $name) -Name Environment -ErrorAction SilentlyContinue)
  if ($v) { return @($v.Environment) } else { return @() }
}
function Get-ServiceLogs($svc, [datetime]$since) {
  $lines = @()
  try {
    $lines += Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'cloudflared'; StartTime = $since } -ErrorAction Stop |
      Sort-Object TimeCreated | ForEach-Object { $_.Message }
  } catch { }
  if ($svc.PathName -match '--logfile\s+"?([^"\s]+)') {
    $lf = $Matches[1]
    if (Test-Path -LiteralPath $lf) {
      $lines += Get-Content -LiteralPath $lf -Tail 3000 | Where-Object {
        if ($_ -match '^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ)') { ([datetime]$Matches[1]).ToUniversalTime() -ge $since.ToUniversalTime() } else { $false }
      }
    }
  }
  return $lines
}

# ---------- checks ----------
function Test-Tcp($h, $port) {
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $task = $client.ConnectAsync($h, $port)
    return ($task.Wait(5000) -and $client.Connected)
  } catch { return $false } finally { $client.Close() }
}
function Check-Edge {
  Say 'Edge reachability (TCP 7844 is used by http2, UDP 7844 by quic):'
  foreach ($h in $EdgeHosts) {
    try { Resolve-DnsName -Name $h -ErrorAction Stop | Out-Null; Ok "DNS $h resolves" } catch { Bad "DNS $h does not resolve"; continue }
    if (Test-Tcp $h 7844) { Ok "TCP ${h}:7844 reachable" } else { Bad "TCP ${h}:7844 blocked: http2 fallback cannot work either" }
  }
  Say '  [INFO] UDP 7844 has no handshake to probe safely; it is judged from connector logs below.'
}
function Report-Logs($label, $lines) {
  $text = @($lines)
  $reg = @($text | Where-Object { $_ -match 'Registered tunnel connection' }).Count
  $quic = @($text | Where-Object { $_ -match $QuicSigns }).Count
  $origin = @($text | Where-Object { $_ -match 'Unable to reach the origin service' }).Count
  Say "  log window: registered=$reg quic_failures=$quic origin_errors=$origin"
  if ($quic -gt 0) { Warn "${label}: QUIC/UDP failures found, pinning http2 is recommended (-Mode Apply)" }
  if ($origin -gt 0) { Warn "${label}: some ingress rules point to origins that refuse connections" }
  $text | Where-Object { $_ -match "$QuicSigns|Registered tunnel|Initiating shutdown|SUMMARY:" } |
    Select-Object -Last 4 | ForEach-Object { Say ('    ' + (Mask $_)) }
}

function Audit-Service($svc) {
  Say "Windows service: $($svc.Name) ($($svc.State), start=$($svc.StartMode))"
  $exe = if ($svc.PathName -match '^"?([^"]+cloudflared\.exe)') { $Matches[1] } else { $null }
  if ($exe -and (Test-Path -LiteralPath $exe)) { Say "  version: $((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion)" }
  $pinned = ((Get-ServiceEnv $svc.Name) -match '^TUNNEL_TRANSPORT_PROTOCOL=http2$') -or ($svc.PathName -match '--protocol[ =]http2')
  if ($pinned) { Ok 'transport already pinned to http2' } else { Warn 'transport is auto (quic first)' }
  if ($svc.PathName -match '--token') { Warn 'token is in the service command line; prefer --token-file' }
  Report-Logs $svc.Name (Get-ServiceLogs $svc (Get-Date).AddHours(-24))
}
function Audit-Docker($c) {
  Say "Docker container: $c ($(docker inspect -f '{{.State.Status}} restart={{.RestartCount}}' $c))"
  Say "  image: $(docker inspect -f '{{.Config.Image}}' $c)  version: $(Get-ContainerVersion $c)"
  $cmd = (docker inspect -f '{{join .Config.Cmd " "}} {{range .Config.Env}}{{.}} {{end}}' $c)
  if ($cmd -match '--protocol[ =]http2|TUNNEL_TRANSPORT_PROTOCOL=http2') { Ok 'transport already pinned to http2' } else { Warn 'transport is auto (quic first)' }
  if ($cmd -match '--token') { Warn 'token is a command-line argument; prefer TUNNEL_TOKEN or --token-file' }
  $f = Get-ComposeFile $c
  if ($f) { Ok "compose file: $f" } else { Warn 'not managed by compose: Apply will only print manual steps' }
  Report-Logs $c @((docker logs --since 24h $c 2>&1) | ForEach-Object { "$_" })
}

# ---------- changes ----------
function Wait-ServiceRegistered($svc, [datetime]$since) {
  for ($i = 0; $i -lt $WaitSeconds; $i++) {
    if (@(Get-ServiceLogs $svc $since | Where-Object { $_ -match 'Registered tunnel connection' }).Count -gt 0) { return $true }
    Start-Sleep -Seconds 1
  }
  return $false
}
function Wait-DockerRegistered($c, [string]$since) {
  for ($i = 0; $i -lt $WaitSeconds; $i++) {
    if ((docker logs --since $since $c 2>&1 | Out-String) -match 'Registered tunnel connection') { return $true }
    Start-Sleep -Seconds 1
  }
  return $false
}

function Apply-Service($svc) {
  $name = $svc.Name
  $envs = @(Get-ServiceEnv $name)
  if (($envs -match '^TUNNEL_TRANSPORT_PROTOCOL=') -or ($svc.PathName -match '--protocol')) { Ok "$name already pins a protocol, nothing to change"; return }
  New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
  $bak = Join-Path $RunDir "$name.reg"
  & reg.exe export "HKLM\SYSTEM\CurrentControlSet\Services\$name" $bak /y | Out-Null
  Record 'service' $name (Get-ServiceKey $name) $bak
  $new = [string[]](@($envs) + 'TUNNEL_TRANSPORT_PROTOCOL=http2')
  New-ItemProperty -Path (Get-ServiceKey $name) -Name Environment -PropertyType MultiString -Value $new -Force | Out-Null
  $since = Get-Date
  Restart-Service -Name $name -Force
  if (Wait-ServiceRegistered $svc $since) { Ok "$name registered with http2" }
  elseif ((Get-Service -Name $name).Status -eq 'Running' -and @(Get-ServiceLogs $svc $since).Count -eq 0) {
    Warn "$name is running; no readable log source, confirm Healthy in the Cloudflare dashboard"
  } else { Bad "$name did not register within ${WaitSeconds}s, rolling back"; Restore-Run $NewRunId; exit 1 }
}

function Edit-ComposeProtocol([string]$f) {
  $text = [IO.File]::ReadAllText($f)
  if ($text -match '--protocol|TUNNEL_TRANSPORT_PROTOCOL') { return 2 }
  $lines = $text -split "`r?`n", 0
  $nl = if ($text -match "`r`n") { "`r`n" } else { "`n" }
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^(\s*command:\s*["'']?.*?\btunnel)\b(.*)$') {
      $lines[$i] = $Matches[1] + ' --protocol http2' + $Matches[2]
      [IO.File]::WriteAllText($f, ($lines -join $nl), $Utf8NoBom); return 0
    }
    if ($lines[$i] -match '^(\s*-\s*)(["'']?)tunnel\2\s*$') {
      $p = $Matches[1]
      $out = @($lines[0..$i]) + ($p + '--protocol') + ($p + 'http2')
      if ($i + 1 -lt $lines.Count) { $out += $lines[($i + 1)..($lines.Count - 1)] }
      [IO.File]::WriteAllText($f, ($out -join $nl), $Utf8NoBom); return 0
    }
  }
  return 1
}
function Recreate-Compose($c, $f) {
  $p = Get-ComposeProject $c
  docker compose -p $p -f $f config -q
  if ($LASTEXITCODE -ne 0) { return $false }
  $since = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  docker compose -p $p -f $f up -d --force-recreate 2>&1 | Select-Object -Last 2 | ForEach-Object { Say "    $_" }
  return (Wait-DockerRegistered $c $since)
}
function Apply-Docker($c) {
  $f = Get-ComposeFile $c
  if (-not $f) { Warn "$c is not a compose container. Recreate it by hand with: tunnel --protocol http2 run ..."; return }
  New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
  $bak = Join-Path $RunDir "$c.compose.bak"
  Copy-Item -LiteralPath $f -Destination $bak -Force
  $rc = Edit-ComposeProtocol $f
  if ($rc -eq 2) { Ok "$c already pins a protocol, nothing to change"; Remove-Item $bak; return }
  if ($rc -ne 0) { Bad "${c}: could not find the tunnel command in $f"; Remove-Item $bak; return }
  Record 'compose' $c $f $bak
  if (Recreate-Compose $c $f) { Ok "$c registered with http2" }
  else { Bad "$c did not register within ${WaitSeconds}s, rolling back"; Restore-Run $NewRunId; exit 1 }
}
function Upgrade-Docker($c) {
  if (-not $Version) { throw 'Upgrade needs -Version, for example 2026.10.1' }
  $f = Get-ComposeFile $c
  if (-not $f) { Warn "$c is not a compose container, skip"; return }
  $ref = "${Image}:$Version"
  Say "  pulling $ref ..."
  docker pull $ref | Out-Null
  if ($LASTEXITCODE -ne 0) { Bad 'pull failed, nothing changed'; return }
  New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
  $bak = Join-Path $RunDir "$c.compose.bak"
  Copy-Item -LiteralPath $f -Destination $bak -Force
  Record 'compose' $c $f $bak
  $text = [IO.File]::ReadAllText($f) -replace '(?m)^(\s*image:\s*).*cloudflared.*$', ('${1}' + $ref)
  [IO.File]::WriteAllText($f, $text, $Utf8NoBom)
  if (Recreate-Compose $c $f) { Ok "$c now runs $(Get-ContainerVersion $c)" }
  else { Bad "$c did not register after upgrade, rolling back"; Restore-Run $NewRunId; exit 1 }
}

function Restore-Run($id) {
  $manifest = Join-Path $StateDir "runs\$id\manifest.tsv"
  if (-not (Test-Path -LiteralPath $manifest)) { throw "no such run: $id" }
  foreach ($row in Get-Content -LiteralPath $manifest) {
    $kind, $name, $path, $bak = $row.Split("`t")
    switch ($kind) {
      'compose' {
        Copy-Item -LiteralPath $bak -Destination $path -Force
        docker compose -p (Get-ComposeProject $name) -f $path up -d --force-recreate 2>&1 | Out-Null
        Ok "restored $name from $bak"
      }
      'service' {
        # reg import merges, so drop the value we added before restoring the export
        Remove-ItemProperty -Path $path -Name Environment -ErrorAction SilentlyContinue
        & reg.exe import $bak 2>&1 | Out-Null
        Restart-Service -Name $name -Force -ErrorAction SilentlyContinue
        Ok "restored $name service settings"
      }
    }
  }
}

# ---------- main ----------
Say "Tunnel Doctor (Windows) mode=$Mode run=$NewRunId"
$services = @(Get-ServiceTargets)
$containers = @(Get-DockerTargets)
if ($Mode -ne 'Rollback' -and $services.Count -eq 0 -and $containers.Count -eq 0) {
  Say 'No cloudflared service or container found on this computer.'; exit 0
}
switch ($Mode) {
  'Audit' {
    Check-Edge
    foreach ($s in $services) { Audit-Service $s }
    foreach ($c in $containers) { Audit-Docker $c }
  }
  'Apply' {
    Check-Edge
    if ($services.Count -gt 0) { Need-Admin }
    foreach ($s in $services) { Apply-Service $s }
    foreach ($c in $containers) { Apply-Docker $c }
  }
  'Upgrade' {
    foreach ($c in $containers) { Upgrade-Docker $c }
    if ($services.Count -gt 0) { Say 'Service installs: upgrade the binary with "winget upgrade --id Cloudflare.cloudflared" or the official MSI, then run Apply again.' }
  }
  'Rollback' {
    if (-not $RunId) { throw 'Rollback needs -RunId' }
    Need-Admin; Restore-Run $RunId
  }
}
if (Test-Path -LiteralPath (Join-Path $RunDir 'manifest.tsv')) {
  Say "Run id: $NewRunId  (rollback: -Mode Rollback -RunId $NewRunId)"
}
