# PhET offline classroom kit for Windows 11 (Windows PowerShell 5.1 or PowerShell 7)
# Downloads official single-file HTML5 sims from phet.colorado.edu and builds a local index.html.
# Sims: PhET Interactive Simulations, University of Colorado Boulder, CC BY-NC 4.0.
[CmdletBinding()]
param(
  [ValidatePattern('^[A-Za-z_]+$')][string]$Lang = 'zh_CN',
  [string]$Sims = 'projectile-motion,circuit-construction-kit-dc,forces-and-motion-basics,energy-skate-park-basics,gravity-and-orbits,wave-on-a-string,bending-light,color-vision,states-of-matter,build-an-atom,ph-scale,balancing-chemical-equations,fractions-intro,graphing-lines,natural-selection',
  [switch]$All,
  [string]$Out = '',
  [switch]$Open,
  [switch]$AllowStats
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$Base = 'https://phet.colorado.edu'
$Query = if ($AllowStats) { "" } else { "?yotta=false" }
if (-not $Out) { $Out = Join-Path (Get-Location) "phet-offline-$Lang" }
$SimDir = Join-Path $Out 'sims'
New-Item -ItemType Directory -Force -Path $SimDir | Out-Null
$Out = (Resolve-Path $Out).Path

function Get-File([string]$Url, [string]$Dest) {
  for ($i = 1; $i -le 3; $i++) {
    try { Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing -TimeoutSec 120; return $true }
    catch {
      $code = $null
      if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
      if ($code -eq 404) { return $false }
      Start-Sleep -Seconds 2
    }
  }
  return $false
}

function Test-Sim([string]$Path) {
  (Test-Path $Path) -and ((Get-Item $Path).Length -gt 0) -and (Select-String -Path $Path -Pattern 'phet-sim-level' -SimpleMatch -Quiet)
}

if ($All) {
  Write-Host '[1/3] Reading the official sim list...'
  $meta = Invoke-RestMethod -Uri "$Base/services/metadata/1.3/simulations?format=json&type=html&summary" -UseBasicParsing
  $Sims = ($meta.projects | ForEach-Object { $_.name -replace '^html/', '' } | Sort-Object -Unique) -join ','
}

$list = $Sims.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
Write-Host "[2/3] Downloading $($list.Count) sims ($Lang) to $SimDir"
$ok = 0; $miss = 0; $rows = New-Object System.Text.StringBuilder
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("phet-" + [guid]::NewGuid().ToString('N') + '.html')
foreach ($sim in $list) {
  if ($sim -notmatch '^[a-z0-9-]+$') { Write-Host "  skip invalid name: $sim"; continue }
  $got = $null
  foreach ($lc in @($Lang, 'en') | Select-Object -Unique) {
    $f = Join-Path $SimDir "${sim}_$lc.html"
    if (Test-Sim $f) { $got = $lc; break }
    if ((Get-File "$Base/sims/html/$sim/latest/${sim}_$lc.html" $tmp) -and (Test-Sim $tmp)) {
      Move-Item -Force $tmp $f; $got = $lc; break
    }
  }
  if (-not $got) { Write-Host "  MISSING  $sim"; $miss++; continue }
  $head = Get-Content -Path (Join-Path $SimDir "${sim}_$got.html") -TotalCount 40 -Encoding UTF8 | Out-String
  $title = $sim
  if ($head -match '<title>([^<]*)</title>') { $title = ($Matches[1] -replace '&#8234;|&#8236;', '') }
  $note = ''; if ($got -ne $Lang) { $note = ' <small>(en)</small>' }
  [void]$rows.Append("<li><a href=""sims/${sim}_$got.html$Query"">$title</a>$note<span>$sim</span></li>")
  Write-Host "  OK       $sim ($got)"; $ok++
}
Remove-Item -Force -ErrorAction SilentlyContinue $tmp

Write-Host '[3/3] Writing index.html and SHA256SUMS.txt'
$html = @"
<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>PhET 离线实验室 / Offline Lab</title>
<style>
body{font-family:system-ui,"PingFang SC","Microsoft YaHei","Noto Sans CJK SC",sans-serif;margin:0;background:#f6f3ec;color:#1d2a3a}
header{background:#1d3557;color:#fff;padding:28px 24px}h1{margin:0 0 6px;font-size:28px}
ul{list-style:none;margin:0;padding:20px;display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:14px}
li{background:#fff;border-radius:12px;padding:16px;box-shadow:0 1px 3px #0002}
a{font-size:19px;color:#1d3557;font-weight:600;text-decoration:none}a:hover{text-decoration:underline}
span{display:block;color:#6b7785;font-size:13px;margin-top:6px}footer{padding:0 24px 28px;color:#6b7785;font-size:13px}
</style></head><body>
<header><h1>PhET 离线实验室 / Offline Lab</h1><div>$ok sims · $Lang · 断网可用 / works offline</div></header>
<ul>$($rows.ToString())</ul>
<footer>Simulation by PhET Interactive Simulations, University of Colorado Boulder, licensed under CC BY-NC 4.0 (https://phet.colorado.edu). Non-commercial use only.</footer>
</body></html>
"@
[IO.File]::WriteAllText((Join-Path $Out 'index.html'), $html, (New-Object System.Text.UTF8Encoding($false)))
$sums = Get-ChildItem -Path (Join-Path $Out 'index.html'), (Join-Path $SimDir '*.html') | ForEach-Object {
  $rel = $_.FullName.Substring($Out.Length + 1) -replace '\\', '/'
  "{0}  {1}" -f (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLower(), $rel
}
[IO.File]::WriteAllLines((Join-Path $Out 'SHA256SUMS.txt'), $sums)

Write-Host "Done: $ok OK, $miss missing. Open: $(Join-Path $Out 'index.html')"
if ($Open) { Start-Process (Join-Path $Out 'index.html') }
if ($ok -eq 0) { exit 1 }
if ($miss -gt 0) { exit 2 }
exit 0
