#!/bin/sh
set -eu
task_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
mode=${1:-audit}
settings="$task_dir/settings.private.json"
pins="$task_dir/resolved.private.json"
json() { jsonfilter -i "$settings" -e "@.$1"; }
pin() { jsonfilter -i "$pins" -e "@.$1"; }
command -v uci >/dev/null
command -v jsonfilter >/dev/null
test -x /usr/sbin/smartdns

case "$mode" in
audit)
    /etc/init.d/smartdns status
    /usr/sbin/smartdns -v
    printf 'Configured enabled upstream records: '
    uci show smartdns | grep -c "enabled='1'" || true
    exit 0
    ;;
rollback)
    if [ -f "$task_dir/router-before.tar.gz" ]; then
        sha256sum -c "$task_dir/router-before.sha256"
        /etc/init.d/smartdns stop
        tar -xzf "$task_dir/router-before.tar.gz" -C /
        rm -f /etc/smartdns/dns-care.conf /etc/smartdns/domain-set/dns-care-china.list
        /etc/init.d/smartdns start
        /etc/init.d/dnsmasq restart
        printf 'Router rollback completed\n'
    fi
    exit 0
    ;;
apply) ;;
*) exit 2 ;;
esac

test ! -f "$task_dir/router-before.tar.gz"
test "$(uci -q get smartdns.@smartdns[0].port)" = 6053 || {
    printf 'This profile requires the documented dnsmasq:53 -> SmartDNS:6053 topology.\n' >&2
    exit 2
}
test -s "$task_dir/core/china-domains.list"
test "$(wc -l < "$task_dir/core/china-domains.list")" -gt 50000
umask 077
tar -czf "$task_dir/router-before.tar.gz" -C / etc/config/smartdns etc/config/dhcp etc/smartdns
sha256sum "$task_dir/router-before.tar.gz" > "$task_dir/router-before.sha256"
for section in $(uci show smartdns | sed -n 's/^\(smartdns\.[^.]*\)=server$/\1/p'); do
    uci set "$section.enabled=0"
done
add_server() {
    section=$1
    uci set "smartdns.$section=server"
    uci set "smartdns.$section.enabled=1"
    uci set "smartdns.$section.type=https"
    uci set "smartdns.$section.ip=$2"
    uci set "smartdns.$section.addition_arg=-host-ip $3"
    uci set "smartdns.$section.server_group=$4"
    uci set "smartdns.$section.exclude_default_group=$5"
    uci set "smartdns.$section.use_proxy=$6"
}
add_server dns_care_google "$(json upstreams.google.url)" "$(pin google)" oversea 0 1
add_server dns_care_cloudflare "$(json upstreams.cloudflare.url)" "$(pin cloudflare)" oversea 0 1
add_server dns_care_ali "$(json upstreams.ali.url)" "$(pin ali)" china 1 0
add_server dns_care_tencent "$(json upstreams.tencent.url)" "$(pin tencent)" china 1 0
uci set "smartdns.@smartdns[0].proxy_server=http://$(json filter_address):$(json adapter_port)"
uci set smartdns.@smartdns[0].enabled=1
uci set smartdns.@smartdns[0].port=6053
uci set smartdns.@smartdns[0].tcp_server=1
uci set smartdns.@smartdns[0].ipv6_server=1
uci set smartdns.@smartdns[0].auto_set_dnsmasq=1
uci set smartdns.@smartdns[0].speed_check_mode=none
uci set smartdns.@smartdns[0].dualstack_ip_selection=0
uci set smartdns.@smartdns[0].rr_ttl_min=0
uci -q delete smartdns.@smartdns[0].rr_ttl || true
uci -q delete dhcp.@dnsmasq[0].min_cache_ttl || true
uci set smartdns.@smartdns[0].seconddns_enabled=1
uci set smartdns.@smartdns[0].seconddns_port=5335
uci set smartdns.@smartdns[0].seconddns_tcp_server=1
uci set smartdns.@smartdns[0].seconddns_server_group=oversea
uci set smartdns.@smartdns[0].seconddns_no_rule_nameserver=1
uci set smartdns.@smartdns[0].seconddns_no_speed_check=1
uci set smartdns.@smartdns[0].seconddns_no_dualstack_selection=1
uci set smartdns.@smartdns[0].seconddns_no_cache=1
mkdir -p /etc/smartdns/domain-set
cp "$task_dir/core/china-domains.list" /etc/smartdns/domain-set/dns-care-china.list
cat > /etc/smartdns/dns-care.conf <<'CONFIG'
# dns-care-managed: imported system resolvers must not add fallback UDP servers.
resolv-file /dev/null
serve-expired-ttl 3600
serve-expired-reply-ttl 30
CONFIG
if ! grep -q '^conf-file /etc/smartdns/dns-care.conf$' /etc/smartdns/custom.conf; then
    printf '\nconf-file /etc/smartdns/dns-care.conf\n' >> /etc/smartdns/custom.conf
fi
uci set smartdns.dns_care_china=domain-rule-list
uci set smartdns.dns_care_china.enabled=1
uci set smartdns.dns_care_china.server_group=china
uci set smartdns.dns_care_china.domain_list_file=/etc/smartdns/domain-set/dns-care-china.list
uci set smartdns.dns_care_china.speed_check_mode=ping,tcp:80,tcp:443
uci set smartdns.dns_care_china.dualstack_ip_selection=yes
if [ -f "$task_dir/local-records.private.sh" ]; then
    sh "$task_dir/local-records.private.sh"
fi
uci commit smartdns
uci commit dhcp
/etc/init.d/smartdns stop
if [ -f /etc/smartdns/smartdns.cache ]; then
    mv /etc/smartdns/smartdns.cache "$task_dir/cache.before"
fi
/etc/init.d/smartdns start
/etc/init.d/dnsmasq restart
printf 'Router profile installed; waiting for actual DNS verification\n'
