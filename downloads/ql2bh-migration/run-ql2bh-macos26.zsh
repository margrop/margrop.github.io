#!/usr/bin/env zsh
set -euo pipefail

QL_DATA="${QL_DATA:-./qinglong-data}"
BH_DATA="${BH_DATA:-./baihu-data}"
BH_CONTAINER="${BH_CONTAINER:-baihu}"

IMAGE="$(docker inspect "$BH_CONTAINER" --format '{{.Config.Image}}')"
docker stop "$BH_CONTAINER" >/dev/null
trap 'docker start "$BH_CONTAINER" >/dev/null' EXIT

docker run --rm \
  -v "$PWD/ql2bh-migrate.py:/work/ql2bh-migrate.py:ro" \
  -v "${QL_DATA:a}:/tmp/ql2bh-migration-lab/qinglong-data:ro" \
  -v "${BH_DATA:a}:/tmp/ql2bh-migration-lab/baihu-data" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  "$IMAGE" python /work/ql2bh-migrate.py
