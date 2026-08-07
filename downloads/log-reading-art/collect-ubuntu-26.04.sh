#!/usr/bin/env bash
set -euo pipefail

hours=4
output_dir="${PWD}/log-report-ubuntu"

usage() {
  cat <<'EOF'
Usage: collect-ubuntu-26.04.sh [--hours 1-168] [--output DIRECTORY]

Collects a local, read-only troubleshooting report using Ubuntu built-in tools.
The report is redacted before it is written and is never uploaded anywhere.
EOF
}

while (($#)); do
  case "$1" in
    --hours)
      hours="${2:-}"
      shift 2
      ;;
    --output)
      output_dir="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! "$hours" =~ ^[0-9]+$ ]] || ((hours < 1 || hours > 168)); then
  printf '%s\n' '--hours must be an integer from 1 to 168.' >&2
  exit 2
fi

mkdir -p "$output_dir"
raw_file=$(mktemp "${TMPDIR:-/tmp}/log-reading-ubuntu.XXXXXX")
report_file="$output_dir/ubuntu-log-report.txt"
trap 'rm -f "$raw_file"' EXIT

section() {
  local title=$1
  shift
  {
    printf '\n===== %s =====\n' "$title"
    "$@" 2>&1 || printf '[command unavailable or returned non-zero]\n'
  } >>"$raw_file"
}

redact() {
  local host user
  host=$(hostname 2>/dev/null || true)
  user=${USER:-}
  sed -E \
    -e 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[IP-REDACTED]/g' \
    -e 's/([[:alnum:]_-]+\.)+(local|lan|internal|home)/[DOMAIN-REDACTED]/gI' \
    -e 's#/(home|Users)/[^/[:space:]]+#/\1/[USER-REDACTED]#g' \
    -e 's/(Bearer|token|secret|password|apikey|api_key)[=:[:space:]]+[^[:space:]]+/\1=[SECRET-REDACTED]/gI' \
    -e "${host:+s/${host//\//\\/}/[HOST-REDACTED]/g}" \
    -e "${user:+s/${user//\//\\/}/[USER-REDACTED]/g}" \
    "$raw_file"
}

{
  printf 'Ubuntu troubleshooting evidence report\n'
  printf 'Generated: %s\n' "$(date -Is)"
  printf 'Window: last %s hour(s)\n' "$hours"
  printf 'Mode: read-only, local-only, redacted\n'
} >"$raw_file"

section "OS AND CLOCK" sh -c 'cat /etc/os-release; printf "\n"; uname -a; printf "\n"; timedatectl status'
section "DISK AND INODES" sh -c 'df -hT; printf "\n"; df -ih'
section "FAILED SERVICES" systemctl --failed --no-pager
section "BOOT ERRORS" journalctl -b -p warning..alert --since "${hours} hours ago" --no-pager -n 300
section "KERNEL WARNINGS" journalctl -k -p warning..alert --since "${hours} hours ago" --no-pager -n 200
section "LISTENING SOCKETS" ss -lntup
section "ROUTES AND ADDRESSES" sh -c 'ip -brief address; printf "\n"; ip route'
section "DNS RESOLUTION" getent ahosts example.com
section "RECENT HIGH-CPU PROCESSES" sh -c 'ps -eo pid,ppid,stat,%cpu,%mem,comm --sort=-%cpu | head -25'

redact >"$report_file"
printf 'Report written to %s\n' "$report_file"
