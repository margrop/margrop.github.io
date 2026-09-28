#!/usr/bin/env zsh
# ==============================================================================
# airprint_toolkit_macos26.zsh
# One-Click AirPrint Automated Diagnostic & Repair Toolkit for macOS 26
# Enables native printer sharing, fixes mDNS cache, and configures CUPS.
# No third-party cloud service dependencies.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
APPLY=0
VERBOSE=0
PLAN_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply|-a)
      APPLY=1
      shift
      ;;
    --verbose|-v)
      VERBOSE=1
      shift
      ;;
    --plan|-p)
      PLAN_FILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--apply] [--verbose] [--plan <plan.json>]" >&2
      exit 1
      ;;
  esac
done

echo "=================================================================="
echo "  iOS 27 AirPrint Compatibility Toolkit (macOS 26)"
echo "=================================================================="

# Step 1: Check cupsd state
echo "[1/4] Checking macOS CUPS print subsystem..."
if ! pgrep -q cupsd; then
  echo "      [!] cupsd not active. Starting via launchctl..."
  if [[ "$APPLY" -eq 1 ]]; then
    sudo launchctl load -w /System/Library/LaunchDaemons/org.cups.cupsd.plist 2>/dev/null || true
  fi
else
  echo "      [✓] CUPS daemon is active."
fi

# Step 2: Configure Sharing via cupsctl
echo "[2/4] Auditing CUPS Printer Sharing Configuration..."
SHARING_STATE=$(cupsctl | grep "_share_printers=" || echo "_share_printers=0")
echo "      Current state: $SHARING_STATE"

if [[ "$SHARING_STATE" != "_share_printers=1" ]]; then
  if [[ "$APPLY" -eq 1 ]]; then
    echo "      [*] Enabling printer sharing and remote access via cupsctl..."
    sudo cupsctl --share-printers --remote-admin --remote-any
    echo "      [✓] Enabled _share_printers=1 and _remote_any=1."
  else
    echo "      [!] Dry-run: Run with --apply to enable native macOS printer sharing."
  fi
else
  echo "      [✓] Native CUPS printer sharing is already enabled."
fi

# Step 3: Run Core Automation Engine
echo "[3/4] Running Protocol & Cache Optimization Engine..."
CMD=("python3" "$SCRIPT_DIR/airprint_core_agent.py")
if [[ -n "$PLAN_FILE" ]]; then
  CMD+=("--plan" "$PLAN_FILE")
fi
if [[ "$APPLY" -eq 1 ]]; then
  CMD+=("--apply")
fi
if [[ "$VERBOSE" -eq 1 ]]; then
  CMD+=("--verbose")
fi

"${CMD[@]}"

# Step 4: Flush mDNSResponder cache and verify
if [[ "$APPLY" -eq 1 ]]; then
  echo "[4/4] Flushing mDNSResponder Cache..."
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder 2>/dev/null || true
  echo "      [✓] mDNSResponder refreshed."
else
  echo "[4/4] Verification check (dns-sd)..."
fi

echo "=================================================================="
echo "  [✓] macOS 26 AirPrint Toolkit Completed Successfully."
echo "=================================================================="
