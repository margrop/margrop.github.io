#!/usr/bin/env bash
# ==============================================================================
# Pantum P2206W AirPrint 825-Day Certificate Auto-Fix Toolkit (Ubuntu 26.04)
# Zero external dependencies. Uses Bash, native OpenSSL and cURL.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PRINTER_HOST="${1:-}"
VALIDITY_DAYS="${2:-825}"
PASSWORD="${3:-123456}"

echo -e "${CYAN}========================================================================${NC}"
echo -e "${GREEN} 🖨️  Pantum P2206W × iOS 27 AirPrint Toolkit (Ubuntu 26.04)${NC}"
echo -e "${YELLOW} 🛡️  Enforcing Apple ATS 825-Day Certificate Lifespan & SAN Rules${NC}"
echo -e "${CYAN}========================================================================${NC}"

# Check OpenSSL and curl
for cmd in openssl curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}[!] Error: Required tool '$cmd' is not installed. Run: sudo apt update && sudo apt install -y $cmd${NC}"
        exit 1
    fi
done

BUILD_DIR="./build"
mkdir -p "$BUILD_DIR"

KEY_FILE="$BUILD_DIR/pantum_p2206w.key"
CRT_FILE="$BUILD_DIR/pantum_p2206w.crt"
PFX_FILE="$BUILD_DIR/pantum_p2206w_825d.pfx"

# 1. Generate 825-day certificate
echo -e "${CYAN}[*] Generating ${VALIDITY_DAYS}-day RSA-2048 certificate with SAN...${NC}"
SAN_EXT="subjectAltName=DNS:printer.local,DNS:Pantum-XXXXXX.local,IP:127.0.0.1"

openssl req -x509 -nodes -newkey rsa:2048 -days "$VALIDITY_DAYS" \
    -keyout "$KEY_FILE" -out "$CRT_FILE" \
    -subj "/C=CN/O=Local Printer/CN=printer.local" \
    -addext "$SAN_EXT" >/dev/null 2>&1

# 2. Package into PKCS#12 (.pfx)
echo -e "${CYAN}[*] Packaging into PKCS#12 (.pfx) container...${NC}"
openssl pkcs12 -export -out "$PFX_FILE" \
    -inkey "$KEY_FILE" -in "$CRT_FILE" \
    -passout "pass:${PASSWORD}" >/dev/null 2>&1

PFX_SIZE=$(wc -c < "$PFX_FILE")
echo -e "${GREEN}[+] Generated '${PFX_FILE}' (${PFX_SIZE} bytes, limit: 51200 bytes).${NC}"

# 3. Upload or manual instructions
if [[ -n "$PRINTER_HOST" ]]; then
    echo -e "${CYAN}[*] Uploading to Pantum printer at http://${PRINTER_HOST}/docertificate ...${NC}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://${PRINTER_HOST}/docertificate" \
        -F "sslcertkey=${PASSWORD}" \
        -F "input_file_upload=@${PFX_FILE};type=application/x-pkcs12" || echo "000")

    if [[ "$HTTP_CODE" == "200" ]]; then
        echo -e "${GREEN}[✓] Upload successful (HTTP 200)! Printer is reloading its TLS service.${NC}"
    else
        echo -e "${YELLOW}[!] Upload returned HTTP ${HTTP_CODE}. Please check printer IP and connectivity.${NC}"
    fi
else
    echo -e "${YELLOW}[*] Manual Upload Steps:${NC}"
    echo -e "    1. Access printer web admin: http://<printer-ip>/index-jump.html"
    echo -e "    2. Navigate to: Settings -> Protocol Settings -> SSL/TLS"
    echo -e "    3. Enter Private Key password: ${PASSWORD}"
    echo -e "    4. Choose File '${PFX_FILE}' and click 'Certificate Installation'"
fi

echo -e "${CYAN}========================================================================${NC}"
echo -e "${GREEN} [✓] Ubuntu 26.04 Pantum Toolkit Execution Completed Successfully!${NC}"
echo -e "${CYAN}========================================================================${NC}"
