#!/usr/bin/env bash
# ==============================================================================
# airprint_toolkit_ubuntu2604.sh
# One-Click AirPrint Automated Diagnostic & Repair Toolkit for Ubuntu 26.04 LTS
# Restores iOS 27 AirPrint compatibility for local printers & CUPS print queues.
# No third-party cloud service dependencies.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
      echo "Usage: sudo $0 [--apply] [--verbose] [--plan <plan.json>]" >&2
      exit 1
      ;;
  esac
done

echo "=================================================================="
echo "  iOS 27 AirPrint Compatibility Toolkit (Ubuntu 26.04 LTS)"
echo "=================================================================="

# Check Root privileges for apply
if [[ "$APPLY" -eq 1 && "$EUID" -ne 0 ]]; then
  echo "[-] Error: --apply requires root privileges. Please run with sudo." >&2
  exit 1
fi

# Step 1: Check Required Packages
echo "[1/5] Verifying CUPS & Avahi subsystem..."
MISSING_PKGS=()
for pkg in cups avahi-daemon cups-filters cups-ipp-utils; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    MISSING_PKGS+=("$pkg")
  fi
done

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
  echo "      [!] Missing required packages: ${MISSING_PKGS[*]}"
  if [[ "$APPLY" -eq 1 ]]; then
    echo "      [*] Installing missing packages via apt-get..."
    apt-get update -qq && apt-get install -y -qq "${MISSING_PKGS[@]}"
  else
    echo "      [!] Dry-run: Run with --apply to automatically install."
  fi
else
  echo "      [✓] All required packages installed."
fi

# Step 2: Configure Firewall (UFW / iptables)
echo "[2/5] Auditing Local Firewall Rules (Port 631 TCP & 5353 UDP)..."
if command -v ufw >/dev/null 2>&1 && ufw status | grep -qw "active"; then
  echo "      [*] UFW is active. Checking rules..."
  if [[ "$APPLY" -eq 1 ]]; then
    ufw allow in proto tcp to any port 631 comment "AirPrint IPP" >/dev/null
    ufw allow in proto udp to any port 5353 comment "Bonjour mDNS" >/dev/null
    echo "      [✓] Inbound rules for TCP 631 & UDP 5353 ensured."
  fi
else
  echo "      [✓] No blocking local UFW detected."
fi

# Step 3: Run Core Automation Engine
echo "[3/5] Executing Core Protocol Audit & Avahi Service Synthesis..."
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

# Step 4: Validate Active CUPS Queues
echo "[4/5] Checking active CUPS print queues..."
if command -v lpstat >/dev/null 2>&1; then
  lpstat -p || echo "      [!] No local printers configured in CUPS yet."
fi

# Step 5: Verification Summary
echo "[5/5] mDNS Service Discovery Verification..."
if command -v avahi-browse >/dev/null 2>&1; then
  echo "      [*] Querying local _ipp._tcp records (timeout 2s)..."
  timeout 2 avahi-browse -rt _ipp._tcp 2>/dev/null | grep -E "hostname|address|txt" | head -n 10 || true
fi

echo "=================================================================="
echo "  [✓] Ubuntu 26.04 AirPrint Toolkit Completed Successfully."
echo "=================================================================="
