#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
ADB_BIN="${ADB_BIN:-adb}"
APK="$ROOT/app/build/outputs/apk/debug/app-debug.apk"
DEVICE="${DEVICE:-<DEVICE_IP>:5555}"
command -v "$ADB_BIN" >/dev/null || { print -u2 'adb not found'; exit 1; }
[[ -f "$APK" ]] || { print -u2 'APK not found; build it first'; exit 1; }
print 'This script only installs the local APK; it never flashes partitions or removes apps.'
read "answer?Connect to ${DEVICE} and install the APK? [y/N] "
[[ "$answer" == [yY] ]] || exit 0
"$ADB_BIN" connect "$DEVICE"
"$ADB_BIN" -s "$DEVICE" wait-for-device
"$ADB_BIN" -s "$DEVICE" install -r "$APK"
"$ADB_BIN" -s "$DEVICE" shell am start -n com.xiaozhi.x08c/.MainActivity
"$ADB_BIN" -s "$DEVICE" shell dumpsys package com.xiaozhi.x08c | grep -E 'versionName|versionCode'
