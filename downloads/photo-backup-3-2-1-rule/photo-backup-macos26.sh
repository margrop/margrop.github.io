#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 SOURCE_DIR LOCAL_BACKUP_DIR OFFSITE_BACKUP_DIR [--execute]" >&2
  echo "Default mode is a dry run. The two backup directories must be separate media in real use." >&2
}

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  usage
  exit 2
fi

source_dir=$(cd "$1" && pwd -P)
local_backup_dir=$(mkdir -p "$2" && cd "$2" && pwd -P)
offsite_backup_dir=$(mkdir -p "$3" && cd "$3" && pwd -P)
mode=${4:---dry-run}
timestamp=${BACKUP_TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}
snapshot_name="photo-backup-$timestamp"

if [ "$source_dir" = "$local_backup_dir" ] || [ "$source_dir" = "$offsite_backup_dir" ] || [ "$local_backup_dir" = "$offsite_backup_dir" ]; then
  echo "SOURCE_AND_DESTINATIONS_MUST_DIFFER=1" >&2
  exit 1
fi

if [ "$mode" != "--dry-run" ] && [ "$mode" != "--execute" ]; then
  usage
  exit 2
fi

local_snapshot="$local_backup_dir/$snapshot_name"
offsite_snapshot="$offsite_backup_dir/$snapshot_name"

echo "SOURCE=$source_dir"
echo "LOCAL_SNAPSHOT=$local_snapshot"
echo "OFFSITE_SNAPSHOT=$offsite_snapshot"
echo "COPY_MODE=$mode"
echo "WARNING=Keep the offsite destination on separate media and in a different physical location."

if [ "$mode" = "--dry-run" ]; then
  echo "PLAN=copy source to local snapshot, copy source to offsite snapshot, write SHA256SUMS, verify both copies"
  echo "DRY_RUN_ONLY=1"
  exit 0
fi

mkdir -p "$local_snapshot" "$offsite_snapshot"
manifest=$(mktemp)
cleanup() { rm -f "$manifest"; }
trap cleanup EXIT

(
  cd "$source_dir"
  find . -type f -exec shasum -a 256 '{}' \; | LC_ALL=C sort
) > "$manifest"

ditto "$source_dir/." "$local_snapshot"
ditto "$source_dir/." "$offsite_snapshot"
cp "$manifest" "$local_snapshot/SHA256SUMS"
cp "$manifest" "$offsite_snapshot/SHA256SUMS"

(
  cd "$local_snapshot"
  shasum -a 256 -c SHA256SUMS >/dev/null
)
(
  cd "$offsite_snapshot"
  shasum -a 256 -c SHA256SUMS >/dev/null
)

echo "LOCAL_CHECKSUM=PASS"
echo "OFFSITE_CHECKSUM=PASS"
echo "BACKUP_STATUS=PASS"
