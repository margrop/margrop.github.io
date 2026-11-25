#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADB_BIN="${ADB_BIN:-adb}"
APK="$ROOT/app/build/outputs/apk/debug/app-debug.apk"
DEVICE="${DEVICE:-<DEVICE_IP>:5555}"
command -v "$ADB_BIN" >/dev/null || { echo "adb not found" >&2; exit 1; }
test -f "$APK" || { echo "APK not found; build it first" >&2; exit 1; }
printf 'This script only installs the local APK; it never flashes partitions or removes apps.\n'
read -r -p "Connect to ${DEVICE} and install the APK? [y/N] " answer
[[ "$answer" == "y" || "$answer" == "Y" ]] || exit 0
"$ADB_BIN" connect "$DEVICE"
"$ADB_BIN" -s "$DEVICE" wait-for-device
"$ADB_BIN" -s "$DEVICE" install -r "$APK"
"$ADB_BIN" -s "$DEVICE" shell am start -n com.xiaozhi.x08c/.MainActivity
"$ADB_BIN" -s "$DEVICE" shell dumpsys package com.xiaozhi.x08c | grep -E 'versionName|versionCode'
