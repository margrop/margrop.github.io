#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
HACS Beginner Automation Toolkit
Zero external dependencies (Python 3 stdlib only).
Cross-platform support: Windows 11 / Ubuntu 26.04 / macOS 27.
"""

import sys
import os
import argparse
import json
import urllib.request
import urllib.error
import zipfile
import io
import time
import socket
import platform

COLOR_RESET = "\033[0m"
COLOR_GREEN = "\033[32m"
COLOR_YELLOW = "\033[33m"
COLOR_CYAN = "\033[36m"
COLOR_RED = "\033[31m"
COLOR_BOLD = "\033[1m"

def log_info(msg):
    print(f"{COLOR_CYAN}[INFO]{COLOR_RESET} {msg}")

def log_success(msg):
    print(f"{COLOR_GREEN}[SUCCESS]{COLOR_RESET} {msg}")

def log_warn(msg):
    print(f"{COLOR_YELLOW}[WARN]{COLOR_RESET} {msg}")

def log_error(msg):
    print(f"{COLOR_RED}[ERROR]{COLOR_RESET} {msg}")

def check_env():
    log_info(f"System: {platform.system()} {platform.release()} ({platform.machine()})")
    log_info(f"Python Runtime: {platform.python_version()} at {sys.executable}")
    
    endpoints = [
        ("GitHub Web", "github.com", 443),
        ("GitHub API", "api.github.com", 443),
        ("Fastly CDN", "raw.githubusercontent.com", 443)
    ]
    
    results = {}
    for name, host, port in endpoints:
        start = time.time()
        try:
            sock = socket.create_connection((host, port), timeout=4.0)
            latency = (time.time() - start) * 1000
            sock.close()
            log_success(f"{name} ({host}:{port}) -> Connected ({latency:.1f}ms)")
            results[name] = True
        except Exception as e:
            log_warn(f"{name} ({host}:{port}) -> Timeout/Refused ({e})")
            results[name] = False
    return results

def detect_config_dir(user_path=None):
    if user_path and os.path.isdir(user_path):
        return os.path.abspath(user_path)
    
    env_path = os.environ.get("HA_CONFIG_DIR")
    if env_path and os.path.isdir(env_path):
        return os.path.abspath(env_path)

    candidates = [
        "/config",
        os.path.expanduser("~/.homeassistant"),
        os.path.join(os.getcwd(), "config"),
        os.path.join(os.getcwd(), "homeassistant"),
        "/usr/share/hassio/homeassistant"
    ]
    
    for c in candidates:
        if os.path.isdir(c) and (os.path.isfile(os.path.join(c, "configuration.yaml")) or os.path.isdir(os.path.join(c, ".storage"))):
            return os.path.abspath(c)
            
    for fallback in ["/config", os.path.join(os.getcwd(), "config"), os.getcwd()]:
        if os.path.isdir(fallback) and os.access(fallback, os.W_OK):
            return os.path.abspath(fallback)
            
    return os.path.abspath(os.getcwd())

def download_hacs(target_dir, use_mirror=False):
    custom_comp = os.path.join(target_dir, "custom_components")
    hacs_dest = os.path.join(custom_comp, "hacs")
    os.makedirs(hacs_dest, exist_ok=True)

    log_info(f"Target HACS installation path: {hacs_dest}")
    
    official_url = "https://github.com/hacs/integration/releases/latest/download/hacs.zip"
    mirror_url = "https://ghproxy.net/https://github.com/hacs/integration/releases/latest/download/hacs.zip"

    urls = [official_url]
    if use_mirror:
        urls.insert(0, mirror_url)
    else:
        urls.append(mirror_url)

    zip_bytes = None
    for url in urls:
        log_info(f"Attempting download from: {url}")
        req = urllib.request.Request(url, headers={"User-Agent": "HACS-Beginner-Toolkit/2026.10"})
        try:
            start = time.time()
            with urllib.request.urlopen(req, timeout=15) as resp:
                zip_bytes = resp.read()
            elapsed = time.time() - start
            log_success(f"Downloaded hacs.zip ({len(zip_bytes)} bytes in {elapsed:.2f}s)")
            break
        except Exception as e:
            log_warn(f"Failed download from {url}: {e}")

    if not zip_bytes:
        log_error("Could not download HACS archive from any endpoint.")
        log_error("Please check your internet connection or use a proxy.")
        sys.exit(1)

    log_info("Extracting HACS archive directly into custom_components/hacs...")
    try:
        with zipfile.ZipFile(io.BytesIO(zip_bytes)) as z:
            z.extractall(hacs_dest)
        log_success("Extraction completed successfully!")
    except Exception as e:
        log_error(f"Failed to extract zip archive: {e}")
        sys.exit(1)

    manifest_path = os.path.join(hacs_dest, "manifest.json")
    if os.path.isfile(manifest_path):
        try:
            with open(manifest_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            log_success(f"Verified HACS manifest. Domain: {data.get('domain')} | Version: {data.get('version')}")
        except Exception as e:
            log_warn(f"Manifest read error: {e}")
    else:
        log_warn("manifest.json not found in destination directory.")

    print("\n" + "="*60)
    print(f"{COLOR_BOLD}{COLOR_GREEN}>>> HACS INSTALLATION FINISHED! <<<{COLOR_RESET}")
    print("="*60)
    print("Next steps to activate HACS in Home Assistant UI:")
    print("  1. Restart Home Assistant: Settings -> System -> Restart")
    print("  2. Clear browser cache (Ctrl+F5 or Shift+Reload)")
    print("  3. Go to Settings -> Devices & Services -> Add Integration")
    print("  4. Search 'HACS' and check all 4 acknowledgment boxes")
    print("  5. Open https://github.com/login/device and submit the 8-digit code!")
    print("="*60 + "\n")

def probe_ha(ha_host="localhost", ha_port=8123):
    log_info(f"Testing Home Assistant HTTP listener on {ha_host}:{ha_port}...")
    try:
        sock = socket.create_connection((ha_host, ha_port), timeout=3.0)
        sock.close()
        log_success(f"Home Assistant is actively LISTENING on port {ha_port}!")
        return True
    except Exception as e:
        log_warn(f"Home Assistant is not responding on {ha_host}:{ha_port}: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="HACS Automated Setup & Diagnostics Toolkit")
    subparsers = parser.add_subparsers(dest="command")

    subparsers.add_parser("check", help="Check system runtime and GitHub connectivity")
    
    install_parser = subparsers.add_parser("install", help="Download and install HACS into config dir")
    install_parser.add_argument("--config-dir", help="Path to Home Assistant configuration directory")
    install_parser.add_argument("--mirror", action="store_true", help="Prioritize acceleration mirror")

    probe_parser = subparsers.add_parser("probe", help="Probe Home Assistant port and HACS files")
    probe_parser.add_argument("--host", default="localhost", help="HA host (default: localhost)")
    probe_parser.add_argument("--port", type=int, default=8123, help="HA port (default: 8123)")
    probe_parser.add_argument("--config-dir", help="Path to config directory")

    args = parser.parse_args()

    if not args.command or args.command == "check":
        check_env()
    elif args.command == "install":
        check_env()
        cfg_dir = detect_config_dir(args.config_dir)
        download_hacs(cfg_dir, use_mirror=args.mirror)
    elif args.command == "probe":
        probe_ha(args.host, args.port)
        cfg_dir = detect_config_dir(args.config_dir)
        hacs_manifest = os.path.join(cfg_dir, "custom_components", "hacs", "manifest.json")
        if os.path.isfile(hacs_manifest):
            log_success(f"HACS is present in: {hacs_manifest}")
        else:
            log_warn(f"HACS was not detected in: {cfg_dir}/custom_components/hacs")

if __name__ == "__main__":
    main()
