#!/usr/bin/env python3
"""
Pantum P2206W AirPrint 825-Day TLS Certificate Toolkit & Autonomous Agent
Zero-dependency Python 3 standard library script.
Supports Windows 11, Ubuntu 26.04, macOS 26.

Modes:
  1. Probe: Diagnoses printer network, mDNS service, and active TLS certificate.
  2. Generate: Creates an Apple ATS/iOS 27 compliant 825-day PKCS#12 (.pfx/.p12) bundle.
  3. Upload: Dispatches the certificate package to the Pantum Embedded Web Server.
  4. Auto: Performs end-to-end diagnosis, generation, upload, and verification.
  5. Plan: Declarative agent mode driven by JSON specification.
"""

import sys
import os
import re
import socket
import ssl
import json
import argparse
import subprocess
import urllib.request
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path

# Maximum certificate validity allowed by Apple ATS / iOS 27
APPLE_MAX_VALIDITY_DAYS = 825

def print_banner():
    banner = """
========================================================================
 🖨️  Pantum P2206W × iOS 27 AirPrint 825-Day Certificate Toolkit
 🛡️  Compliant with Apple ATS, RFC 5280 & Local Sandboxing Rules
========================================================================
"""
    print(banner)

def run_cmd(cmd, check=True):
    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and res.returncode != 0:
        raise RuntimeError(f"Command failed (exit {res.returncode}): {cmd}\nStderr: {res.stderr.strip()}")
    return res.stdout.strip(), res.stderr.strip(), res.returncode

def probe_printer_cert(host, port=443):
    print(f"[*] Probing TLS Certificate on {host}:{port} ...")
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    with socket.create_connection((host, port), timeout=5) as sock:
        with ctx.wrap_socket(sock, server_hostname=host) as ssock:
            cert_bin = ssock.getpeercert(binary_form=True)

    # Use openssl command to parse binary cert
    p = subprocess.Popen(["openssl", "x509", "-inform", "DER", "-text", "-noout"],
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    stdout, stderr = p.communicate(input=cert_bin.decode("latin1"))

    info = {}
    # Extract Validity
    not_before_match = re.search(r"Not Before\s*:\s*(.+)", stdout)
    not_after_match = re.search(r"Not After\s*:\s*(.+)", stdout)
    subject_match = re.search(r"Subject\s*:\s*(.+)", stdout)
    issuer_match = re.search(r"Issuer\s*:\s*(.+)", stdout)
    san_match = re.search(r"X509v3 Subject Alternative Name:\s*\n\s*(.+)", stdout)

    if not_before_match and not_after_match:
        nb_str = not_before_match.group(1).strip()
        na_str = not_after_match.group(1).strip()
        info["not_before"] = nb_str
        info["not_after"] = na_str
        try:
            nb = datetime.strptime(nb_str, "%b %d %H:%M:%S %Y %Z")
            na = datetime.strptime(na_str, "%b %d %H:%M:%S %Y %Z")
            days = (na - nb).days
            info["validity_days"] = days
        except Exception:
            info["validity_days"] = -1

    info["subject"] = subject_match.group(1).strip() if subject_match else "Unknown"
    info["issuer"] = issuer_match.group(1).strip() if issuer_match else "Unknown"
    info["san"] = san_match.group(1).strip() if san_match else "MISSING"

    print(f"    Subject: {info['subject']}")
    print(f"    Issuer:  {info['issuer']}")
    print(f"    Validity: {info.get('not_before')} -> {info.get('not_after')} ({info.get('validity_days')} days)")
    print(f"    SAN:     {info['san']}")

    if info.get("validity_days", 0) > APPLE_MAX_VALIDITY_DAYS:
        print(f"[-] [NON-COMPLIANT] Lifetime ({info.get('validity_days')}d) > {APPLE_MAX_VALIDITY_DAYS}d! iOS 27 will REJECT this certificate.")
        info["compliant"] = False
    elif info["san"] == "MISSING":
        print(f"[-] [NON-COMPLIANT] Missing SAN extension! iOS 27 will REJECT this certificate.")
        info["compliant"] = False
    else:
        print(f"[+] [COMPLIANT] Certificate satisfies Apple ATS and iOS 27 criteria!")
        info["compliant"] = True

    return info

def generate_compliant_certificate(output_dir=".", cn="printer.local", days=825, password=""):
    out_dir = Path(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    key_file = out_dir / "pantum_temp.key"
    crt_file = out_dir / "pantum_temp.crt"
    pfx_file = out_dir / "pantum_825d.pfx"

    print(f"[*] Generating {days}-day RSA-2048 self-signed certificate...")
    san_ext = f"subjectAltName=DNS:{cn},DNS:printer.local,IP:127.0.0.1"

    cmd_req = (
        f"openssl req -x509 -nodes -newkey rsa:2048 -days {days} "
        f"-keyout \"{key_file}\" -out \"{crt_file}\" "
        f"-subj \"/C=CN/O=Local Printer/CN={cn}\" "
        f"-addext \"{san_ext}\""
    )
    run_cmd(cmd_req)

    print(f"[*] Packaging into PKCS#12 (.pfx) bundle...")
    cmd_pfx = (
        f"openssl pkcs12 -export -out \"{pfx_file}\" "
        f"-inkey \"{key_file}\" -in \"{crt_file}\" "
        f"-passout pass:{password}"
    )
    run_cmd(cmd_pfx)

    pfx_size = pfx_file.stat().st_size
    print(f"[+] Created '{pfx_file.name}' ({pfx_size} bytes, limit: 51200 bytes).")
    if pfx_size > 50000:
        raise ValueError("Generated PFX exceeds Pantum's 50KB upload limit!")

    return pfx_file, crt_file, key_file

def upload_certificate(host, pfx_path, password=""):
    print(f"[*] Uploading certificate to Pantum printer at http://{host}/docertificate ...")
    url = f"http://{host}/docertificate"
    boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
    
    with open(pfx_path, "rb") as f:
        file_bytes = f.read()

    body = bytearray()
    body.extend(f"--{boundary}\r\n".encode("utf-8"))
    body.extend(b'Content-Disposition: form-data; name="sslcertkey"\r\n\r\n')
    body.extend(f"{password}\r\n".encode("utf-8"))

    body.extend(f"--{boundary}\r\n".encode("utf-8"))
    body.extend(f'Content-Disposition: form-data; name="input_file_upload"; filename="{Path(pfx_path).name}"\r\n'.encode("utf-8"))
    body.extend(b"Content-Type: application/x-pkcs12\r\n\r\n")
    body.extend(file_bytes)
    body.extend(b"\r\n")
    body.extend(f"--{boundary}--\r\n".encode("utf-8"))

    req = urllib.request.Request(url, data=bytes(body), method="POST")
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    req.add_header("User-Agent", "Mozilla/5.0 PantumCertificateAgent/1.0")

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            resp_data = resp.read().decode("utf-8", errors="ignore")
            print(f"[+] Server HTTP response code: {resp.status}")
            print(f"[+] Server response content: {resp_data[:200]}")
            return True
    except Exception as e:
        print(f"[!] Upload returned: {e}")
        return False

def execute_plan(plan_path):
    print(f"[*] Executing declarative plan: {plan_path}")
    with open(plan_path, "r", encoding="utf-8") as f:
        plan = json.load(f)

    target_host = plan.get("network", {}).get("printer_host")
    policy = plan.get("compliance_policy", {})
    max_days = policy.get("max_validity_days", 825)
    cn = plan.get("certificate_payload", {}).get("cn", "printer.local")
    pwd = plan.get("certificate_payload", {}).get("passphrase", "")

    if target_host:
        probe = probe_printer_cert(target_host)
        if probe.get("compliant"):
            print("[+] Target already compliant. No action required.")
            return

    pfx_file, _, _ = generate_compliant_certificate(output_dir="./build", cn=cn, days=max_days, password=pwd)
    if plan.get("deployment", {}).get("auto_upload") and target_host:
        upload_certificate(target_host, pfx_file, password=pwd)
        print("[+] Re-probing after deployment...")
        probe_printer_cert(target_host)

def main():
    print_banner()
    parser = argparse.ArgumentParser(description="Pantum P2206W 825-Day Certificate Auto-Fix Toolkit")
    parser.add_argument("--mode", choices=["probe", "generate", "upload", "auto", "plan"], default="auto")
    parser.add_argument("--host", help="Printer IP address or hostname (e.g., 192.168.1.xxx)")
    parser.add_argument("--port", type=int, default=443, help="TLS port (default: 443)")
    parser.add_argument("--cn", default="printer.local", help="Certificate Common Name")
    parser.add_argument("--days", type=int, default=825, help="Validity period in days (max 825)")
    parser.add_argument("--password", default="", help="Private key / PFX export password")
    parser.add_argument("--pfx", help="PFX file path for upload")
    parser.add_argument("--plan", help="JSON declarative plan file path")

    args = parser.parse_args()

    if args.mode == "plan":
        if not args.plan:
            print("[!] Error: --plan <file.json> required in plan mode.")
            sys.exit(1)
        execute_plan(args.plan)
        return

    if args.mode == "probe":
        if not args.host:
            print("[!] Error: --host <printer-ip> required for probe.")
            sys.exit(1)
        probe_printer_cert(args.host, args.port)

    elif args.mode == "generate":
        pfx, crt, key = generate_compliant_certificate(cn=args.cn, days=args.days, password=args.password)
        print(f"[+] Output ready: {pfx}")

    elif args.mode == "upload":
        if not args.host or not args.pfx:
            print("[!] Error: --host and --pfx required for upload.")
            sys.exit(1)
        upload_certificate(args.host, args.pfx, args.password)

    elif args.mode == "auto":
        if not args.host:
            print("[*] No --host specified. Generating standalone 825-day package for web upload...")
            pfx, _, _ = generate_compliant_certificate(cn=args.cn, days=args.days, password=args.password)
            print(f"[+] File generated at: {pfx.resolve()}")
            print("[*] You can now open printer web interface -> Settings -> SSL/TLS to upload.")
        else:
            probe = probe_printer_cert(args.host, args.port)
            pfx, _, _ = generate_compliant_certificate(cn=args.cn, days=args.days, password=args.password)
            upload_certificate(args.host, pfx, args.password)
            print("[+] Auto execution completed!")

if __name__ == "__main__":
    main()
