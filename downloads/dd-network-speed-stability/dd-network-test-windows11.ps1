[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^[A-Za-z0-9._:-]+$')][string]$RemoteHost,
    [ValidatePattern('^[A-Za-z0-9._-]+$')][string]$RemoteUser = $env:USERNAME,
    [ValidateRange(1, 65535)][int]$Port = 22,
    [ValidateRange(1, 1024)][int]$SizeMiB = 16,
    [ValidateRange(1, 100)][int]$Rounds = 5,
    [ValidateSet('upload', 'download', 'both')][string]$Direction = 'both',
    [switch]$DryRun
)

# Windows 11 version. It uses the inbox OpenSSH client and .NET byte streams;
# the remote side runs dd and discards data in /dev/null. No WSL is required.

$ErrorActionPreference = 'Stop'
$ssh = (Get-Command ssh.exe -ErrorAction SilentlyContinue).Source
if (-not $ssh) { throw 'ssh.exe was not found. Enable Windows OpenSSH Client first.' }
if ([string]::IsNullOrWhiteSpace($RemoteUser)) { $RemoteUser = 'testuser' }
$target = "$RemoteUser@$RemoteHost"
$common = @(
    '-T', '-p', "$Port", '-o', 'BatchMode=yes', '-o', 'Compression=no',
    '-o', 'ConnectTimeout=10', '-o', 'ServerAliveInterval=5',
    '-o', 'ServerAliveCountMax=2', '-o', 'StrictHostKeyChecking=accept-new',
    '-o', 'LogLevel=ERROR'
)

function New-SshProcess([string]$RemoteCommand) {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $ssh
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    # ArgumentList exists in modern .NET. The Arguments fallback keeps this
    # script usable in Windows PowerShell 5.1, which is still inbox on Win11.
    if ($psi.PSObject.Properties.Name -contains 'ArgumentList') {
        foreach ($arg in ($common + @($target, $RemoteCommand))) { [void]$psi.ArgumentList.Add($arg) }
    } else {
        $safe = ($RemoteCommand -replace '"', '\"')
        $psi.Arguments = (($common + @($target)) -join ' ') + ' "' + $safe + '"'
    }
    $p = [System.Diagnostics.Process]::new()
    $p.StartInfo = $psi
    [void]$p.Start()
    return $p
}

function Invoke-Transfer([string]$Mode, [int]$Round) {
    $remoteCommand = if ($Mode -eq 'upload') {
        "dd iflag=fullblock of=/dev/null bs=1048576 count=$SizeMiB 2>/dev/null"
    } else {
        "dd iflag=fullblock if=/dev/zero bs=1048576 count=$SizeMiB 2>/dev/null"
    }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $p = $null
    $stderrTask = $null
    try {
        $p = New-SshProcess $remoteCommand
        $stderrTask = $p.StandardError.ReadToEndAsync()
        if ($Mode -eq 'upload') {
            $zero = New-Object byte[] (1MB)
            for ($i = 0; $i -lt $SizeMiB; $i++) {
                if ($sw.Elapsed.TotalSeconds -gt 120) { throw 'transfer timeout' }
                $p.StandardInput.BaseStream.Write($zero, 0, $zero.Length)
            }
            $p.StandardInput.Close()
            [void]$p.StandardOutput.ReadToEndAsync()
        } else {
            $p.StandardOutput.BaseStream.CopyTo([System.IO.Stream]::Null)
        }
        if (-not $p.WaitForExit(120000)) { $p.Kill(); throw 'transfer timeout' }
        $rc = $p.ExitCode
        $stderr = if ($stderrTask) { $stderrTask.Result.Trim() } else { '' }
    } catch {
        if ($p -and -not $p.HasExited) { $p.Kill() }
        $rc = 124
        $stderr = $_.Exception.Message
    }
    $sw.Stop()
    $seconds = [math]::Max($sw.Elapsed.TotalSeconds, 0.000001)
    $rate = $SizeMiB / $seconds
    if ($rc -eq 0) {
        Write-Host ("{0} round={1} rc=0 seconds={2:N6} MiB={3} throughput={4:N1} MiB/s" -f $Mode, $Round, $seconds, $SizeMiB, $rate)
    } else {
        Write-Host ("{0} round={1} rc={2} seconds={3:N6} FAIL" -f $Mode, $Round, $rc, $seconds)
        if ($stderr) { Write-Warning (($stderr -split "`r?`n")[0]) }
    }
    [pscustomobject]@{ Mode = $Mode; Rc = $rc; Seconds = $seconds; Rate = $rate }
}

Write-Host "DD network lab: $SizeMiB MiB × $Rounds round(s), direction=$Direction"
Write-Host "Endpoint: $target`:$Port (bytes are discarded on both ends)"
if ($DryRun) {
    Write-Host "DRY-RUN upload: dd iflag=fullblock if=/dev/zero bs=1048576 count=$SizeMiB | ssh ... dd iflag=fullblock of=/dev/null"
    Write-Host "DRY-RUN download: ssh ... dd iflag=fullblock if=/dev/zero bs=1048576 count=$SizeMiB | dd iflag=fullblock of=/dev/null"
    exit 0
}

$results = @()
foreach ($mode in @('upload', 'download')) {
    if ($Direction -ne 'both' -and $Direction -ne $mode) { continue }
    for ($round = 1; $round -le $Rounds; $round++) { $results += Invoke-Transfer $mode $round }
}

foreach ($group in ($results | Group-Object Mode)) {
    $ok = @($group.Group | Where-Object Rc -eq 0)
    $rates = @($ok | ForEach-Object Rate)
    if ($rates.Count -gt 0) {
        $avg = ($rates | Measure-Object -Average).Average
        $min = ($rates | Measure-Object -Minimum).Minimum
        $max = ($rates | Measure-Object -Maximum).Maximum
        $variance = (($rates | ForEach-Object { ($_ - $avg) * ($_ - $avg) } | Measure-Object -Average).Average)
        $cv = if ($avg -gt 0) { [math]::Sqrt($variance) / $avg * 100 } else { 0 }
        $failed = @($group.Group | Where-Object Rc -ne 0).Count
        Write-Host ("SUMMARY {0} samples={1} avg={2:N1} MiB/s min={3:N1} max={4:N1} CV={5:N1}% failures={6}" -f $group.Name, $ok.Count, $avg, $min, $max, $cv, $failed)
    }
}
if (@($results | Where-Object Rc -ne 0).Count -gt 0) { exit 1 }
Write-Host 'Completed without transfer failures. Repeat at different times for a stability baseline.'
