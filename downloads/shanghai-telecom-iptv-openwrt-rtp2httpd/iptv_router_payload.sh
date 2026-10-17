#!/bin/sh
# iptv-router-payload: runs ON the OpenWrt/ImmortalWrt router (POSIX sh / BusyBox ash).
# Inputs (env): MODE=check|apply|rollback  IPTV_DEV=ethX|auto  LISTEN_PORT=5140
#               MCAST_PREFIX=233.18.204  MCAST_PORT=5140  FCC=host:port|""  SCAN_ALL=0|1
set -u
MODE="${MODE:-check}"
IPTV_DEV="${IPTV_DEV:-auto}"
LISTEN_PORT="${LISTEN_PORT:-5140}"
MCAST_PREFIX="${MCAST_PREFIX:-233.18.204}"
MCAST_PORT="${MCAST_PORT:-5140}"
FCC="${FCC:-}"
SCAN_ALL="${SCAN_ALL:-0}"
M3U=/etc/rtp2httpd/iptv.m3u
HOOK=/etc/hotplug.d/iface/90-iptv-route

say()  { printf '[router] %s\n' "$*"; }
ok()   { printf '[router] OK   %s\n' "$*"; }
warn() { printf '[router] WARN %s\n' "$*"; }
die()  { printf '[router] FAIL %s\n' "$*"; exit 1; }
mask() { sed -E 's/([0-9]+\.[0-9]+)\.[0-9]+\.[0-9]+/\1.x.x/g'; }

# Channel table: last octet | group | name  (all on ${MCAST_PREFIX}.N:${MCAST_PORT})
channels() {
cat <<'EOF'
57|上海文广|上海新闻综合
51|上海文广|东方卫视
45|上海文广|生活时尚
48|上海文广|都市剧场
53|上海文广|上海都市
55|上海文广|东方影视
58|上海文广|五星体育
59|上海文广|上海第一财经
65|上海文广|东方财经
63|上海文广|上海教育
52|CCTV|CCTV1
68|CCTV|CCTV2
69|CCTV|CCTV3
70|CCTV|CCTV4
71|CCTV|CCTV5
67|CCTV|CCTV5+
72|CCTV|CCTV6
73|CCTV|CCTV7
74|CCTV|CCTV8
75|CCTV|CCTV9
76|CCTV|CCTV10
77|CCTV|CCTV11
78|CCTV|CCTV12
79|CCTV|CCTV13
80|CCTV|CCTV14
81|CCTV|CCTV15
82|CCTV|CCTV16
83|CCTV|CCTV17
98|CCTV|CETV1
154|CCTV|CETV2
111|CCTV|CETV4
187|CCTV|CETV早期教育
28|CCTV|CGTN
93|卫视频道|安徽卫视
87|卫视频道|北京卫视
221|卫视频道|兵团卫视
94|卫视频道|东南卫视
110|卫视频道|甘肃卫视
88|卫视频道|广东卫视
107|卫视频道|广西卫视
101|卫视频道|贵州卫视
102|卫视频道|海南卫视
103|卫视频道|河北卫视
105|卫视频道|河南卫视
90|卫视频道|黑龙江卫视
92|卫视频道|湖北卫视
86|卫视频道|湖南卫视
108|卫视频道|吉林卫视
85|卫视频道|江苏卫视
95|卫视频道|江西卫视
96|卫视频道|辽宁卫视
217|卫视频道|内蒙古卫视
230|卫视频道|宁夏卫视
112|卫视频道|青海卫视
172|卫视频道|三沙卫视
91|卫视频道|山东卫视
211|卫视频道|山西卫视
223|卫视频道|陕西卫视
89|卫视频道|深圳卫视
99|卫视频道|四川卫视
97|卫视频道|天津卫视
222|卫视频道|西藏卫视
220|卫视频道|新疆卫视
155|卫视频道|延边卫视
106|卫视频道|云南卫视
84|卫视频道|浙江卫视
100|卫视频道|重庆卫视
50|数字频道|欢笑剧场
104|数字频道|金鹰纪实
47|数字频道|乐游
157|数字频道|家庭理财
231|数字频道|财富天下
49|数字频道|法治天地
42|数字频道|快乐垂钓
44|数字频道|游戏风云
116|数字频道|BesTV电影介绍
201|数字频道|IPTV测试
174|数字频道|CHC动作电影
173|数字频道|CHC家庭影院
175|数字频道|CHC影迷电影
178|数字频道|兵器科技
184|数字频道|第一剧场
183|数字频道|风云剧场
185|数字频道|风云音乐
176|数字频道|风云足球
181|数字频道|高尔夫网球
182|数字频道|怀旧剧场
180|数字频道|女性时尚
179|数字频道|世界地理
186|数字频道|文化精品
177|数字频道|央视台球
66|少儿频道|金色学堂
46|少儿频道|动漫秀场
54|少儿频道|哈哈炫动
151|少儿频道|嘉佳卡通
113|少儿频道|金鹰卡通
109|少儿频道|卡酷少儿
224|4K频道|东方卫视「4K」
115|4K频道|欢笑剧场「4K」
169|4K频道|BesTV电影「4K」
170|4K频道|BesTV记录「4K」
114|4K频道|CCTV16「4K」
188|4K频道|CCTV4K「4K」
209|4K频道|北京卫视「4K」
218|4K频道|广东卫视「4K」
227|4K频道|湖南卫视「4K」
226|4K频道|江苏卫视「4K」
228|4K频道|山东卫视「4K」
219|4K频道|深圳卫视「4K」
225|4K频道|四川卫视「4K」
229|4K频道|浙江卫视「4K」
171|4K频道|BesTV动画「4K」
EOF
}

[ -f /etc/openwrt_release ] || die "not an OpenWrt system"
. /etc/openwrt_release
say "firmware: ${DISTRIB_ID:-OpenWrt} ${DISTRIB_RELEASE:-?}  mode: $MODE"

lan_ip() { uci -q get network.lan.ipaddr | awk '{print $1}' | cut -d/ -f1; }
LAN_IP="$(lan_ip)"
[ -n "$LAN_IP" ] || die "cannot read network.lan.ipaddr"

pkg_install() {
	if command -v apk >/dev/null 2>&1; then apk update >/dev/null && apk add "$@"
	else opkg update >/dev/null && opkg install "$@"; fi
}
pkg_remove() {
	if command -v apk >/dev/null 2>&1; then apk del "$@"; else opkg remove "$@"; fi
}

pick_dev() {
	[ "$IPTV_DEV" != auto ] && { echo "$IPTV_DEV"; return; }
	cur="$(uci -q get network.iptv.device)"
	[ -n "$cur" ] && { echo "$cur"; return; }
	used="$(uci show network 2>/dev/null)"
	for d in /sys/class/net/eth*; do
		[ -e "$d" ] || continue
		n="${d##*/}"
		case "$n" in *.*) continue ;; esac
		echo "$used" | grep -q "[' ]$n['. ]" || echo "$n"
	done | head -n1
}

# fetch N seconds of a stream through rtp2httpd, print byte count
probe() {
	f="/tmp/iptv-probe.$$.$1"
	wget -q -O "$f" "http://$LAN_IP:$LISTEN_PORT/rtp/$MCAST_PREFIX.$1:$MCAST_PORT" 2>/dev/null &
	p=$!; sleep "${2:-3}"; kill "$p" 2>/dev/null; wait "$p" 2>/dev/null
	if [ -f "$f" ]; then wc -c <"$f"; else echo 0; fi; rm -f "$f"
}

do_check() {
	dev="$(pick_dev)"
	if [ -n "$dev" ]; then ok "IPTV NIC candidate: $dev"; else warn "no unused ethX found (add a VLAN-tagged NIC first)"; fi
	if uci -q get network.iptv >/dev/null; then
		st="$(ifstatus iptv 2>/dev/null | jsonfilter -e '@.up')"
		addr="$(ifstatus iptv 2>/dev/null | jsonfilter -e '@["ipv4-address"][0].address' | mask)"
		ok "interface iptv exists (up=$st ip=${addr:-none})"
	else
		say "interface iptv not configured yet"
	fi
	if [ -x /usr/bin/rtp2httpd ]; then ok "rtp2httpd installed"; else say "rtp2httpd not installed"; fi
	say "default route: $(ip route | grep '^default' | mask)"
}

do_apply() {
	dev="$(pick_dev)"
	[ -n "$dev" ] || die "no IPTV NIC; pass IPTV_DEV or add a NIC with VLAN tag first"
	[ -e "/sys/class/net/$dev" ] || die "device $dev not found"
	say "using $dev as IPTV uplink"

	uci set network.iptv=interface
	uci set network.iptv.device="$dev"
	uci set network.iptv.proto=dhcp
	uci set network.iptv.defaultroute=0
	uci set network.iptv.peerdns=0
	uci set network.iptv.delegate=0
	uci commit network

	# firewall: rebuild our zone and rules idempotently
	for s in $(uci -X show firewall | sed -nE "s/^firewall\.([^.]+)\.name='(iptv|IPTV-Allow-.*)'$/\1/p"); do
		uci delete "firewall.$s"
	done
	z=$(uci add firewall zone)
	uci set "firewall.$z.name=iptv"
	uci add_list "firewall.$z.network=iptv"
	uci set "firewall.$z.input=REJECT"
	uci set "firewall.$z.output=ACCEPT"
	uci set "firewall.$z.forward=REJECT"
	rule() {
		r=$(uci add firewall rule)
		uci set "firewall.$r.name=$1"; uci set "firewall.$r.src=iptv"
		uci set "firewall.$r.family=ipv4"; uci set "firewall.$r.target=ACCEPT"
		shift
		while [ $# -gt 1 ]; do uci set "firewall.$r.$1=$2"; shift 2; done
	}
	rule IPTV-Allow-DHCP-Renew proto udp dest_port 68
	rule IPTV-Allow-IGMP proto igmp
	rule IPTV-Allow-Multicast proto udp dest_port "$MCAST_PORT"
	[ -n "$FCC" ] && rule IPTV-Allow-FCC proto udp src_ip "${FCC%:*}"
	uci commit firewall

	if [ -n "$FCC" ]; then
		cat >"$HOOK" <<EOF
#!/bin/sh
# Route the IPTV FCC server via the IPTV VLAN gateway (DHCP-provided)
[ "\$INTERFACE" = iptv ] || exit 0
case "\$ACTION" in
ifup|ifupdate)
	gw=\$(ifstatus iptv | jsonfilter -e '@.inactive.route[@.mask=0].nexthop' -e '@.route[@.mask=0].nexthop' | head -n1)
	[ -n "\$gw" ] && ip route replace ${FCC%:*}/32 via "\$gw" dev "\$DEVICE" && logger -t iptv "FCC route via \$gw"
	;;
esac
EOF
		chmod +x "$HOOK"
	fi

	[ -x /usr/bin/rtp2httpd ] || { say "installing rtp2httpd ..."; pkg_install rtp2httpd luci-app-rtp2httpd >/dev/null || die "package install failed"; }
	pkg_install luci-i18n-rtp2httpd-zh-cn >/dev/null 2>&1 || true

	/etc/init.d/firewall reload >/dev/null 2>&1
	ifup iptv
	i=0
	while [ $i -lt 20 ]; do
		addr="$(ifstatus iptv | jsonfilter -e '@["ipv4-address"][0].address')"
		[ -n "$addr" ] && break
		i=$((i + 1)); sleep 1
	done
	[ -n "$addr" ] || die "iptv got no DHCP lease on $dev (check the VLAN tag)"
	ok "iptv lease: $(echo "$addr" | mask)"
	[ -n "$FCC" ] && ACTION=ifup INTERFACE=iptv DEVICE="$dev" sh "$HOOK"

	sec=$(uci -X show rtp2httpd | sed -nE "s/^rtp2httpd\.([^=.]+)=instance$/\1/p" | head -n1)
	[ -n "$sec" ] || sec=$(uci add rtp2httpd instance)
	uci -q delete "rtp2httpd.$sec.listen"
	uci add_list "rtp2httpd.$sec.listen=$LAN_IP:$LISTEN_PORT"
	uci set "rtp2httpd.$sec.enabled=1"
	uci set "rtp2httpd.$sec.upstream_interface=$dev"
	uci set "rtp2httpd.$sec.maxclients=32"
	uci set "rtp2httpd.$sec.workers=2"
	uci set "rtp2httpd.$sec.mcast_rejoin_interval=60"
	uci set "rtp2httpd.$sec.verbose=1"
	uci commit rtp2httpd
	/etc/init.d/rtp2httpd enable
	/etc/init.d/rtp2httpd restart >/dev/null 2>&1
	sleep 2

	say "scanning channels (12 at a time, 3 s each) ..."
	mkdir -p /etc/rtp2httpd
	tmp=/tmp/iptv-scan.$$; : >"$tmp"
	if [ "$SCAN_ALL" = 1 ]; then
		i=1; while [ $i -le 254 ]; do echo "$i|自动发现|频道 $i"; i=$((i + 1)); done
	else
		channels
	fi >"$tmp.list"
	# pass 1: 12 parallel x 3 s; pass 2: retry misses 4 parallel x 6 s (IGMP joins can be slow under load)
	scan() {  # $1 = list file, $2 = parallel, $3 = seconds
		n=0
		while IFS='|' read -r oct grp name; do
			( b=$(probe "$oct" "$3"); [ "$b" -gt 200000 ] && echo "$oct|$grp|$name" >>"$tmp" ) &
			n=$((n + 1)); [ $((n % $2)) -eq 0 ] && wait
		done <"$1"
		wait
	}
	scan "$tmp.list" 12 3
	while IFS='|' read -r oct rest; do grep -q "^$oct|" "$tmp" || echo "$oct|$rest"; done <"$tmp.list" >"$tmp.miss"
	[ -s "$tmp.miss" ] && { say "retrying $(wc -l <"$tmp.miss") silent channels ..."; scan "$tmp.miss" 4 6; }
	rm -f "$tmp.miss"
	total=$(wc -l <"$tmp.list"); live=$(wc -l <"$tmp")
	[ "$live" -gt 0 ] || die "no channel produced data; check firewall/IGMP"
	ok "live channels: $live / $total"

	q=""; [ -n "$FCC" ] && q="?fcc=$FCC"
	{
		echo '#EXTM3U'
		while IFS='|' read -r oct grp name; do
			grep -q "^$oct|" "$tmp" || continue
			printf '#EXTINF:-1 tvg-name="%s" group-title="%s",%s\n' "$name" "$grp" "$name"
			printf 'rtp://%s.%s:%s%s\n' "$MCAST_PREFIX" "$oct" "$MCAST_PORT" "$q"
		done <"$tmp.list"
	} >"$M3U"
	rm -f "$tmp" "$tmp.list"
	uci set "rtp2httpd.$sec.external_m3u=file://$M3U"
	uci set "rtp2httpd.$sec.external_m3u_update_interval=0"
	uci commit rtp2httpd
	/etc/init.d/rtp2httpd restart >/dev/null 2>&1
	sleep 2

	for f in "$HOOK" /etc/rtp2httpd/; do
		[ -e "$f" ] && ! grep -qx "$f" /etc/sysupgrade.conf && echo "$f" >>/etc/sysupgrade.conf
	done

	first=$(sed -n 's#^rtp://[0-9.]*\.\([0-9]*\):.*#\1#p' "$M3U" | head -n1)
	b=$(probe "$first" 5)
	[ "$b" -gt 1000000 ] || die "verification stream too small ($b bytes)"
	ok "verify: $((b / 1024)) KiB in 5 s via rtp2httpd"
	ok "playlist: http://<router>:$LISTEN_PORT/playlist.m3u"
	say "default route still: $(ip route | grep '^default' | mask)"
}

do_rollback() {
	/etc/init.d/rtp2httpd stop >/dev/null 2>&1
	/etc/init.d/rtp2httpd disable >/dev/null 2>&1
	pkg_remove luci-i18n-rtp2httpd-zh-cn luci-app-rtp2httpd rtp2httpd >/dev/null 2>&1
	rm -rf /etc/rtp2httpd "$HOOK" /etc/config/rtp2httpd
	sed -i '\#^/etc/rtp2httpd/$#d;\#^/etc/hotplug.d/iface/90-iptv-route$#d' /etc/sysupgrade.conf
	ifdown iptv 2>/dev/null
	uci -q delete network.iptv; uci commit network
	for s in $(uci -X show firewall | sed -nE "s/^firewall\.([^.]+)\.name='(iptv|IPTV-Allow-.*)'$/\1/p"); do
		uci delete "firewall.$s"
	done
	uci commit firewall
	/etc/init.d/firewall reload >/dev/null 2>&1
	/etc/init.d/network reload >/dev/null 2>&1
	ok "router side rolled back"
}

case "$MODE" in
	check) do_check ;;
	apply) do_apply ;;
	rollback) do_rollback ;;
	*) die "unknown MODE=$MODE" ;;
esac
