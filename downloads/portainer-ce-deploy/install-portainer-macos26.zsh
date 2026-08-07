#!/bin/zsh
set -euo pipefail

version="${PORTAINER_VERSION:-2.39.4}"
container_name="${PORTAINER_CONTAINER_NAME:-portainer}"
volume_name="${PORTAINER_VOLUME_NAME:-portainer_data}"
enable_legacy_http="${PORTAINER_ENABLE_LEGACY_HTTP:-0}"

while (( $# )); do
  case "$1" in
    --version) version="$2"; shift 2 ;;
    --name) container_name="$2"; shift 2 ;;
    --volume) volume_name="$2"; shift 2 ;;
    --enable-legacy-http) enable_legacy_http=1; shift ;;
    -h|--help)
      print "Usage: $0 [--version 2.39.4] [--name portainer] [--volume portainer_data] [--enable-legacy-http]"
      exit 0
      ;;
    *) print -u2 "Unknown option: $1"; exit 2 ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  print -u2 'Docker Desktop is required. Start Docker Desktop, then rerun this script.'
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  print -u2 'Docker Desktop is installed but its Docker engine is not running.'
  exit 1
fi

if docker container inspect "$container_name" >/dev/null 2>&1; then
  running=$(docker inspect -f '{{.State.Running}}' "$container_name")
  image=$(docker inspect -f '{{.Config.Image}}' "$container_name")
  if [[ "$running" != true ]]; then
    docker start "$container_name" >/dev/null
  fi
  print "Container $container_name already exists and is using $image."
  print 'Open https://localhost:9443'
  exit 0
fi

docker volume inspect "$volume_name" >/dev/null 2>&1 || docker volume create "$volume_name" >/dev/null
image="portainer/portainer-ce:${version}"
docker pull "$image"

run_args=(
  run -d
  -p 9443:9443
  --name "$container_name"
  --restart=always
  -v /var/run/docker.sock:/var/run/docker.sock
  -v "$volume_name:/data"
)
if [[ "$enable_legacy_http" == 1 ]]; then
  run_args+=(-p 9000:9000)
fi
run_args+=("$image")

docker "${run_args[@]}" >/dev/null

for _ in {1..30}; do
  if docker ps --filter "name=^/${container_name}$" --filter status=running --format '{{.Names}}' | grep -qx "$container_name"; then
    print "Portainer $version is running."
    print 'Open https://localhost:9443'
    if [[ "$enable_legacy_http" == 1 ]]; then
      print 'Legacy HTTP is also available at http://localhost:9000'
    fi
    exit 0
  fi
  sleep 1
done

docker logs --tail 80 "$container_name" >&2 || true
print -u2 'Portainer did not reach the running state within 30 seconds.'
exit 1
