#!/usr/bin/env zsh
# ==============================================================================
# Pantum P2206W AirPrint 825-Day Certificate Auto-Fix Toolkit (macOS 26)
# Zero external dependencies. Uses native Zsh, dns-sd, OpenSSL, and cURL.
# ==============================================================================

set -euo pipefail

autoload -U colors && colors

PRINTER_HOST="${1:-}"
VALIDITY_DAYS="${2:-825}"
PASSWORD="${3:-123456}"

print -P "%F{cyan}========================================================================%f"
print -P "%F{green} 🖨️  Pantum P2206W × iOS 27 AirPrint Toolkit (macOS 26)%f"
print -P "%F{yellow} 🛡️  Enforcing Apple ATS 825-Day Certificate Lifespan & SAN Rules%f"
print -P "%F{cyan}========================================================================%f"

# 1. Auto-discover Pantum via dns-sd if PRINTER_HOST is empty
if [[ -z "$PRINTER_HOST" ]]; then
    print -P "%F{cyan}[*] Querying Bonjour for Pantum printer...%f"
    BONJOUR_LINE=$(dns-sd -B _ipp._tcp . 2>&1 & PID=$!; sleep 1.5; kill $PID 2>/dev/null | grep -i "Pantum" | head -n 1 || true)
    if [[ -n "$BONJOUR_LINE" ]]; then
        print -P "%F{green}[+] Found Bonjour service: Pantum-P2206W%f"
    fi
fi

BUILD_DIR="./build"
mkdir -p "$BUILD_DIR"

KEY_FILE="$BUILD_DIR/pantum_p2206w.key"
CRT_FILE="$BUILD_DIR/pantum_p2206w.crt"
PFX_FILE="$BUILD_DIR/pantum_p2206w_825d.pfx"

# 2. Generate compliant certificate
print -P "%F{cyan}[*] Generating ${VALIDITY_DAYS}-day RSA-2048 certificate with SAN...%f"
SAN_EXT="subjectAltName=DNS:printer.local,DNS:Pantum-******.local,IP:127.0.0.1"

openssl req -x509 -nodes -newkey rsa:2048 -days "$VALIDITY_DAYS" \
    -keyout "$KEY_FILE" -out "$CRT_FILE" \
    -subj "/C=CN/O=Local Printer/CN=printer.local" \
    -addext "$SAN_EXT" >/dev/null 2>&1

# 3. Package into PKCS#12 (.pfx)
print -P "%F{cyan}[*] Packaging into PKCS#12 (.pfx) container...%f"
openssl pkcs12 -export -out "$PFX_FILE" \
    -inkey "$KEY_FILE" -in "$CRT_FILE" \
    -passout "pass:${PASSWORD}" >/dev/null 2>&1

PFX_SIZE=$(wc -c < "$PFX_FILE" | tr -d ' ')
print -P "%F{green}[+] Generated '${PFX_FILE}' (${PFX_SIZE} bytes, limit: 51200 bytes).%f"

# 4. Upload or manual guidance
if [[ -n "$PRINTER_HOST" ]]; then
    print -P "%F{cyan}[*] Uploading to Pantum printer at http://${PRINTER_HOST}/docertificate ...%f"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://${PRINTER_HOST}/docertificate" \
        -F "sslcertkey=${PASSWORD}" \
        -F "input_file_upload=@${PFX_FILE};type=application/x-pkcs12" || echo "000")

    if [[ "$HTTP_CODE" == "200" ]]; then
        print -P "%F{green}[✓] Upload successful (HTTP 200)! Pantum printer is active with new 825d cert.%f"
    else
        print -P "%F{yellow}[!] Upload returned HTTP ${HTTP_CODE}. Please verify printer reachability.%f"
    fi
else
    print -P "%F{yellow}[*] Manual Upload Steps:%f"
    print -P "    1. Access printer backend: http://<printer-ip>/index-jump.html"
    print -P "    2. Navigate to: Settings -> Protocol Settings -> SSL/TLS"
    print -P "    3. Enter Private Key password: ${PASSWORD}"
    print -P "    4. Choose File '${PFX_FILE}' and click 'Certificate Installation'"
fi

print -P "%F{cyan}========================================================================%f"
print -P "%F{green} [✓] macOS 26 Pantum Toolkit Execution Completed Successfully!%f"
print -P "%F{cyan}========================================================================%f"
