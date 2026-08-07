#!/usr/bin/env bash
set -euo pipefail

SOURCE="${1:-}"
DESTINATION="${2:-}"
MODE="${3:---plan}"
DELETE_POLICY="${ALLOW_DELETE:-0}"
PLAN_FILE="${PLAN_FILE:-./rsync-plan-$(date +%Y%m%d-%H%M%S).txt}"

if [[ -z "$SOURCE" || -z "$DESTINATION" ]]; then
  echo "Usage: $0 <source/> <user@host:/destination/> [--plan|--apply]" >&2
  exit 2
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is unavailable. Restore the macOS system tool or install rsync with Homebrew." >&2
  exit 1
fi

SOURCE="${SOURCE%/}/"
RSYNC_ARGS=(-aiv --human-readable --partial --itemize-changes --out-format=%i\|%n%L)
if [[ "$DELETE_POLICY" == "1" ]]; then
  RSYNC_ARGS+=(--delete-after)
fi

echo "Source:      $SOURCE"
echo "Destination: $DESTINATION"
echo "Delete:      $([[ "$DELETE_POLICY" == "1" ]] && echo enabled || echo disabled)"

if [[ "$MODE" == "--plan" ]]; then
  rsync --dry-run "${RSYNC_ARGS[@]}" "$SOURCE" "$DESTINATION" | tee "$PLAN_FILE"
  echo "Plan saved to $PLAN_FILE"
elif [[ "$MODE" == "--apply" ]]; then
  rsync --dry-run "${RSYNC_ARGS[@]}" "$SOURCE" "$DESTINATION" | tee "$PLAN_FILE"
  read -r -p "Apply exactly this incremental sync? Type APPLY: " CONFIRMATION
  [[ "$CONFIRMATION" == "APPLY" ]] || { echo "Cancelled."; exit 1; }
  rsync "${RSYNC_ARGS[@]}" "$SOURCE" "$DESTINATION"
  echo "Post-sync verification:"
  rsync --dry-run "${RSYNC_ARGS[@]}" "$SOURCE" "$DESTINATION"
else
  echo "Mode must be --plan or --apply." >&2
  exit 2
fi
