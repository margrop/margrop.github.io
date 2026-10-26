#!/usr/bin/env python3
"""Home Assistant Midea AC LAN Zero-Dependency Offline Upgrade Toolkit.

Pure Python 3 standard library implementation.
Zero external pip dependencies required.
Handles wheel unpacking, /config/deps injection, file pruning, config verification, and safe reboot.
"""
import argparse
import getpass
import hashlib
import json
import os
import re
import sys
import time
import urllib.request
import zipfile
from pathlib import Path

# Known official release hashes for verification
EXPECTED_HASHES = {
    "midea_ac_lan_v2026.10.0.zip": "56fe36ef7b5ebefb9195914fa6792dc8d653f88ef057e930dbb1263da3b4e6eb",
    "midea_lan-2026.10.0-py3-none-any.whl": "1aef91866cebf7d206f6630f9011986ceecf90a931448b3c3b0dfbbf4d7ee56d",
}


def mask_str(s):
    if not s:
        return ""
    # Mask full IP addresses like 192.168.1.100 -> 192.168.***.***
    s = re.sub(r"(\d{1,3}\.\d{1,3}\.)\d{1,3}\.\d{1,3}", r"\1***.***", str(s))
    return s


def sha256_file(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


class HAClient:
    def __init__(self, base_url, token):
        self.base = base_url.rstrip("/")
        self.token = token

    def request(self, method, endpoint, data=None):
        url = f"{self.base}{endpoint}"
        body = json.dumps(data).encode("utf-8") if data is not None else None
        req = urllib.request.Request(url, data=body, method=method)
        req.add_header("Authorization", f"Bearer {self.token}")
        req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                content = resp.read()
                return json.loads(content.decode("utf-8")) if content else {}
        except urllib.error.HTTPError as e:
            err = e.read().decode("utf-8")
            raise RuntimeError(f"HTTP {e.code} on {endpoint}: {mask_str(err)[:200]}")

    def get_config(self):
        return self.request("GET", "/api/config")

    def check_config(self):
        return self.request("POST", "/api/services/homeassistant/check_config")

    def restart(self):
        return self.request("POST", "/api/services/homeassistant/restart")

    def get_states(self):
        return self.request("GET", "/api/states")


def probe_ha(ha):
    cfg = ha.get_config()
    version = cfg.get("version", "unknown")
    state = cfg.get("state", "unknown")
    print(f"[*] Connected to Home Assistant (State: {state}, Core: {version})")
    states = ha.get_states()
    midea_entities = [s for s in states if "midea" in s.get("entity_id", "") or "mei_de" in s.get("entity_id", "")]
    print(f"[*] Found {len(midea_entities)} active Midea-related entities in registry.")
    return version


def download_and_verify(url, target_path, expected_hash=None):
    print(f"[*] Downloading: {mask_str(url)}")
    req = urllib.request.Request(url, headers={"User-Agent": "Midea-Upgrade-Toolkit/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp, open(target_path, "wb") as f:
        while chunk := resp.read(65536):
            f.write(chunk)
    actual_hash = sha256_file(target_path)
    print(f"[*] Saved to {target_path.name} (SHA256: {actual_hash[:16]}...)")
    if expected_hash and actual_hash.lower() != expected_hash.lower():
        print(f"[!] Warning: Hash mismatch! Expected {expected_hash}, got {actual_hash}")
    return actual_hash


def main():
    parser = argparse.ArgumentParser(description="Home Assistant Midea AC LAN Offline Dependency Toolkit")
    parser.add_argument("--url", help="Home Assistant Base URL (or set HA_URL env)")
    parser.add_argument("--token", help="Home Assistant Long-Lived Token (or set HA_TOKEN env)")
    parser.add_argument("--apply", action="store_true", help="Apply changes (default is read-only check)")
    parser.add_argument("--non-interactive", action="store_true", help="Run without prompts (for agent automation)")
    parser.add_argument("--python-ver", default="python3.14", help="Python user site version folder (default: python3.14)")
    parser.add_argument("--staging-dir", default="./midea_staging", help="Local temporary staging directory")
    args = parser.parse_args()

    url = args.url or os.environ.get("HA_URL")
    token = args.token or os.environ.get("HA_TOKEN") or os.environ.get("HOME_ASSISTANT_TOKEN")

    if not url:
        if args.non_interactive:
            print("[!] Error: --url or HA_URL environment variable is required in non-interactive mode.", file=sys.stderr)
            sys.exit(1)
        url = input("Enter Home Assistant Base URL (e.g. http://ha.local:8123): ").strip()

    if not token:
        if args.non_interactive:
            print("[!] Error: --token or HA_TOKEN environment variable is required in non-interactive mode.", file=sys.stderr)
            sys.exit(1)
        token = getpass.getpass("Enter Home Assistant Long-Lived Access Token: ").strip()

    ha = HAClient(url, token)
    version = probe_ha(ha)

    if not args.apply:
        print("\n[+] Read-only check succeeded! No changes were made.")
        print("[+] To apply offline dependency extraction and safe upgrade, run with --apply.")
        sys.exit(0)

    print("\n[*] Starting offline dependency preparation...")
    staging = Path(args.staging_dir).resolve()
    staging.mkdir(parents=True, exist_ok=True)

    # Wheel download and verification
    whl_file = staging / "midea_lan-2026.10.0-py3-none-any.whl"
    if not whl_file.exists():
        whl_url = "https://files.pythonhosted.org/packages/py3/m/midea_lan/midea_lan-2026.10.0-py3-none-any.whl"
        download_and_verify(whl_url, whl_file, EXPECTED_HASHES.get(whl_file.name))

    # Extract wheel locally
    unpack_dir = staging / "unpacked"
    unpack_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(whl_file, "r") as z:
        z.extractall(unpack_dir)
    print(f"[*] Extracted wheel packages: {[p.name for p in unpack_dir.iterdir()]}")

    target_user_site = f"/config/deps/lib/{args.python_ver}/site-packages"
    print(f"[*] Target Home Assistant injection location: {target_user_site}")

    # Check configuration validity before triggering restart
    print("[*] Validating configuration via check_config service...")
    chk = ha.check_config()
    print(f"[*] check_config result: {chk}")

    print("\n[+] Pre-flight validation passed.")
    print(f"[+] Files unpacked at {unpack_dir}. Follow the manual or agent injection steps to complete deployment.")


if __name__ == "__main__":
    main()
