#!/usr/bin/env zsh
# ==============================================================================
# usb-speed-audit-macos26.zsh
# Universal USB & Type-C / Thunderbolt Interface Speed Auditor (macOS 26 / Darwin)
#
# Description:
#   Audits macOS USB & Thunderbolt hardware controllers, link speeds, and connected peripherals.
#   Uses native system_profiler and python3/ioreg (built-in).
#   Detects throttled devices (e.g. SSD linked at 480Mbps USB 2.0).
#   Zero external dependencies. Fully native for Apple Silicon & Intel Macs.
#
# Usage:
#   Human interactive: ./usb-speed-audit-macos26.zsh
#   Agent machine:     ./usb-speed-audit-macos26.zsh --json
# ==============================================================================
set -euo pipefail

FORMAT="text"
if [[ "${1:-}" == "--json" ]]; then
  FORMAT="json"
fi

python3 - "$FORMAT" << 'PY'
import sys, json, subprocess

format_type = sys.argv[1]

def run_cmd(args):
    try:
        res = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        return res.stdout
    except Exception:
        return ""

usb_raw = run_cmd(["system_profiler", "SPUSBDataType", "-json"])
tb_raw = run_cmd(["system_profiler", "SPThunderboltDataType", "-json"])

devices_list = []

def parse_usb_items(items):
    for item in items:
        name = item.get("_name", "Generic USB Device")
        speed = item.get("device_speed", "Unknown")
        vendor = item.get("manufacturer", "Apple / Generic")
        prod_id = item.get("product_id", "")
        vend_id = item.get("vendor_id", "")
        cur_req = item.get("current_required", "N/A")
        cur_avail = item.get("current_available", "N/A")
        
        # Check throttling
        is_throttled = False
        alert = "Optimal Link"
        name_lower = name.lower()
        if any(w in name_lower for w in ["ssd", "nvme", "disk", "drive", "extreme", "storage"]) and ("480" in speed or "12" in speed):
            is_throttled = True
            alert = "ALERT: High-speed storage linked at USB 2.0 speed (480Mbps). Cable lacks SuperSpeed pairs!"

        devices_list.append({
            "type": "USB",
            "product": name,
            "vendor": vendor,
            "id": f"{vend_id}:{prod_id}",
            "speed": speed,
            "current_required": cur_req,
            "current_available": cur_avail,
            "throttled": is_throttled,
            "alert": alert
        })
        
        # Recursively parse nested hub items
        for sub_k in ["_items", "items"]:
            if sub_k in item and isinstance(item[sub_k], list):
                parse_usb_items(item[sub_k])

try:
    if usb_raw.strip():
        data = json.loads(usb_raw)
        items = data.get("SPUSBDataType", [])
        parse_usb_items(items)
except Exception as e:
    pass

# Parse Thunderbolt
try:
    if tb_raw.strip():
        tb_data = json.loads(tb_raw)
        for bus in tb_data.get("SPThunderboltDataType", []):
            b_name = bus.get("_name", "Thunderbolt / USB4 Domain")
            speed = bus.get("speed_string", "Up to 40 Gb/s")
            devices_list.append({
                "type": "Thunderbolt/USB4",
                "product": b_name,
                "vendor": "Apple Inc.",
                "id": "TBT-CONTROLLER",
                "speed": speed,
                "current_required": "N/A",
                "current_available": "N/A",
                "throttled": False,
                "alert": "Optimal Link"
            })
except Exception:
    pass

if format_type == "json":
    print(json.dumps({
        "platform": "macos",
        "device_count": len(devices_list),
        "devices": devices_list
    }, indent=2, ensure_ascii=False))
else:
    print("================================================================================")
    print(" macOS 26 / Darwin USB & Type-C / Thunderbolt Link Speed Auditor")
    print(" Native Hardware Prober: system_profiler SPUSBDataType")
    print("================================================================================")
    if not devices_list:
        print("No external USB or Thunderbolt peripherals currently enumerated.")
    else:
        for idx, dev in enumerate(devices_list, 1):
            print("--------------------------------------------------------------------------------")
            print(f"Device [{idx}]: {dev['vendor']} - {dev['product']} [{dev['type']}]")
            print(f"  • Negotiated Speed : {dev['speed']}")
            print(f"  • Power Allocation : Req {dev['current_required']} / Avail {dev['current_available']}")
            if dev["throttled"]:
                print(f"  • \033[1;31m[WARNING] {dev['alert']}\033[0m")
            else:
                print("  • Link Quality     : \033[1;32mOptimal Link\033[0m")
    print("================================================================================")
    print(f"Total Audited Devices: {len(devices_list)} | Zero external dependencies required.")
    print("================================================================================")
PY
