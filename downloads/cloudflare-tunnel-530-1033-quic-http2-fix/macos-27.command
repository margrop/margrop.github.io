#!/usr/bin/env bash
# Tunnel Doctor for macOS 27
# Diagnose a cloudflared connector that drops offline (Cloudflare 530 / 1033),
# pin it to the http2 transport, optionally upgrade the image, and roll back.
#
# Usage:
#   bash ./macos-27.command audit
#   bash ./macos-27.command apply              [--target NAME]
#   bash ./macos-27.command upgrade 2026.10.1  [--target NAME] [--image REPO]
#   bash ./macos-27.command rollback RUN_ID
#
# No cloud API, no remote script download. Only Docker Desktop / launchd / PlistBuddy.
# System LaunchDaemons need sudo; Docker Desktop containers do not.
set -euo pipefail
export LC_ALL=C

IFS=$' \t\n'
MODE="${1:-audit}"; shift || true
ARG=""; TARGET=""; IMAGE_REPO="cloudflare/cloudflared"
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --image)  IMAGE_REPO="$2"; shift 2 ;;
    *) ARG="$1"; shift ;;
  esac
done

STATE_DIR="${TUNNEL_DOCTOR_STATE:-$HOME/Library/Application Support/tunnel-doctor}"
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
PB=/usr/libexec/PlistBuddy
have() { command -v "$1" >/dev/null 2>&1; }

# ---------- discovery ----------
docker_targets() {
  have docker || return 0
  docker ps -a --format '{{.Names}}\t{{.Image}}' 2>/dev/null \
    | awk -F'\t' 'tolower($2) ~ /cloudflared/ {print $1}' \
    | { if [ -n "$TARGET" ]; then grep -Fx "$TARGET" || true; else cat; fi; }
}
launchd_targets() { # plist paths of cloudflared services
  local f
  for f in /Library/LaunchDaemons/*cloudflared*.plist "$HOME"/Library/LaunchAgents/*cloudflared*.plist; do
    [ -f "$f" ] || continue
    if [ -n "$TARGET" ] && [ "$(basename "$f" .plist)" != "$TARGET" ]; then continue; fi
    printf '%s\n' "$f"
  done
}
plist_label()  { "$PB" -c 'Print :Label' "$1" 2>/dev/null; }
plist_errlog() { "$PB" -c 'Print :StandardErrorPath' "$1" 2>/dev/null || "$PB" -c 'Print :StandardOutPath' "$1" 2>/dev/null || true; }
plist_pinned() {
  "$PB" -c 'Print :EnvironmentVariables:TUNNEL_TRANSPORT_PROTOCOL' "$1" >/dev/null 2>&1 \
    || "$PB" -c 'Print :ProgramArguments' "$1" 2>/dev/null | grep -q -- '--protocol'
}
plist_domain() { case "$1" in /Library/LaunchDaemons/*) echo system ;; *) echo "gui/$(id -u)" ;; esac; }
plist_needs_root() { case "$1" in /Library/LaunchDaemons/*) [ "$(id -u)" -eq 0 ] || { say "sudo is required for $1"; exit 1; } ;; esac; }

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
    if dscacheutil -q host -a name "$h" | grep -q address; then ok "DNS $h resolves"; else bad "DNS $h does not resolve"; continue; fi
    if nc -z -G 5 "$h" 7844 >/dev/null 2>&1; then ok "TCP $h:7844 reachable"
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

audit_launchd() {
  local f="$1" log
  say "launchd service: $(plist_label "$f") ($f)"
  log="$(plist_errlog "$f")"
  say "  version: $( { [ -r "$log" ] && grep -oE 'Version [0-9]{4}\.[0-9]+\.[0-9]+' "$log" | tail -1 | awk '{print $2}'; } || true)"
  if plist_pinned "$f"; then ok "transport already pinned to http2"
  else warn "transport is auto (quic first)"; fi
  log="$(plist_errlog "$f")"
  if [ -n "$log" ] && [ -r "$log" ]; then tail -n 3000 "$log" | report_logs "$(plist_label "$f")"
  else warn "no readable log file in plist (StandardErrorPath)"; fi
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
wait_registered_log() { # $1 log file, $2 line count before restart
  local i
  for i in $(seq 1 "$WAIT_SECONDS"); do
    tail -n +"$(( $2 + 1 ))" "$1" 2>/dev/null | grep -q 'Registered tunnel connection' && return 0
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

reload_plist() {
  local f="$1" d; d="$(plist_domain "$f")"
  launchctl bootout "$d" "$f" 2>/dev/null || true
  launchctl bootstrap "$d" "$f"
}

apply_launchd() {
  local f="$1" name log before
  plist_needs_root "$f"
  name="$(basename "$f" .plist)"
  if plist_pinned "$f"; then ok "$name already pins a protocol, nothing to change"; return 0; fi
  mkdir -p "$RUN_DIR"; cp -p "$f" "$RUN_DIR/$name.plist.bak"
  record "launchd	$name	$f	$RUN_DIR/$name.plist.bak"
  "$PB" -c 'Add :EnvironmentVariables dict' "$f" 2>/dev/null || true
  "$PB" -c 'Delete :EnvironmentVariables:TUNNEL_TRANSPORT_PROTOCOL' "$f" 2>/dev/null || true
  "$PB" -c 'Add :EnvironmentVariables:TUNNEL_TRANSPORT_PROTOCOL string http2' "$f"
  plutil -lint "$f" >/dev/null
  log="$(plist_errlog "$f")"; before=0
  [ -n "$log" ] && [ -f "$log" ] && before=$(wc -l < "$log" | tr -d ' ')
  reload_plist "$f"
  if [ -z "$log" ]; then warn "$name reloaded; no log file configured, verify in the Cloudflare dashboard"; return 0; fi
  if wait_registered_log "$log" "$before"; then ok "$name registered with http2"
  else bad "$name did not register within ${WAIT_SECONDS}s, rolling back"; restore_run "$RUN_ID"; return 1; fi
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
      launchd)
        plist_needs_root "$path"; cp -p "$bak" "$path"; reload_plist "$path" || true
        ok "restored $name from $bak" ;;
    esac
  done < "$STATE_DIR/runs/$id/manifest.tsv"
}

# ---------- main ----------
DOCKER_LIST="$(docker_targets)"; LAUNCHD_LIST="$(launchd_targets)"
say "Tunnel Doctor (macOS) mode=$MODE run=$RUN_ID"
if [ -z "$DOCKER_LIST$LAUNCHD_LIST" ] && [ "$MODE" != rollback ]; then
  say "No cloudflared container or launchd service found on this host."; exit 0
fi

case "$MODE" in
  audit)
    check_edge
    for c in $DOCKER_LIST; do audit_docker "$c"; done
    for f in $LAUNCHD_LIST; do audit_launchd "$f"; done ;;
  apply)
    check_edge
    for c in $DOCKER_LIST; do apply_docker "$c"; done
    for f in $LAUNCHD_LIST; do apply_launchd "$f"; done ;;
  upgrade)
    for c in $DOCKER_LIST; do upgrade_docker "$c" "$ARG"; done
    [ -n "$LAUNCHD_LIST" ] && say "launchd installs: upgrade the binary with 'brew upgrade cloudflared' or the official .pkg, then run apply again." ;;
  rollback)
    restore_run "$ARG" ;;
  *) say "unknown mode: $MODE (audit|apply|upgrade|rollback)"; exit 1 ;;
esac
[ -f "$RUN_DIR/manifest.tsv" ] && say "Run id: $RUN_ID  (rollback: bash $0 rollback $RUN_ID)"
exit 0
