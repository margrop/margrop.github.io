#!/usr/bin/env zsh
# ==============================================================================
# iptv_toolkit_macos27.zsh
# 上海电信 IPTV -> OpenWrt/ImmortalWrt + rtp2httpd 一键配置（macOS 27 原生）
# 需与 iptv_router_payload.sh 放在同一目录。只依赖系统自带 zsh / ssh / curl，全部操作通过 SSH 完成，不访问任何第三方服务。
#
#   体检（只读）: zsh iptv_toolkit_macos27.zsh --router 192.168.x.1
#   一键配置    : zsh iptv_toolkit_macos27.zsh --router 192.168.x.1 --apply \
#                    [--pve 192.168.x.10 --vmid 101 --bridge vmbr1]
#   一键回滚    : zsh iptv_toolkit_macos27.zsh --router 192.168.x.1 --rollback --yes \
#                    [--pve 192.168.x.10 --vmid 101 --bridge vmbr1]
# ==============================================================================
setopt errexit nounset pipefail

MODE=check ROUTER="" PVE="" VMID="" BRIDGE=vmbr1 VLAN=85 USER_NAME=root
IPTV_DEV=auto PORT=5140 SCAN_ALL=0 YES=0 NO_FCC=0
FCC_NET="124.75.25" FCC_ID="211" FCC_PORT="7777"   # 上海电信 FCC 服务器（社区公开）
OUT_DIR="${HOME}/iptv-toolkit-$(date +%Y%m%d-%H%M%S)"

usage() { sed -n '3,14p' "$0"; exit "${1:-0}"; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --router) ROUTER="$2"; shift 2 ;;
    --pve) PVE="$2"; shift 2 ;;
    --vmid) VMID="$2"; shift 2 ;;
    --bridge) BRIDGE="$2"; shift 2 ;;
    --vlan) VLAN="$2"; shift 2 ;;
    --user) USER_NAME="$2"; shift 2 ;;
    --iptv-dev) IPTV_DEV="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --no-fcc) NO_FCC=1; shift ;;
    --scan-all) SCAN_ALL=1; shift ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    --check) MODE=check; shift ;;
    --apply) MODE=apply; shift ;;
    --rollback) MODE=rollback; shift ;;
    --yes) YES=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown option: $1" >&2; usage 1 ;;
  esac
done
[[ -n "$ROUTER" ]] || usage 1
[[ -z "$PVE" || -n "$VMID" ]] || { echo "--pve 需要同时指定 --vmid" >&2; exit 1; }
FCC="${FCC_NET}.${FCC_ID}:${FCC_PORT}"; [[ "$NO_FCC" == 1 ]] && FCC=""

c_ok=$'\e[32m' c_warn=$'\e[33m' c_err=$'\e[31m' c_info=$'\e[36m' c_off=$'\e[0m'
info() { printf '%s[local]%s %s\n' "$c_info" "$c_off" "$*"; }
ok()   { printf '%s[local] OK%s   %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '%s[local] WARN%s %s\n' "$c_warn" "$c_off" "$*"; }
die()  { printf '%s[local] FAIL%s %s\n' "$c_err" "$c_off" "$*" >&2; exit 1; }
mask() { sed -E 's/([0-9]+\.[0-9]+)\.[0-9]+\.[0-9]+/\1.x.x/g'; }

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=15)
r_ssh() { ssh "${SSH_OPTS[@]}" "${USER_NAME}@${ROUTER}" "$@"; }
p_ssh() { ssh "${SSH_OPTS[@]}" "root@${PVE}" "$@"; }

SCRIPT_DIR="${0:A:h}"
PAYLOAD_FILE="${PAYLOAD_FILE:-$SCRIPT_DIR/iptv_router_payload.sh}"
[[ -f "$PAYLOAD_FILE" ]] || die "找不到 $PAYLOAD_FILE（请和本脚本放在同一目录）"
payload() { tr -d '\r' <"$PAYLOAD_FILE"; }

run_payload() {  # $1 = mode, $2 = iptv dev
  payload | r_ssh "MODE=$1 IPTV_DEV=$2 LISTEN_PORT=$PORT FCC='$FCC' SCAN_ALL=$SCAN_ALL sh -s"
}

router_devs() { r_ssh 'ls /sys/class/net' | grep -E '^eth[0-9]+$' | sort; }

pve_iptv_net() {  # prints netN that sits on $BRIDGE with tag=$VLAN, if any
  p_ssh "qm config $VMID" | sed -nE "s/^(net[0-9]+): .*bridge=${BRIDGE}(,.*)?,tag=${VLAN}(,.*)?$/\1/p" | head -n1
}

# 1. preflight
info "目标路由器: $(echo "$ROUTER" | mask)   模式: $MODE"
r_ssh true 2>/dev/null || die "SSH 免密登录路由器失败，请先执行: ssh-copy-id ${USER_NAME}@<路由器>"
ok "SSH 连通"
if [[ -n "$PVE" ]]; then
  p_ssh "qm config $VMID >/dev/null" 2>/dev/null || die "PVE 上找不到 VM $VMID 或 SSH 失败"
  ok "PVE 连通，VM $VMID 存在"
fi

case "$MODE" in
  check)
    run_payload check auto
    [[ -n "$PVE" ]] && { n=$(pve_iptv_net || true); [[ -n "$n" ]] && ok "PVE 已有 IPTV 网卡: $n (tag=$VLAN)" || info "PVE 尚未添加 tag=$VLAN 网卡"; }
    ;;
  apply)
    mkdir -p "$OUT_DIR"
    # 2. backup
    r_ssh 'sysupgrade -b /tmp/iptv-pre.tgz >/dev/null 2>&1 && cat /tmp/iptv-pre.tgz && rm -f /tmp/iptv-pre.tgz' >"$OUT_DIR/router-backup.tgz"
    [[ -s "$OUT_DIR/router-backup.tgz" ]] || die "配置备份失败"
    ok "路由器配置已备份: $OUT_DIR/router-backup.tgz"
    # 3. optional: add VLAN NIC on PVE
    dev="$IPTV_DEV"
    if [[ -n "$PVE" ]]; then
      p_ssh "cp /etc/pve/qemu-server/$VMID.conf /root/$VMID.conf.bak-iptv-$(date +%Y%m%d%H%M%S)"
      n=$(pve_iptv_net || true)
      if [[ -n "$n" ]]; then
        ok "PVE 已存在 IPTV 网卡 $n，跳过"
      else
        before=$(router_devs)
        free=$(p_ssh "qm config $VMID" | awk -F: '/^net[0-9]+:/{print $1}' | sed 's/net//' | sort -n | awk 'BEGIN{n=0}{if($1==n)n++}END{print n}')
        p_ssh "qm set $VMID --net$free virtio,bridge=$BRIDGE,tag=$VLAN,firewall=0" >/dev/null
        ok "PVE 已热插拔 net$free (bridge=$BRIDGE, tag=$VLAN)"
        for i in $(seq 1 20); do
          new=$(comm -13 <(echo "$before") <(router_devs) | head -n1)
          [[ -n "$new" ]] && break; sleep 1
        done
        [[ -n "${new:-}" ]] || die "路由器没有识别到新网卡（虚拟机可能不支持热插拔，重启 VM 后再试）"
        dev="$new"; ok "路由器识别到新网卡: $dev"
      fi
    fi
    # 4-7. configure, install, scan, verify on the router
    run_payload apply "$dev" | tee "$OUT_DIR/apply.log"
    # local acceptance
    m3u=$(curl -s -m 10 "http://${ROUTER}:${PORT}/playlist.m3u" || true)
    n_ch=$(printf '%s\n' "$m3u" | grep -c '^http' || true)
    [[ "$n_ch" -gt 0 ]] || die "本机取不到播放列表"
    url=$(printf '%s\n' "$m3u" | awk '/^http/{print; exit}')
    bytes=$(curl -s -m 5 -o /dev/null -w '%{size_download}' "$url" || true)
    ok "本机验收: 播放列表 $n_ch 个频道，5 秒拉流 $((bytes / 1024)) KiB"
    info "播放器填写: http://$(echo "$ROUTER" | mask):${PORT}/playlist.m3u （把 x.x 换成你的路由器地址）"
    ;;
  rollback)
    if [[ "$YES" != 1 ]]; then
      read -r "a?确认回滚 IPTV 配置？[y/N] "; [[ "$a" == y || "$a" == Y ]] || exit 0
    fi
    run_payload rollback auto
    if [[ -n "$PVE" ]]; then
      n=$(pve_iptv_net || true)
      if [[ -n "$n" ]]; then p_ssh "qm set $VMID --delete $n" >/dev/null; ok "PVE 已移除 $n"; else info "PVE 上没有需要移除的 IPTV 网卡"; fi
    fi
    ;;
esac
ok "完成"
