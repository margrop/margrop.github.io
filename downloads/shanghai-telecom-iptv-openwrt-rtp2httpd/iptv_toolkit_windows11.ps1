<#
==============================================================================
 iptv_toolkit_windows11.ps1
 上海电信 IPTV -> OpenWrt/ImmortalWrt + rtp2httpd 一键配置（Windows 11 原生）
 需与 iptv_router_payload.sh 放在同一目录。只依赖系统自带的 PowerShell / OpenSSH 客户端 / curl.exe，不访问任何第三方服务。

   体检（只读）: powershell -ExecutionPolicy Bypass -File .\iptv_toolkit_windows11.ps1 -Router 192.168.x.1
   一键配置    : ... -Router 192.168.x.1 -Mode apply [-Pve 192.168.x.10 -VmId 101 -Bridge vmbr1]
   一键回滚    : ... -Router 192.168.x.1 -Mode rollback -Yes [-Pve 192.168.x.10 -VmId 101]
==============================================================================
#>
param(
  [Parameter(Mandatory = $true)][string]$Router,
  [ValidateSet('check', 'apply', 'rollback')][string]$Mode = 'check',
  [string]$Pve = '',
  [string]$VmId = '',
  [string]$Bridge = 'vmbr1',
  [int]$Vlan = 85,
  [string]$User = 'root',
  [string]$IptvDev = 'auto',
  [int]$Port = 5140,
  [switch]$NoFcc,
  [switch]$ScanAll,
  [switch]$Yes,
  [string]$OutDir = (Join-Path $HOME ("iptv-toolkit-" + (Get-Date -Format 'yyyyMMdd-HHmmss')))
)
$ErrorActionPreference = 'Stop'
$FccNet = '124.75.25'; $FccId = '211'; $FccPort = '7777'   # 上海电信 FCC 服务器（社区公开）
$Fcc = if ($NoFcc) { '' } else { "$FccNet.$($FccId):$FccPort" }
if ($Pve -and -not $VmId) { throw '-Pve 需要同时指定 -VmId' }

function Mask([string]$s) { $s -replace '(\d+\.\d+)\.\d+\.\d+', '$1.x.x' }
function Info([string]$m) { Write-Host "[local] $m" -ForegroundColor Cyan }
function Ok([string]$m) { Write-Host "[local] OK   $m" -ForegroundColor Green }
function Die([string]$m) { Write-Host "[local] FAIL $m" -ForegroundColor Red; exit 1 }

$SshOpts = '-o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=15'

# Run ssh with exact bytes on stdin/stdout (no CRLF or UTF-16 conversion).
function Invoke-Ssh {
  param([string]$Target, [string]$Command, [byte[]]$InputBytes = $null, [string]$OutFile = '', [switch]$Capture)
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'ssh'
  $psi.Arguments = "$SshOpts $Target `"$($Command -replace '"', '\"')`""
  $psi.UseShellExecute = $false
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = [bool]($OutFile -or $Capture)
  $p = [System.Diagnostics.Process]::Start($psi)
  if ($InputBytes) { $p.StandardInput.BaseStream.Write($InputBytes, 0, $InputBytes.Length) }
  $p.StandardInput.Close()
  $text = $null
  if ($OutFile) {
    $fs = [System.IO.File]::Create($OutFile); $p.StandardOutput.BaseStream.CopyTo($fs); $fs.Close()
  } elseif ($Capture) {
    $ms = New-Object System.IO.MemoryStream; $p.StandardOutput.BaseStream.CopyTo($ms)
    $text = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
  }
  $p.WaitForExit()
  if ($p.ExitCode -ne 0) { throw "ssh $Target exited with $($p.ExitCode)" }
  return $text
}
function RouterSsh([string]$c, [switch]$Capture) { Invoke-Ssh -Target "$User@$Router" -Command $c -Capture:$Capture }
function PveSsh([string]$c, [switch]$Capture) { Invoke-Ssh -Target "root@$Pve" -Command $c -Capture:$Capture }

# 路由器端逻辑（POSIX sh）放在同目录的 iptv_router_payload.sh，按原始字节读取并去掉 CR
$PayloadFile = Join-Path $PSScriptRoot 'iptv_router_payload.sh'
if (-not (Test-Path $PayloadFile)) { Die "找不到 $PayloadFile（请和本脚本放在同一目录）" }
$PayloadBytes = [byte[]]([System.IO.File]::ReadAllBytes($PayloadFile) | Where-Object { $_ -ne 13 })

function Run-Payload([string]$m, [string]$dev) {
  Invoke-Ssh -Target "$User@$Router" -Command "MODE=$m IPTV_DEV=$dev LISTEN_PORT=$Port FCC='$Fcc' SCAN_ALL=$([int][bool]$ScanAll) sh -s" -InputBytes $PayloadBytes | Out-Null
}
function Router-Devs { (RouterSsh 'ls /sys/class/net' -Capture) -split "\s+" | Where-Object { $_ -match '^eth\d+$' } | Sort-Object }
function Pve-IptvNet {
  $cfg = PveSsh "qm config $VmId" -Capture
  foreach ($line in ($cfg -split "`n")) {
    if ($line -match "^(net\d+): .*bridge=$Bridge(,.*)?,tag=$Vlan(,.*)?$") { return $Matches[1] }
  }
  return ''
}

# 1. preflight
Info "目标路由器: $(Mask $Router)   模式: $Mode"
try { RouterSsh 'true' | Out-Null } catch { Write-Host "[local] $($_.Exception.Message)" -ForegroundColor DarkGray; Die "SSH 免密登录路由器失败，请先把公钥加入路由器（type `$env:USERPROFILE\.ssh\id_ed25519.pub | ssh $User@<路由器> 'cat >> /etc/dropbear/authorized_keys'）" }
Ok 'SSH 连通'
if ($Pve) {
  try { PveSsh "qm config $VmId >/dev/null" | Out-Null } catch { Die "PVE 上找不到 VM $VmId 或 SSH 失败" }
  Ok "PVE 连通，VM $VmId 存在"
}

switch ($Mode) {
  'check' {
    Run-Payload 'check' 'auto'
    if ($Pve) { $n = Pve-IptvNet; if ($n) { Ok "PVE 已有 IPTV 网卡: $n (tag=$Vlan)" } else { Info "PVE 尚未添加 tag=$Vlan 网卡" } }
  }
  'apply' {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $bk = Join-Path $OutDir 'router-backup.tgz'
    Invoke-Ssh -Target "$User@$Router" -Command 'sysupgrade -b /tmp/iptv-pre.tgz >/dev/null 2>&1 && cat /tmp/iptv-pre.tgz && rm -f /tmp/iptv-pre.tgz' -OutFile $bk | Out-Null
    if ((Get-Item $bk).Length -lt 1024) { Die '配置备份失败' }
    Ok "路由器配置已备份: $bk"
    $dev = $IptvDev
    if ($Pve) {
      PveSsh "cp /etc/pve/qemu-server/$VmId.conf /root/$VmId.conf.bak-iptv-$(Get-Date -Format yyyyMMddHHmmss)" | Out-Null
      $n = Pve-IptvNet
      if ($n) { Ok "PVE 已存在 IPTV 网卡 $n，跳过" }
      else {
        $before = Router-Devs
        $used = ((PveSsh "qm config $VmId" -Capture) -split "`n") | Where-Object { $_ -match '^net(\d+):' } | ForEach-Object { [int]($_ -replace '^net(\d+):.*', '$1') }
        $free = 0; while ($used -contains $free) { $free++ }
        PveSsh "qm set $VmId --net$free virtio,bridge=$Bridge,tag=$Vlan,firewall=0 >/dev/null 2>&1" | Out-Null
        Ok "PVE 已热插拔 net$free (bridge=$Bridge, tag=$Vlan)"
        $new = $null
        for ($i = 0; $i -lt 20 -and -not $new; $i++) {
          $new = Router-Devs | Where-Object { $before -notcontains $_ } | Select-Object -First 1
          if (-not $new) { Start-Sleep -Seconds 1 }
        }
        if (-not $new) { Die '路由器没有识别到新网卡（虚拟机可能不支持热插拔，重启 VM 后再试）' }
        $dev = $new; Ok "路由器识别到新网卡: $dev"
      }
    }
    Run-Payload 'apply' $dev
    $m3u = & curl.exe -s -m 10 "http://$($Router):$Port/playlist.m3u"
    $urls = @($m3u | Where-Object { $_ -like 'http*' })
    if ($urls.Count -eq 0) { Die '本机取不到播放列表' }
    $bytes = [int](& curl.exe -s -m 5 -o NUL -w '%{size_download}' $urls[0])
    Ok "本机验收: 播放列表 $($urls.Count) 个频道，5 秒拉流 $([int]($bytes / 1024)) KiB"
    Info "播放器填写: http://$(Mask $Router):$Port/playlist.m3u （把 x.x 换成你的路由器地址）"
  }
  'rollback' {
    if (-not $Yes) { if ((Read-Host '确认回滚 IPTV 配置？[y/N]') -notmatch '^[yY]$') { exit 0 } }
    Run-Payload 'rollback' 'auto'
    if ($Pve) {
      $n = Pve-IptvNet
      if ($n) { PveSsh "qm set $VmId --delete $n >/dev/null 2>&1" | Out-Null; Ok "PVE 已移除 $n" } else { Info 'PVE 上没有需要移除的 IPTV 网卡' }
    }
  }
}
Ok '完成'
