#!/usr/bin/env bash
# One-click entry point for Ubuntu 26.04. The lab publishes no host ports and
# removes only resources under its fixed Docker Compose project name.
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  printf '%s\n' 'Docker is required. Install Docker Engine from its official packages first.' >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  printf '%s\n' 'Docker is installed but the daemon is unavailable for this user.' >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  printf '%s\n' 'Docker Compose v2 is required.' >&2
  exit 1
fi

exec "$LAB_DIR/run-lab.sh"
