$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Adb = if ($env:ADB_BIN) { $env:ADB_BIN } else { 'adb' }
$Apk = Join-Path $Root 'app/build/outputs/apk/debug/app-debug.apk'
$Device = if ($env:DEVICE) { $env:DEVICE } else { '<DEVICE_IP>:5555' }
if (-not (Get-Command $Adb -ErrorAction SilentlyContinue)) { throw 'adb not found' }
if (-not (Test-Path $Apk)) { throw 'APK not found; build it first' }
Write-Host 'This script only installs the local APK; it never flashes partitions or removes apps.'
$answer = Read-Host "Connect to $Device and install the APK? [y/N]"
if ($answer -notin @('y','Y')) { exit 0 }
& $Adb connect $Device
& $Adb -s $Device wait-for-device
& $Adb -s $Device install -r $Apk
& $Adb -s $Device shell am start -n com.xiaozhi.x08c/.MainActivity
& $Adb -s $Device shell dumpsys package com.xiaozhi.x08c | Select-String 'versionName|versionCode'
