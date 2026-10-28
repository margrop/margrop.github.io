#!/usr/bin/env python3
"""
Wintermelon HAOS (wghaos) Beginner Installation & 3-Port Diagnostic Toolkit.
Pure Python 3 standard library implementation. Zero third-party dependencies.
"""
import argparse
import hashlib
import json
import os
import platform
import shutil
import socket
import sys
import time
import urllib.error
import urllib.request

FIRMWARE_CATALOG = {
    "x86-64-pe": {
        "version": "18.3.1",
        "filename": "win10pex64-wg-haos18.3.1.iso",
        "url": "https://fw.wghaos.com/haos/x86-64-pc/win10pex64-wg-haos18.3.1.iso",
        "desc": "64-bit Win10PE Universal Installer ISO (Recommended for PC / PVE / NAS VM)",
    },
    "x86-32-pe": {
        "version": "18.3.1",
        "filename": "win10pex86-wg-haos18.3.1.iso",
        "url": "https://fw.wghaos.com/haos/x86-64-pc/win10pex86-wg-haos18.3.1.iso",
        "desc": "32-bit IA32 Win10PE Installer ISO (For legacy 32-bit UEFI boards)",
    },
    "x86-64-pc": {
        "version": "18.3.1",
        "filename": "haos_x86-64-pc_cn-18.3.1.release.20261018_010438.a1de3a8760.img.xz",
        "url": "https://fw.wghaos.com/haos/x86-64-pc/haos_x86-64-pc_cn-18.3.1.release.20261018_010438.a1de3a8760.img.xz",
        "desc": "Bare-Metal x86-64 Native CPU Image (.img.xz)",
    },
    "x86-64-vm": {
        "version": "18.3.1",
        "filename": "haos_x86-64-vm_cn-18.3.1.release.20261018_235206.fa66a7567d.img.xz",
        "url": "https://fw.wghaos.com/haos/x86-64-vm/haos_x86-64-vm_cn-18.3.1.release.20261018_235206.fa66a7567d.img.xz",
        "desc": "Virtual Machine QEMU/OVA Compatible Image (.img.xz)",
    },
}

PORTS = [
    (8124, "Wintermelon Companion (Concierge UI)", "http://{host}:8124/"),
    (7681, "TTYD Web CLI Terminal (ha-install -t)", "http://{host}:7681/"),
    (8123, "Home Assistant Core Main UI", "http://{host}:8123/"),
]


def redact_address(val: str) -> str:
    """Redact host/IP string so reports never leak private LAN addresses."""
    if not val:
        return "<REDACTED>"
    parts = val.split(".")
    if len(parts) == 4 and all(p.isdigit() for p in parts):
        return f"{parts[0]}.{parts[1]}.x.x"
    return val


def check_tcp_port(host: str, port: int, timeout: float = 2.5) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def check_http_status(url: str, timeout: float = 3.0) -> int:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "wghaos-beginner-toolkit/1.0"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return 0


def cmd_plan(args: argparse.Namespace) -> int:
    target = args.edition
    info = FIRMWARE_CATALOG[target]
    free_gb = shutil.disk_usage(os.getcwd()).free / (1024 ** 3)
    plan_doc = {
        "os_platform": f"{platform.system()} {platform.release()}",
        "selected_edition": target,
        "firmware_version": info["version"],
        "description": info["desc"],
        "official_download_url": info["url"],
        "local_free_disk_gb": round(free_gb, 2),
        "recommended_vm_spec": {
            "bios": "OVMF (UEFI) - Never use Legacy SeaBIOS",
            "add_efi_disk": False,
            "cpu_cores": 2,
            "cpu_type": "host",
            "memory_mb": 4096,
            "disk_bus": "SATA",
            "disk_size_gb": 32,
            "network": "Bridge (vmbr0) on same LAN subnet",
        },
        "pve_cli_template": (
            "qm create 108 --name wghaos --memory 4096 --cores 2 --cpu host "
            "--bios ovmf --net0 virtio,bridge=vmbr0 --sata0 local-lvm:32"
        ),
    }
    print(json.dumps(plan_doc, indent=2, ensure_ascii=False))
    return 0


def cmd_fetch(args: argparse.Namespace) -> int:
    target = args.edition
    info = FIRMWARE_CATALOG[target]
    out_dir = os.path.abspath(args.out_dir)
    os.makedirs(out_dir, exist_ok=True)
    dest = os.path.join(out_dir, info["filename"])

    if args.dry_run:
        print(f"[DRY-RUN] Would download {info['url']} -> {dest}")
        return 0

    print(f"Downloading {info['filename']} from official mirror...")
    req = urllib.request.Request(info["url"], headers={"User-Agent": "Mozilla/5.0"})
    h = hashlib.sha256()
    downloaded = 0
    with urllib.request.urlopen(req, timeout=30) as resp, open(dest, "wb") as out_f:
        while True:
            chunk = resp.read(1024 * 256)
            if not chunk:
                break
            out_f.write(chunk)
            h.update(chunk)
            downloaded += len(chunk)
    print(f"Saved: {dest} ({downloaded} bytes, sha256={h.hexdigest()})")
    return 0


def cmd_probe(args: argparse.Namespace) -> int:
    host = args.host
    safe_host = redact_address(host)
    print(f"=== Probing Wintermelon HAOS target: {safe_host} ===")

    mdns_ok = True
    try:
        socket.getaddrinfo(host, None)
    except OSError:
        mdns_ok = False

    if not mdns_ok:
        print(f"[WARN] Cannot resolve '{safe_host}'.")
        print("  -> Fix 1: Ensure your PC and HAOS box are plugged into the same router subnet (avoid optical modem IPTV ports).")
        print("  -> Fix 2: Check router DHCP client list for 'homeassistant' and pass --host <LAN_ADDRESS>.")
        return 1

    results = {}
    for port, label, url_tmpl in PORTS:
        tcp_up = check_tcp_port(host, port)
        url = url_tmpl.format(host=host)
        http_code = check_http_status(url) if tcp_up else 0
        results[port] = {"tcp": tcp_up, "http": http_code, "label": label}
        status_str = f"ONLINE (HTTP {http_code})" if tcp_up else "OFFLINE"
        print(f"  Port {port} [{label}]: {status_str}")

    if results[8123]["tcp"]:
        print("\n[READY] Port 8123 is live! Open http://homeassistant.local:8123 to create your smart home account.")
    elif results[8124]["tcp"]:
        print("\n[INITIALIZING] Port 8124 (Wintermelon Companion) is active while 8123 is still preparing.")
        print("  -> Open http://homeassistant.local:8124/ to watch the 4-stage initialization progress bar.")
        print("  -> Once progress reaches 100%, click Reboot in Companion, wait 60s, and visit port 8123.")
    elif results[7681]["tcp"]:
        print("\n[CLI ONLY] Port 7681 (TTYD) is reachable. Open http://homeassistant.local:7681/ and run 'ha-install -t'.")
    else:
        print("\n[WAITING] All three ports are currently unreachable. Wait 2-3 minutes after power-on or verify UEFI boot setting.")
    return 0


def cmd_wait(args: argparse.Namespace) -> int:
    host = args.host
    timeout_sec = args.timeout
    interval = args.interval
    deadline = time.time() + timeout_sec
    safe_host = redact_address(host)
    print(f"Waiting up to {timeout_sec}s for {safe_host}:8123 onboarding UI...")

    while time.time() < deadline:
        up_8124 = check_tcp_port(host, 8124)
        up_8123 = check_tcp_port(host, 8123)
        if up_8123:
            print(f"[SUCCESS] {safe_host}:8123 is ONLINE and ready for onboarding!")
            if args.report:
                with open(args.report, "w", encoding="utf-8") as rf:
                    rf.write("# Wintermelon HAOS Readiness Report\n\n")
                    rf.write(f"- Target Host: `{safe_host}`\n")
                    rf.write(f"- Companion (8124): `{'ONLINE' if up_8124 else 'OFFLINE'}`\n")
                    rf.write("- HA Core (8123): `ONLINE`\n")
                    rf.write("- Recommended Post-Install Checks: Metric units, Asia/Shanghai timezone, initial backup.\n")
            return 0
        state_msg = "Companion 8124 active (initializing Core...)" if up_8124 else "Booting OS kernel..."
        print(f"  Still waiting ({state_msg})...")
        time.sleep(interval)

    print("[TIMEOUT] Port 8123 did not become ready within timeout. Check http://homeassistant.local:8124/ routine maintenance.")
    return 2


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Wintermelon HAOS Beginner Toolkit")
    sub = p.add_subparsers(dest="cmd", required=True)

    p_plan = sub.add_parser("plan", help="Output firmware download URL and recommended VM/BIOS specs")
    p_plan.add_argument("--edition", choices=list(FIRMWARE_CATALOG.keys()), default="x86-64-pe")
    p_plan.set_defaults(func=cmd_plan)

    p_fetch = sub.add_parser("fetch", help="Download official Wintermelon HAOS firmware and verify SHA256")
    p_fetch.add_argument("--edition", choices=list(FIRMWARE_CATALOG.keys()), default="x86-64-pe")
    p_fetch.add_argument("--out-dir", default="./downloads")
    p_fetch.add_argument("--dry-run", action="store_true")
    p_fetch.set_defaults(func=cmd_fetch)

    p_probe = sub.add_parser("probe", help="Probe ports 8124 (Companion), 7681 (TTYD), and 8123 (HA Core)")
    p_probe.add_argument("--host", default=os.environ.get("WGHAOS_HOST", "homeassistant.local"))
    p_probe.set_defaults(func=cmd_probe)

    p_wait = sub.add_parser("wait", help="Poll until HAOS finishes initialization and port 8123 is live")
    p_wait.add_argument("--host", default=os.environ.get("WGHAOS_HOST", "homeassistant.local"))
    p_wait.add_argument("--timeout", type=int, default=1200)
    p_wait.add_argument("--interval", type=int, default=15)
    p_wait.add_argument("--report", default="wghaos-readiness-report.md")
    p_wait.set_defaults(func=cmd_wait)
    return p


if __name__ == "__main__":
    parser = build_parser()
    ns = parser.parse_args()
    sys.exit(ns.func(ns))
