#!/bin/bash
set -euo pipefail
base=$(cd "$(dirname "$0")" && pwd)
config=${DNS_CARE_CONFIG:-"$base/settings.private.json"}
mode=${1:-audit}
case "$mode" in audit|apply|rollback) ;; *) printf 'Usage: audit | apply | rollback RUN_ID\n' >&2; exit 2 ;; esac
test -f "$config" || { printf 'Copy settings.example.json to settings.private.json and fill your local roles.\n' >&2; exit 2; }
get_setting() {
    if [ "$(uname -s)" = Darwin ]; then
        /usr/bin/plutil -extract "$1" raw -o - "$config"
    else
        python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$config" "$1"
    fi
}
router=$(get_setting router_ssh)
filter=$(get_setting filter_ssh)
for role in "$router" "$filter"; do
    [[ "$role" =~ ^[A-Za-z0-9_@.-]+$ ]] || { printf 'Use a simple, preconfigured SSH alias.\n' >&2; exit 2; }
done
run_id=${2:-"$(date -u +%Y%m%dT%H%M%S)-$RANDOM"}
[[ "$run_id" =~ ^[A-Za-z0-9-]+$ ]] || exit 2
remote="/root/dns-care-$run_id"
ssh_args=(-o BatchMode=yes -o ConnectTimeout=8)
if [ -n "${DNS_CARE_SSH_CONFIG:-}" ]; then
    ssh_args+=(-F "$DNS_CARE_SSH_CONFIG")
fi
if [ "$mode" = rollback ]; then
    ssh "${ssh_args[@]}" "$router" "sh '$remote/core/router.sh' rollback"
    ssh "${ssh_args[@]}" "$filter" "python3 '$remote/core/manage_filter.py' rollback"
    exit 0
fi
scratch=$(mktemp -d "${TMPDIR:-/tmp}/dns-care.XXXXXX")
cleanup() {
    rc=$?
    trap - EXIT
    if [ "$rc" -ne 0 ] && [ "$mode" = apply ]; then
        printf 'Apply failed. Attempting to restore the two original configurations.\n' >&2
        ssh "${ssh_args[@]}" "$router" "test ! -f '$remote/core/router.sh' || sh '$remote/core/router.sh' rollback" || true
        ssh "${ssh_args[@]}" "$filter" "test ! -f '$remote/core/manage_filter.py' || python3 '$remote/core/manage_filter.py' rollback" || true
    fi
    rm -rf "$scratch"
    printf 'Run ID: %s. Remote private receipts: %s\n' "$run_id" "$remote"
    exit "$rc"
}
trap cleanup EXIT
if [ "$(uname -s)" = Darwin ]; then
    COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -czf "$scratch/payload.tar.gz" --exclude='__pycache__' --exclude='*.pyc' -C "$base" core
else
    tar -czf "$scratch/payload.tar.gz" --exclude='__pycache__' --exclude='*.pyc' -C "$base" core
fi
for role in "$router" "$filter"; do
    ssh "${ssh_args[@]}" "$role" "umask 077; mkdir -p '$remote'; chmod 700 '$remote'"
    scp -O "${ssh_args[@]}" "$scratch/payload.tar.gz" "$role:$remote/payload.tar.gz"
    scp -O "${ssh_args[@]}" "$config" "$role:$remote/settings.private.json"
    ssh "${ssh_args[@]}" "$role" "umask 077; tar -xzf '$remote/payload.tar.gz' -C '$remote'"
done
ssh "${ssh_args[@]}" "$filter" "python3 '$remote/core/manage_filter.py' bootstrap"
scp -O "${ssh_args[@]}" "$filter:$remote/resolved.private.json" "$scratch/resolved.private.json"
scp -O "${ssh_args[@]}" "$filter:$remote/local-records.private.sh" "$scratch/local-records.private.sh"
scp -O "${ssh_args[@]}" "$scratch/resolved.private.json" "$scratch/local-records.private.sh" "$router:$remote/"
if [ "$mode" = audit ]; then
    ssh "${ssh_args[@]}" "$router" "sh '$remote/core/router.sh' audit"
    ssh "${ssh_args[@]}" "$filter" "python3 '$remote/core/manage_filter.py' audit"
    exit 0
fi
ssh "${ssh_args[@]}" "$filter" "python3 '$remote/core/manage_filter.py' adapter"
ssh "${ssh_args[@]}" "$router" "sh '$remote/core/router.sh' apply"
sleep 3
ssh "${ssh_args[@]}" "$filter" "python3 '$remote/core/manage_filter.py' verify-router"
ssh "${ssh_args[@]}" "$filter" "python3 '$remote/core/manage_filter.py' adguard"
ssh "${ssh_args[@]}" "$filter" "python3 '$remote/core/manage_filter.py' verify-all"
if [ "$(uname -s)" = Darwin ]; then
    /usr/bin/dscacheutil -flushcache || true
elif command -v resolvectl >/dev/null; then
    resolvectl flush-caches 2>/dev/null || true
fi
printf 'PASS: server profile applied and live DNS checks completed.\n'
