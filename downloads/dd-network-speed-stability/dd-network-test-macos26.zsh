#!/bin/zsh
set -euo pipefail

# macOS 26 version. It uses the system zsh, dd, ssh, awk and Perl/Python stdlib.
# No test file is written; both endpoints send bytes to /dev/null.

REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-${USER:-testuser}}"
PORT="${PORT:-22}"
SIZE_MIB="${SIZE_MIB:-16}"
ROUNDS="${ROUNDS:-5}"
DIRECTION="${DIRECTION:-both}"
DRY_RUN="${DRY_RUN:-0}"

usage() {
  cat <<'EOF'
Usage: dd-network-test-macos26.zsh --remote-host HOST [options]
  --remote-host HOST   SSH endpoint (required)
  --remote-user USER   SSH user (default: current user)
  --port PORT          SSH port (default: 22)
  --size-mib N         MiB per round (default: 16, max: 1024)
  --rounds N           rounds per direction (default: 5, max: 100)
  --direction MODE     upload, download or both (default: both)
  --dry-run            print the plan without sending bytes
  -h, --help           show help

Example (replace placeholders):
  ./dd-network-test-macos26.zsh --remote-host 'test-endpoint' --remote-user 'testuser'
EOF
}

die() { echo "ERROR: $*" >&2; exit 2; }
is_uint() { [[ "$1" =~ ^[0-9]+$ ]]; }

while (( $# )); do
  case "$1" in
    --remote-host) (( $# >= 2 )) || die "--remote-host needs a value"; REMOTE_HOST="$2"; shift 2 ;;
    --remote-user) (( $# >= 2 )) || die "--remote-user needs a value"; REMOTE_USER="$2"; shift 2 ;;
    --port) (( $# >= 2 )) || die "--port needs a value"; PORT="$2"; shift 2 ;;
    --size-mib) (( $# >= 2 )) || die "--size-mib needs a value"; SIZE_MIB="$2"; shift 2 ;;
    --rounds) (( $# >= 2 )) || die "--rounds needs a value"; ROUNDS="$2"; shift 2 ;;
    --direction) (( $# >= 2 )) || die "--direction needs a value"; DIRECTION="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ -n "$REMOTE_HOST" ]] || { usage >&2; die "--remote-host is required"; }
[[ "$REMOTE_HOST" =~ ^[A-Za-z0-9._:-]+$ ]] || die "remote host contains unsupported characters"
[[ "$REMOTE_USER" =~ ^[A-Za-z0-9._-]+$ ]] || die "remote user contains unsupported characters"
is_uint "$PORT" && (( PORT >= 1 && PORT <= 65535 )) || die "port must be 1..65535"
is_uint "$SIZE_MIB" && (( SIZE_MIB >= 1 && SIZE_MIB <= 1024 )) || die "size-mib must be 1..1024"
is_uint "$ROUNDS" && (( ROUNDS >= 1 && ROUNDS <= 100 )) || die "rounds must be 1..100"
case "$DIRECTION" in upload|download|both) ;; *) die "direction must be upload, download or both" ;; esac

for command in dd ssh awk; do command -v "$command" >/dev/null 2>&1 || die "$command is required"; done
if command -v perl >/dev/null 2>&1; then
  now() { perl -MTime::HiRes=time -e 'printf "%.6f", time'; }
elif command -v python3 >/dev/null 2>&1; then
  now() { python3 -c 'import time; print(f"{time.time():.6f}", end="")'; }
else
  die "perl or python3 is required for timing"
fi

SSH_TARGET="${REMOTE_USER}@${REMOTE_HOST}"
SSH_OPTS=(-T -p "$PORT" -o BatchMode=yes -o Compression=no -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR)
RESULTS="$(mktemp "${TMPDIR:-/tmp}/dd-network-results.XXXXXX")"
trap 'rm -f "$RESULTS"' EXIT
remote_sink="dd iflag=fullblock of=/dev/null bs=1048576 count=${SIZE_MIB} 2>/dev/null"
remote_source="dd iflag=fullblock if=/dev/zero bs=1048576 count=${SIZE_MIB} 2>/dev/null"

echo "DD network lab: ${SIZE_MIB} MiB × ${ROUNDS} round(s), direction=${DIRECTION}"
echo "Endpoint: ${SSH_TARGET}:${PORT} (bytes are discarded on both ends)"
if [[ "$DRY_RUN" == "1" ]]; then
  echo "DRY-RUN upload: dd iflag=fullblock if=/dev/zero bs=1048576 count=${SIZE_MIB} | ssh ... \"${remote_sink}\""
  echo "DRY-RUN download: ssh ... \"${remote_source}\" | dd iflag=fullblock of=/dev/null bs=1048576 count=${SIZE_MIB}"
  exit 0
fi

echo -n "Checking remote dd ... "
if ssh "${SSH_OPTS[@]}" "$SSH_TARGET" 'command -v dd >/dev/null 2>&1'; then echo "PASS"; else die "remote dd check failed"; fi

run_one() {
  local direction="$1" round="$2" start end elapsed rc err rate
  err="$(mktemp "${TMPDIR:-/tmp}/dd-network-error.XXXXXX")"
  start="$(now)"
  set +e
  if [[ "$direction" == "upload" ]]; then
    dd iflag=fullblock if=/dev/zero bs=1048576 count="$SIZE_MIB" 2>"$err" |
      ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "$remote_sink" >/dev/null 2>>"$err"
  else
    ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "$remote_source" 2>"$err" |
      dd iflag=fullblock of=/dev/null bs=1048576 count="$SIZE_MIB" 2>>"$err" >/dev/null
  fi
  rc=$?
  set -e
  end="$(now)"
  elapsed="$(awk -v s="$start" -v e="$end" 'BEGIN { d=e-s; if (d < 0.000001) d=0.000001; printf "%.6f", d }')"
  if (( rc == 0 )); then
    rate="$(awk -v m="$SIZE_MIB" -v s="$elapsed" 'BEGIN { printf "%.1f", m/s }')"
    printf '%s\t%s\t%s\n' "$direction" "$rc" "$elapsed" >>"$RESULTS"
    printf '%s round=%d rc=0 seconds=%s MiB=%s throughput=%s MiB/s\n' "$direction" "$round" "$elapsed" "$SIZE_MIB" "$rate"
  else
    printf '%s\t%s\t%s\n' "$direction" "$rc" "$elapsed" >>"$RESULTS"
    printf '%s round=%d rc=%d seconds=%s FAIL\n' "$direction" "$round" "$rc" "$elapsed"
    sed -n '1,2p' "$err" >&2 || true
  fi
  rm -f "$err"
}

run_direction() { local direction="$1" round; for (( round=1; round<=ROUNDS; round++ )); do run_one "$direction" "$round"; done; }
[[ "$DIRECTION" == upload || "$DIRECTION" == both ]] && run_direction upload
[[ "$DIRECTION" == download || "$DIRECTION" == both ]] && run_direction download

awk -F '\t' -v size="$SIZE_MIB" '
  { if ($2 == 0) { n[$1]++; r=$3>0 ? size/$3 : 0; sum[$1]+=r; sumsq[$1]+=r*r; if (!( $1 in min) || r<min[$1]) min[$1]=r; if (!( $1 in max) || r>max[$1]) max[$1]=r } else fail[$1]++ }
  END { for (d in n) { avg=sum[d]/n[d]; v=sumsq[d]/n[d]-avg*avg; if (v<0) v=0; cv=avg>0 ? sqrt(v)/avg*100 : 0; printf "SUMMARY %s samples=%d avg=%.1f MiB/s min=%.1f max=%.1f CV=%.1f%% failures=%d\n",d,n[d],avg,min[d],max[d],cv,fail[d]+0 } }
' "$RESULTS"
if awk -F '\t' '$2 != 0 { bad=1 } END { exit bad ? 0 : 1 }' "$RESULTS"; then exit 1; fi
echo "Completed without transfer failures. Repeat at different times for a stability baseline."
