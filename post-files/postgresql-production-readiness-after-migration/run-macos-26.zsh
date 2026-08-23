#!/bin/zsh
# One-click entry point for macOS 26 with Docker Desktop or another compatible
# local Docker runtime. It never changes system PostgreSQL configuration.
set -eu

LAB_DIR="${0:A:h}"

if ! command -v docker >/dev/null 2>&1; then
  print -u2 'Docker CLI is required. Install and start an official compatible Docker runtime first.'
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  print -u2 'Docker is installed but its local daemon is not ready.'
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  print -u2 'Docker Compose v2 is required.'
  exit 1
fi

exec /bin/bash "$LAB_DIR/run-lab.sh"
