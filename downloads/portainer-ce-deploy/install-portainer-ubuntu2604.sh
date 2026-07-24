#!/usr/bin/env bash
set -euo pipefail

version="${PORTAINER_VERSION:-2.39.4}"
container_name="${PORTAINER_CONTAINER_NAME:-portainer}"
data_dir="${PORTAINER_DATA_DIR:-/docker/portainer_data}"
enable_legacy_http="${PORTAINER_ENABLE_LEGACY_HTTP:-0}"

while (($#)); do
  case "$1" in
    --version) version="$2"; shift 2 ;;
    --name) container_name="$2"; shift 2 ;;
    --data-dir) data_dir="$2"; shift 2 ;;
    --enable-legacy-http) enable_legacy_http=1; shift ;;
    -h|--help)
      printf '%s\n' "Usage: $0 [--version 2.39.4] [--name portainer] [--data-dir /docker/portainer_data] [--enable-legacy-http]"
      exit 0
      ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  printf '%s\n' 'Docker is required. Install Docker Engine, then rerun this script.' >&2
  exit 1
fi

docker_cmd=(docker)
if ! docker info >/dev/null 2>&1; then
  if command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    docker_cmd=(sudo docker)
  else
    printf '%s\n' 'Docker is installed, but the current user cannot reach the Docker daemon.' >&2
    exit 1
  fi
fi

if "${docker_cmd[@]}" container inspect "$container_name" >/dev/null 2>&1; then
  running=$("${docker_cmd[@]}" inspect -f '{{.State.Running}}' "$container_name")
  image=$("${docker_cmd[@]}" inspect -f '{{.Config.Image}}' "$container_name")
  if [[ "$running" != true ]]; then
    "${docker_cmd[@]}" start "$container_name" >/dev/null
  fi
  printf 'Container %s already exists and is using %s.\n' "$container_name" "$image"
  printf '%s\n' 'Open https://localhost:9443'
  exit 0
fi

if command -v sudo >/dev/null 2>&1 && [[ "${docker_cmd[0]}" == sudo ]]; then
  sudo install -d -m 700 "$data_dir"
else
  install -d -m 700 "$data_dir"
fi

image="portainer/portainer-ce:${version}"
"${docker_cmd[@]}" pull "$image"

run_args=(
  run -d
  -p 9443:9443
  --name "$container_name"
  --restart=always
  -v /var/run/docker.sock:/var/run/docker.sock
  -v "$data_dir:/data"
)
if [[ "$enable_legacy_http" == 1 ]]; then
  run_args+=(-p 9000:9000)
fi
run_args+=("$image")

"${docker_cmd[@]}" "${run_args[@]}" >/dev/null

for _ in {1..30}; do
  if "${docker_cmd[@]}" ps --filter "name=^/${container_name}$" --filter status=running --format '{{.Names}}' | grep -qx "$container_name"; then
    printf 'Portainer %s is running.\n' "$version"
    printf '%s\n' 'Open https://localhost:9443'
    if [[ "$enable_legacy_http" == 1 ]]; then
      printf '%s\n' 'Legacy HTTP is also available at http://localhost:9000'
    fi
    exit 0
  fi
  sleep 1
done

"${docker_cmd[@]}" logs --tail 80 "$container_name" >&2 || true
printf '%s\n' 'Portainer did not reach the running state within 30 seconds.' >&2
exit 1
