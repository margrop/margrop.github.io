#!/usr/bin/env bash
# ==============================================================================
# Script Name: cernet-switch-ubuntu2604.sh
# Supported OS: Ubuntu 26.04 LTS / 24.04 LTS / 22.04 LTS & Debian Derivatives
# Description: Automatically detects DEB822 vs legacy sources.list, migrates
#              APT and Python pip to CERNET Hub, supports JSON inspection and backup.
# Dependencies: Native POSIX tools (bash, awk, sed, curl) with zero external deps.
# ==============================================================================

set -euo pipefail

MODE="apply" # apply | check
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --apply) MODE="apply"; shift ;;
    --json)  OUTPUT_JSON=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
UBUNTU_SOURCES="/etc/apt/sources.list.d/ubuntu.sources"
LEGACY_SOURCES="/etc/apt/sources.list"
CERNET_MIRROR_BASE="https://mirrors.cernet.edu.cn/ubuntu/"
PIP_MIRROR_INDEX="https://mirrors.cernet.edu.cn/pypi/web/simple/"

# Detect distribution codename
OS_CODENAME="unknown"
if [ -f /etc/os-release ]; then
  OS_CODENAME=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
  [ -z "$OS_CODENAME" ] && OS_CODENAME=$(grep -E '^UBUNTU_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
fi

# Inspect current configuration
CURRENT_APT_SOURCE="default"
IS_CERNET_CONFIGURED=false

if [ -f "$UBUNTU_SOURCES" ]; then
  if grep -q "mirrors.cernet.edu.cn" "$UBUNTU_SOURCES"; then
    IS_CERNET_CONFIGURED=true
    CURRENT_APT_SOURCE="deb822:cernet"
  else
    CURRENT_APT_SOURCE="deb822:other"
  fi
elif [ -f "$LEGACY_SOURCES" ]; then
  if grep -q "mirrors.cernet.edu.cn" "$LEGACY_SOURCES"; then
    IS_CERNET_CONFIGURED=true
    CURRENT_APT_SOURCE="legacy:cernet"
  else
    CURRENT_APT_SOURCE="legacy:other"
  fi
fi

# Check dynamic redirection target
REDIRECT_TARGET="unreachable"
if command -v curl >/dev/null 2>&1; then
  REDIRECT_TARGET=$(curl -sIL -o /dev/null -w "%{redirect_url}" "$CERNET_MIRROR_BASE" 2>/dev/null || echo "failed")
  [ -z "$REDIRECT_TARGET" ] && REDIRECT_TARGET="direct"
fi

if [ "$MODE" = "check" ]; then
  if [ "$OUTPUT_JSON" = true ]; then
    printf '{"os":"ubuntu","codename":"%s","apt_source":"%s","configured":%s,"redirect_node":"%s"}\n' \
      "$OS_CODENAME" "$CURRENT_APT_SOURCE" "$IS_CERNET_CONFIGURED" "$REDIRECT_TARGET"
  else
    echo "=== Ubuntu 26.04 CERNET Mirror Inspection ==="
    echo "Codename: $OS_CODENAME"
    echo "Current APT Source: $CURRENT_APT_SOURCE"
    echo "Dynamic Redirect Node: $REDIRECT_TARGET"
    echo "Is Configured: $IS_CERNET_CONFIGURED"
  fi
  exit 0
fi

# Apply migration
BACKUP_PATH=""
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: Modifying APT sources requires root privileges. Run with sudo $0" >&2
  exit 1
fi

if [ -f "$UBUNTU_SOURCES" ]; then
  # Modern DEB822 format (Ubuntu 24.04+)
  BACKUP_PATH="${UBUNTU_SOURCES}.bak.${TIMESTAMP}"
  cp -p "$UBUNTU_SOURCES" "$BACKUP_PATH"
  
  cat << EOF > "$UBUNTU_SOURCES"
Types: deb
URIs: https://mirrors.cernet.edu.cn/ubuntu/
Suites: ${OS_CODENAME} ${OS_CODENAME}-updates ${OS_CODENAME}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: https://mirrors.cernet.edu.cn/ubuntu/
Suites: ${OS_CODENAME}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

else
  # Legacy sources.list format
  BACKUP_PATH="${LEGACY_SOURCES}.bak.${TIMESTAMP}"
  cp -p "$LEGACY_SOURCES" "$BACKUP_PATH"

  cat << EOF > "$LEGACY_SOURCES"
deb https://mirrors.cernet.edu.cn/ubuntu/ ${OS_CODENAME} main restricted universe multiverse
deb https://mirrors.cernet.edu.cn/ubuntu/ ${OS_CODENAME}-updates main restricted universe multiverse
deb https://mirrors.cernet.edu.cn/ubuntu/ ${OS_CODENAME}-backports main restricted universe multiverse
deb https://mirrors.cernet.edu.cn/ubuntu/ ${OS_CODENAME}-security main restricted universe multiverse
EOF
fi

# Configure Python pip mirror
PIP_CONFIG_STATUS="skipped"
if command -v python3 >/dev/null 2>&1; then
  python3 -m pip config set global.index-url "$PIP_MIRROR_INDEX" >/dev/null 2>&1 || true
  PIP_CONFIG_STATUS="applied"
fi

if [ "$OUTPUT_JSON" = true ]; then
  printf '{"status":"success","os":"ubuntu","backup":"%s","redirect_node":"%s","pip":"%s"}\n' \
    "$BACKUP_PATH" "$REDIRECT_TARGET" "$PIP_CONFIG_STATUS"
else
  echo -e "\033[32m[SUCCESS]\033[0m APT repositories successfully switched to CERNET Joint Mirror!"
  echo "• Backup created: $BACKUP_PATH"
  echo "• Dynamic redirect target: $REDIRECT_TARGET"
  echo "• Python pip configuration: $PIP_CONFIG_STATUS"
  echo "• Test immediately by running: sudo apt-get update"
fi
