#!/usr/bin/env bash
# Tunnel Doctor for Ubuntu 26.04
# Diagnose a cloudflared connector that drops offline (Cloudflare 530 / 1033),
# pin it to the http2 transport, optionally upgrade the image, and roll back.
#
# Usage:
#   sudo bash ./ubuntu-26.04.sh audit
#   sudo bash ./ubuntu-26.04.sh apply              [--target NAME]
#   sudo bash ./ubuntu-26.04.sh upgrade 2026.10.1  [--target NAME] [--image REPO]
#   sudo bash ./ubuntu-26.04.sh rollback RUN_ID
#
# No cloud API, no remote script download. Only local docker / systemd / journalctl.
set -euo pipefail
export LC_ALL=C

MODE="${1:-audit}"; shift || true
ARG=""; TARGET=""; IMAGE_REPO="cloudflare/cloudflared"
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --image)  IMAGE_REPO="$2"; shift 2 ;;
    *) ARG="$1"; shift ;;
  esac
done

STATE_DIR="${TUNNEL_DOCTOR_STATE:-/var/lib/tunnel-doctor}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$STATE_DIR/runs/$RUN_ID"
EDGE_HOSTS="region1.v2.argotunnel.com region2.v2.argotunnel.com"
QUIC_SIGNS='no recent network activity|failed to accept QUIC stream|Switching to fallback protocol|egress UDP to port 7844|UDP Connectivity.*status=fail'
WAIT_SECONDS="${TUNNEL_DOCTOR_WAIT:-25}"

say()  { printf '%s\n' "$*"; }
ok()   { printf '  [OK]   %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }
bad()  { printf '  [FAIL] %s\n' "$*"; }
mask() { sed -E 's/eyJ[A-Za-z0-9_=-]{20,}/<TOKEN>/g'; }
need_root() { [ "$(id -u)" -eq 0 ] || { say "Please run with sudo for mode: $MODE"; exit 1; }; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------- discovery ----------
docker_targets() {
  have docker || return 0
  docker ps -a --format '{{.Names}}\t{{.Image}}' 2>/dev/null \
    | awk -F'\t' 'tolower($2) ~ /cloudflared/ {print $1}' \
    | { if [ -n "$TARGET" ]; then grep -Fx "$TARGET" || true; else cat; fi; }
}
systemd_targets() {
  have systemctl || return 0
  systemctl list-unit-files --type=service --no-legend 2>/dev/null \
    | awk '{print $1}' | grep -E '^cloudflared.*\.service$' \
    | { if [ -n "$TARGET" ]; then grep -Fx "$TARGET" || true; else cat; fi; } || true
}

# Compose file of a container. Portainer stores stacks inside its own /data volume,
# so translate that path back to the host when needed.
compose_file_of() {
  local c="$1" f src
  f="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project.config_files"}}' "$c" 2>/dev/null | cut -d, -f1)"
  [ -n "$f" ] || return 1
  if [ -f "$f" ]; then printf '%s\n' "$f"; return 0; fi
  for p in $(docker ps --format '{{.Names}}\t{{.Image}}' | awk -F'\t' '$2 ~ /portainer/ {print $1}'); do
    src="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}' "$p")"
    if [ -n "$src" ] && [ -f "$src${f#/data}" ]; then printf '%s\n' "$src${f#/data}"; return 0; fi
  done
  return 1
}
compose_project_of() { docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$1"; }

container_cmdline() { docker inspect -f '{{join .Config.Cmd " "}} {{range .Config.Env}}{{.}} {{end}}' "$1" 2>/dev/null; }
container_version() { docker logs "$1" 2>&1 | grep -oE 'Version [0-9]{4}\.[0-9]+\.[0-9]+' | tail -1 | awk '{print $2}' || true; }

# ---------- checks ----------
check_edge() {
  say "Edge reachability (TCP 7844 is used by http2, UDP 7844 by quic):"
  local h
  for h in $EDGE_HOSTS; do
    if getent ahosts "$h" >/dev/null 2>&1; then ok "DNS $h resolves"; else bad "DNS $h does not resolve"; continue; fi
    if timeout 5 bash -c "exec 3<>/dev/tcp/$h/7844" 2>/dev/null; then ok "TCP $h:7844 reachable"
    else bad "TCP $h:7844 blocked: http2 fallback cannot work either"; fi
  done
  say "  [INFO] UDP 7844 has no handshake to probe safely; it is judged from connector logs below."
}

report_logs() { # $1 = label, stdin = recent logs
  local logs; logs="$(cat)"
  local reg quic origin
  reg=$(printf '%s\n' "$logs" | grep -c 'Registered tunnel connection' || true)
  quic=$(printf '%s\n' "$logs" | grep -cE "$QUIC_SIGNS" || true)
  origin=$(printf '%s\n' "$logs" | grep -c 'Unable to reach the origin service' || true)
  say "  log window: registered=$reg quic_failures=$quic origin_errors=$origin"
  [ "$quic" -gt 0 ] && warn "$1: QUIC/UDP failures found, pinning http2 is recommended (mode: apply)"
  [ "$origin" -gt 0 ] && warn "$1: some ingress rules point to origins that refuse connections"
  printf '%s\n' "$logs" | grep -E "$QUIC_SIGNS|Registered tunnel|Initiating shutdown|SUMMARY:" | tail -4 | mask | sed 's/^/    /'
}

audit_docker() {
  local c="$1" cmd ver f
  say "Docker container: $c ($(docker inspect -f '{{.State.Status}} restart={{.RestartCount}}' "$c"))"
  cmd="$(container_cmdline "$c")"; ver="$(container_version "$c")"
  say "  image: $(docker inspect -f '{{.Config.Image}}' "$c")  version: ${ver:-unknown}"
  case "$ver" in 2024.*|2023.*|2022.*) warn "connector is older than one year, consider: upgrade" ;; esac
  if printf '%s' "$cmd" | grep -qE -- '--protocol[ =]http2|TUNNEL_TRANSPORT_PROTOCOL=http2'; then ok "transport already pinned to http2"
  else warn "transport is auto (quic first)"; fi
  if printf '%s' "$cmd" | grep -q -- '--token'; then warn "token is a command-line argument, visible in ps; prefer TUNNEL_TOKEN or --token-file"; fi
  if f="$(compose_file_of "$c")"; then ok "compose file: $f"; else warn "not managed by compose: apply will only print manual steps"; fi
  docker logs --since 24h "$c" 2>&1 | report_logs "$c"
}

audit_systemd() {
  local u="$1"
  say "systemd unit: $u ($(systemctl is-active "$u" 2>/dev/null || true))"
  have cloudflared && say "  version: $(cloudflared --version 2>/dev/null | grep -oE '[0-9]{4}\.[0-9]+\.[0-9]+' | head -1)"
  if systemctl show "$u" -p Environment -p ExecStart 2>/dev/null | grep -qE 'TUNNEL_TRANSPORT_PROTOCOL=http2|--protocol[ =]http2'; then ok "transport already pinned to http2"
  else warn "transport is auto (quic first)"; fi
  journalctl -u "$u" --since "-24h" --no-pager 2>/dev/null | report_logs "$u"
}

# ---------- verification ----------
wait_registered_docker() {
  local c="$1" since="$2" i
  for i in $(seq 1 "$WAIT_SECONDS"); do
    docker logs --since "$since" "$c" 2>&1 | grep -q 'Registered tunnel connection' && return 0
    sleep 1
  done
  return 1
}
wait_registered_systemd() {
  local u="$1" since="$2" i
  for i in $(seq 1 "$WAIT_SECONDS"); do
    journalctl -u "$u" --since "$since" --no-pager 2>/dev/null | grep -q 'Registered tunnel connection' && return 0
    sleep 1
  done
  return 1
}

# ---------- changes ----------
record() { mkdir -p "$RUN_DIR"; printf '%s\n' "$*" >> "$RUN_DIR/manifest.tsv"; }

pin_compose_file() { # edit a compose file in place, keep YAML shape
  local f="$1"
  grep -qE -- '--protocol|TUNNEL_TRANSPORT_PROTOCOL' "$f" && return 2
  if grep -qE '^[[:space:]]*command:.*tunnel' "$f"; then
    perl -pi -e 's/^(\s*command:\s*["\x27]?.*?\btunnel)\b/$1 --protocol http2/ if /^\s*command:/' "$f"
  elif grep -qE '^[[:space:]]*-[[:space:]]*["\x27]?tunnel["\x27]?[[:space:]]*$' "$f"; then
    perl -pi -e 's/^(\s*-\s*)(["\x27]?)tunnel\2\s*$/$&$1--protocol\n$1http2\n/' "$f"
  else
    return 1
  fi
}

recreate_compose() { # $1 container, $2 file
  local c="$1" f="$2" p since
  p="$(compose_project_of "$c")"
  docker compose -p "$p" -f "$f" config -q
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  docker compose -p "$p" -f "$f" up -d --force-recreate 2>&1 | tail -2 | sed 's/^/    /'
  wait_registered_docker "$c" "$since"
}

apply_docker() {
  local c="$1" f rc=0
  if ! f="$(compose_file_of "$c")"; then
    warn "$c is not a compose container. Recreate it by hand with: tunnel --protocol http2 run ..."
    return 0
  fi
  mkdir -p "$RUN_DIR"; cp -p "$f" "$RUN_DIR/$c.compose.bak"
  pin_compose_file "$f" || rc=$?
  if [ "$rc" -eq 2 ]; then ok "$c already pins a protocol, nothing to change"; rm -f "$RUN_DIR/$c.compose.bak"; return 0; fi
  if [ "$rc" -ne 0 ]; then bad "$c: could not find the tunnel command in $f"; rm -f "$RUN_DIR/$c.compose.bak"; return 1; fi
  record "compose	$c	$f	$RUN_DIR/$c.compose.bak"
  if recreate_compose "$c" "$f"; then ok "$c registered with http2"
  else bad "$c did not register within ${WAIT_SECONDS}s, rolling back"; restore_run "$RUN_ID"; return 1; fi
}

apply_systemd() {
  local u="$1" d="/etc/systemd/system/$1.d" since
  mkdir -p "$d" "$RUN_DIR"
  [ -f "$d/10-tunnel-doctor.conf" ] && cp -p "$d/10-tunnel-doctor.conf" "$RUN_DIR/$u.dropin.bak"
  record "systemd	$u	$d/10-tunnel-doctor.conf	$RUN_DIR/$u.dropin.bak"
  printf '[Service]\nEnvironment=TUNNEL_TRANSPORT_PROTOCOL=http2\n' > "$d/10-tunnel-doctor.conf"
  systemctl daemon-reload
  since="$(date '+%Y-%m-%d %H:%M:%S')"
  systemctl restart "$u"
  if wait_registered_systemd "$u" "$since"; then ok "$u registered with http2"
  else bad "$u did not register within ${WAIT_SECONDS}s, rolling back"; restore_run "$RUN_ID"; return 1; fi
}

upgrade_docker() {
  local c="$1" ver="$2" f ref
  [ -n "$ver" ] || { say "usage: upgrade VERSION, for example 2026.10.1"; exit 1; }
  f="$(compose_file_of "$c")" || { warn "$c is not a compose container, skip"; return 0; }
  ref="$IMAGE_REPO:$ver"
  say "  pulling $ref ..."
  docker pull "$ref" >/dev/null || { bad "pull failed, nothing changed"; return 1; }
  mkdir -p "$RUN_DIR"; cp -p "$f" "$RUN_DIR/$c.compose.bak"
  record "compose	$c	$f	$RUN_DIR/$c.compose.bak"
  REF="$ref" perl -pi -e 's/^(\s*image:\s*).*cloudflared.*$/$1$ENV{REF}/' "$f"
  if recreate_compose "$c" "$f"; then ok "$c now runs $(container_version "$c")"
  else bad "$c did not register after upgrade, rolling back"; restore_run "$RUN_ID"; return 1; fi
}

restore_run() {
  local id="$1" kind name path bak
  [ -f "$STATE_DIR/runs/$id/manifest.tsv" ] || { say "no such run: $id"; exit 1; }
  while IFS=$'\t' read -r kind name path bak; do
    case "$kind" in
      compose)
        cp -p "$bak" "$path"
        docker compose -p "$(compose_project_of "$name")" -f "$path" up -d >/dev/null 2>&1 || true
        ok "restored $name from $bak" ;;
      systemd)
        if [ -f "$bak" ]; then cp -p "$bak" "$path"; else rm -f "$path"; fi
        systemctl daemon-reload; systemctl restart "$name" || true
        ok "restored $name drop-in" ;;
    esac
  done < "$STATE_DIR/runs/$id/manifest.tsv"
}

# ---------- main ----------
DOCKER_LIST="$(docker_targets)"; SYSTEMD_LIST="$(systemd_targets)"
say "Tunnel Doctor (Ubuntu) mode=$MODE run=$RUN_ID"
if [ -z "$DOCKER_LIST$SYSTEMD_LIST" ] && [ "$MODE" != rollback ]; then
  say "No cloudflared container or systemd unit found on this host."; exit 0
fi

case "$MODE" in
  audit)
    check_edge
    for c in $DOCKER_LIST; do audit_docker "$c"; done
    for u in $SYSTEMD_LIST; do audit_systemd "$u"; done ;;
  apply)
    need_root; check_edge
    for c in $DOCKER_LIST; do apply_docker "$c"; done
    for u in $SYSTEMD_LIST; do apply_systemd "$u"; done ;;
  upgrade)
    need_root
    for c in $DOCKER_LIST; do upgrade_docker "$c" "$ARG"; done
    [ -n "$SYSTEMD_LIST" ] && say "systemd installs: upgrade with 'apt-get install --only-upgrade cloudflared' from the Cloudflare package repository." ;;
  rollback)
    need_root; restore_run "$ARG" ;;
  *) say "unknown mode: $MODE (audit|apply|upgrade|rollback)"; exit 1 ;;
esac
[ -f "$RUN_DIR/manifest.tsv" ] && say "Run id: $RUN_ID  (rollback: sudo bash $0 rollback $RUN_ID)"
exit 0
