#!/usr/bin/env bash
# ==============================================================================
# usb-speed-audit-ubuntu2604.sh
# Universal USB & Type-C / Thunderbolt Interface Speed Auditor (Ubuntu 26.04 / Linux)
#
# Description:
#   Audits local USB host controllers, ports, and connected devices.
#   Reads physical link speeds directly from Linux sysfs (/sys/bus/usb/devices).
#   Detects throttled devices (e.g. SSD running at 480Mbps USB 2.0 due to bad cable).
#   Zero external dependencies. Works out-of-the-box on Ubuntu 20.04/22.04/24.04/26.04.
#
# Usage:
#   Human interactive: ./usb-speed-audit-ubuntu2604.sh
#   Agent machine:     ./usb-speed-audit-ubuntu2604.sh --json
# ==============================================================================
set -euo pipefail

FORMAT="text"
if [[ "${1:-}" == "--json" ]]; then
  FORMAT="json"
fi

format_speed() {
  local sp="$1"
  case "$sp" in
    "1.5")   echo "1.5 Mbps (Low Speed - USB 1.0)" ;;
    "12")    echo "12 Mbps (Full Speed - USB 1.1)" ;;
    "480")   echo "480 Mbps (High Speed - USB 2.0)" ;;
    "5000")  echo "5.0 Gbps (SuperSpeed - USB 3.0 / 3.2 Gen 1)" ;;
    "10000") echo "10.0 Gbps (SuperSpeedPlus - USB 3.2 Gen 2)" ;;
    "20000") echo "20.0 Gbps (SuperSpeedPlus x2 - USB 3.2 Gen 2x2)" ;;
    "40000") echo "40.0 Gbps (USB4 Gen 3x2 / Thunderbolt 3/4)" ;;
    "80000") echo "80.0 Gbps (USB4 Gen 4 / Thunderbolt 5)" ;;
    "120000")echo "120.0 Gbps (Thunderbolt 5 Asymmetric)" ;;
    *)       echo "$sp Mbps (Custom/Unknown)" ;;
  esac
}

audit_devices() {
  local count=0
  local entries=()
  local throttled=()

  if [[ ! -d /sys/bus/usb/devices ]]; then
    echo "Error: /sys/bus/usb/devices not found. Is USB subsystem enabled?" >&2
    exit 1
  fi

  for dev in /sys/bus/usb/devices/*; do
    [[ -e "$dev" ]] || continue
    # Only target device endpoints, exclude interfaces like 1-1:1.0
    case "$dev" in
      *:*) continue ;;
    esac

    if [[ -f "$dev/speed" ]]; then
      local dev_name="$(basename "$dev")"
      local speed="$(cat "$dev/speed" 2>/dev/null || echo "Unknown")"
      local product="$(cat "$dev/product" 2>/dev/null || echo "Generic USB Device")"
      local vendor="$(cat "$dev/manufacturer" 2>/dev/null || echo "Unknown Vendor")"
      local vid="$(cat "$dev/idVendor" 2>/dev/null || echo "----")"
      local pid="$(cat "$dev/idProduct" 2>/dev/null || echo "----")"
      local power="$(cat "$dev/bMaxPower" 2>/dev/null || echo "Unknown")"
      local usb_ver="$(cat "$dev/version" 2>/dev/null || echo "Unknown")"
      local human_speed="$(format_speed "$speed")"

      local is_throttle=0
      local alert_msg="OK"

      # Heuristic detection: If storage or high-speed device is linked at 480Mbps or less
      local prod_lower="$(echo "$product" | tr '[:upper:]' '[:lower:]')"
      if [[ "$prod_lower" =~ ssd|nvme|extreme|disk|drive|storage|uasp|sata ]] && [[ "$speed" == "480" || "$speed" == "12" ]]; then
        is_throttle=1
        alert_msg="ALERT: High-speed storage is bottlenecked at USB 2.0 speed! Suspect charging-only cable."
      fi

      count=$((count + 1))

      if [[ "$FORMAT" == "json" ]]; then
        entries+=("{\"device\":\"$dev_name\",\"vendor\":\"$vendor\",\"product\":\"$product\",\"id\":\"$vid:$pid\",\"speed_mbps\":\"$speed\",\"speed_human\":\"$human_speed\",\"usb_version\":\"$usb_ver\",\"max_power\":\"$power\",\"throttled\":$is_throttle,\"alert\":\"$alert_msg\"}")
      else
        echo "--------------------------------------------------------------------------------"
        printf "Device [%s]: %s - %s (ID: %s:%s)\n" "$dev_name" "$vendor" "$product" "$vid" "$pid"
        printf "  • Negotiated Speed : %s\n" "$human_speed"
        printf "  • USB Spec Version : USB %s\n" "$usb_ver"
        printf "  • Max Power Draw   : %s\n" "$power"
        if [[ $is_throttle -eq 1 ]]; then
          printf "  • \033[1;31m[WARNING] %s\033[0m\n" "$alert_msg"
        else
          printf "  • Status           : \033[1;32mOptimal Link\033[0m\n"
        fi
      fi
    fi
  done

  if [[ "$FORMAT" == "json" ]]; then
    local joined=""
    for item in "${entries[@]}"; do
      if [[ -z "$joined" ]]; then
        joined="$item"
      else
        joined="$joined,$item"
      fi
    done
    echo "{\"platform\":\"ubuntu-linux\",\"device_count\":$count,\"devices\":[$joined]}"
  else
    echo "================================================================================"
    echo "Total Audited USB / Type-C Devices: $count"
    echo "Finished link speed audit. Zero external dependencies required."
    echo "================================================================================"
  fi
}

if [[ "$FORMAT" == "text" ]]; then
  echo "================================================================================"
  echo " Ubuntu 26.04 / Linux USB & Type-C / Thunderbolt Link Speed Auditor"
  echo " Host Kernel: $(uname -r) | Host Architecture: $(uname -m)"
  echo "================================================================================"
fi

audit_devices
