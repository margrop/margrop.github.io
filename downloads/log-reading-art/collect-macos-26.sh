#!/usr/bin/env bash
set -euo pipefail

hours=4
output_dir="${PWD}/log-report-macos"

usage() {
  cat <<'EOF'
Usage: collect-macos-26.sh [--hours 1-168] [--output DIRECTORY]

Collects a local, read-only troubleshooting report using macOS built-in tools.
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
raw_file=$(mktemp "${TMPDIR:-/tmp}/log-reading-macos.XXXXXX")
report_file="$output_dir/macos-log-report.txt"
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
  local host short_host user
  host=$(scutil --get ComputerName 2>/dev/null || true)
  short_host=$(hostname -s 2>/dev/null || true)
  user=${USER:-}
  sed -E \
    -e 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[IP-REDACTED]/g' \
    -e 's/([[:alnum:]_-]+\.)+(local|lan|internal|home)/[DOMAIN-REDACTED]/gI' \
    -e 's#/Users/[^/[:space:]]+#/Users/[USER-REDACTED]#g' \
    -e 's/(Bearer|token|secret|password|apikey|api_key)[=:[:space:]]+[^[:space:]]+/\1=[SECRET-REDACTED]/gI' \
    -e "${host:+s/${host//\//\\/}/[HOST-REDACTED]/g}" \
    -e "${short_host:+s/${short_host//\//\\/}/[HOST-REDACTED]/g}" \
    -e "${user:+s/${user//\//\\/}/[USER-REDACTED]/g}" \
    "$raw_file"
}

{
  printf 'macOS troubleshooting evidence report\n'
  printf 'Generated: %s\n' "$(date -Iseconds)"
  printf 'Window: last %s hour(s)\n' "$hours"
  printf 'Mode: read-only, local-only, redacted\n'
} >"$raw_file"

section "OS AND CLOCK" sh -c 'sw_vers; printf "\n"; uname -a; printf "\n"; systemsetup -gettimezone 2>/dev/null || true'
section "DISK" df -h
section "UNIFIED LOG ERRORS" /usr/bin/log show --last "${hours}h" --style compact --predicate 'messageType == error OR messageType == fault' --info --debug
section "LAUNCH SERVICES" launchctl list
section "LISTENING SOCKETS" netstat -anv -p tcp
section "NETWORK CONFIGURATION" scutil --nwi
section "DNS CONFIGURATION" scutil --dns
section "DNS RESOLUTION" dscacheutil -q host -a name example.com
section "RECENT HIGH-CPU PROCESSES" sh -c 'ps -Ao pid,ppid,state,%cpu,%mem,comm -r | head -25'

redact | awk 'NR <= 1600' >"$report_file"
printf 'Report written to %s\n' "$report_file"
