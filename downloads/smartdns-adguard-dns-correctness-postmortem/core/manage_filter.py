#!/usr/bin/env python3
"""Run on the Ubuntu filter host. No third-party Python packages required."""
import argparse
import concurrent.futures
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import shlex
import socket
import ssl
import secrets
import struct
import subprocess
import time
import urllib.parse
import urllib.request
from dns_probe import query, decode

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('mode', choices=['bootstrap', 'adapter', 'adguard', 'verify-router', 'verify-all', 'audit', 'rollback'])
args = parser.parse_args()
CFG = json.loads((ROOT / 'settings.private.json').read_text())
for key in ['router_address', 'filter_address']:
    assert ipaddress.ip_address(CFG[key]).version == 4, 'This kit expects IPv4 LAN transport'
proxy = urllib.parse.urlsplit(CFG['proxy_url'])
os.environ['no_proxy'] = ''
assert proxy.scheme == 'http' and not proxy.username and proxy.port, 'Use an existing unauthenticated LAN HTTP CONNECT proxy'
ipaddress.ip_address(proxy.hostname)
assert 1024 <= int(CFG['adapter_port']) <= 65535
container = CFG['adguard_container']
assert re.fullmatch(r'[A-Za-z0-9_.-]+', container)
for endpoint in list(CFG['upstreams'].values()) + [{'url': CFG['reference_doh_url']}]:
    url = urllib.parse.urlsplit(endpoint['url'])
    assert url.scheme == 'https' and url.hostname and not url.username
    assert (url.port or 443) == 443 and not any(ord(c) <= 32 for c in endpoint['url'])


def run(*cmd, check=True):
    return subprocess.run(cmd, check=check, capture_output=True, text=True).stdout.strip()


def atomic(path, data, mode=0o600):
    path = Path(path)
    previous = path.stat() if path.exists() else None
    temporary = path.with_name(path.name + '.dns-care-new')
    temporary.write_text(data)
    os.chmod(temporary, mode)
    if previous:
        os.chown(temporary, previous.st_uid, previous.st_gid)
    os.replace(temporary, path)


def doh(name, kind='A'):
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({'https': CFG['proxy_url']}),
        urllib.request.HTTPSHandler(context=ssl.create_default_context()))
    ident = secrets.randbelow(65536)
    qtype = 1 if kind == 'A' else 28
    packet = struct.pack('!HHHHHH', ident, 0x100, 1, 0, 0, 0)
    packet += b''.join(bytes([len(label)]) + label.encode('ascii') for label in name.split('.'))
    packet += b'\0' + struct.pack('!HH', qtype, 1)
    request = urllib.request.Request(CFG['reference_doh_url'], data=packet,
        headers={'Content-Type': 'application/dns-message', 'Accept': 'application/dns-message'})
    with opener.open(request, timeout=12) as response:
        result = decode(response.read(65536), ident)
    assert result['rcode'] == 0, 'Reference DNS returned an error'
    return [r['data'] for r in result['answers'] if r['type'] == qtype]


def bootstrap():
    pins = {}
    for key in ['google', 'cloudflare', 'ali', 'tencent']:
        address = ipaddress.ip_address(CFG['upstreams'][key]['address'])
        assert address.version == 4
        pins[key] = str(address)
    assert doh('www.google.com'), 'Configured reference DoH did not return address records'
    atomic(ROOT / 'resolved.private.json', json.dumps(pins, indent=2))
    records = ['#!/bin/sh', 'set -eu']
    for index, record in enumerate(CFG.get('local_records', [])):
        name = record['name']
        assert re.fullmatch(r'[A-Za-z0-9.-]+', name)
        address = str(ipaddress.ip_address(record['address']))
        for entry in [f'dhcp.dns_care_local_{index}=hostrecord',
                      f'dhcp.dns_care_local_{index}.name={name}',
                      f'dhcp.dns_care_local_{index}.ip={address}']:
            records.append('uci set ' + shlex.quote(entry))
    atomic(ROOT / 'local-records.private.sh', '\n'.join(records) + '\n')
    print('Verified reference DoH with TLS; four endpoint pins prepared')


def adapter():
    pins = json.loads((ROOT / 'resolved.private.json').read_text())
    destinations = {pins[key] + ':443': urllib.parse.urlsplit(CFG['upstreams'][key]['url']).hostname + ':443'
                    for key in ['google', 'cloudflare']}
    directory = Path('/etc/dns-care')
    library = Path('/usr/local/lib/dns-care')
    unit = Path('/etc/systemd/system/dns-care-connect.service')
    assert not unit.exists(), 'A previous dns-care service exists; inspect it before another apply'
    assert not directory.exists() and not library.exists(), 'dns-care path already exists'
    directory.mkdir(mode=0o755)
    created = [str(directory)]
    atomic(ROOT / 'adapter-created.marker', json.dumps(created))
    library.mkdir(mode=0o755)
    created.append(str(library))
    atomic(ROOT / 'adapter-created.marker', json.dumps(created))
    settings = {'bind': CFG['filter_address'], 'port': int(CFG['adapter_port']),
                'upstream': [proxy.hostname, proxy.port],
                'allowed_clients': [CFG['router_address'], CFG['filter_address']], 'endpoints': destinations}
    atomic(directory / 'adapter.json', json.dumps(settings), 0o644)
    shutil.copyfile(ROOT / 'core/connect_adapter.py', library / 'adapter.py')
    os.chmod(library / 'adapter.py', 0o644)
    atomic(unit, '''[Unit]
Description=dns-care-managed restricted DoH CONNECT adapter
Wants=network-online.target
After=network-online.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/lib/dns-care/adapter.py --settings /etc/dns-care/adapter.json
DynamicUser=yes
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
RestrictAddressFamilies=AF_INET AF_INET6
CapabilityBoundingSet=
MemoryMax=128M
TasksMax=80
Restart=on-failure
RestartSec=3
[Install]
WantedBy=multi-user.target
''', 0o644)
    run('systemd-analyze', 'verify', str(unit))
    run('systemctl', 'daemon-reload')
    run('systemctl', 'enable', '--now', 'dns-care-connect.service')
    for _ in range(12):
        try:
            with socket.create_connection((CFG['filter_address'], int(CFG['adapter_port'])), timeout=1):
                break
        except OSError:
            time.sleep(1)
    else:
        raise RuntimeError('Adapter did not become ready')
    print('Restricted DoH adapter installed; service enabled')


def config_path():
    data = json.loads(run('docker', 'inspect', container))[0]
    for mount in data['Mounts']:
        if mount['Destination'] == '/opt/adguardhome/conf' and mount['Type'] == 'bind':
            return Path(mount['Source']) / 'AdGuardHome.yaml'
    raise ValueError('Expected an AdGuard bind-mounted configuration directory')


def replace_dns_lists(text, values):
    # Preserve every other YAML byte; reject unfamiliar layout instead of guessing.
    lines = text.splitlines(keepends=True)
    start = next(i for i, line in enumerate(lines) if line.rstrip() == 'dns:')
    end = next((i for i in range(start + 1, len(lines)) if re.match(r'^\S[^#]*:', lines[i])), len(lines))
    block = lines[start + 1:end]
    for key, items in values.items():
        begin = [i for i, line in enumerate(block) if re.match(r'^  ' + key + r':', line)]
        assert len(begin) == 1, 'Unfamiliar AdGuard DNS field layout: ' + key
        first = begin[0]
        last = next((i for i in range(first + 1, len(block)) if re.match(r'^  [a-zA-Z_]+:', block[i])), len(block))
        # Blank lines and comments can belong to the next field; retain them.
        suffix = []
        while last > first + 1 and (not block[last - 1].strip() or block[last - 1].lstrip().startswith('#')):
            suffix.insert(0, block[last - 1]); last -= 1
        replacement = ['  ' + key + ': []\n'] if not items else ['  ' + key + ':\n'] + ['    - ' + json.dumps(item) + '\n' for item in items]
        block[first:last] = replacement
    return ''.join(lines[:start + 1] + block + lines[end:])


def adguard():
    path = config_path()
    assert path.is_file() and not path.is_symlink(), 'Expected a regular AdGuard configuration file'
    run('docker', 'stop', '--timeout', '10', container)
    original = path.read_text()
    shutil.copy2(path, ROOT / 'adguard.original.yaml')
    atomic(ROOT / 'adguard-path.marker', str(path))
    try:
        changed = replace_dns_lists(original, {'upstream_dns': [CFG['router_address'] + ':53'],
                                             'bootstrap_dns': [CFG['router_address'] + ':53'], 'fallback_dns': []})
        atomic(path, changed, path.stat().st_mode & 0o777)
        run('docker', 'start', container)
    except BaseException:
        atomic(path, original)
        run('docker', 'start', container, check=False)
        raise
    resolver = Path('/etc/resolv.conf')
    if resolver.is_symlink() and not resolver.exists():
        atomic(ROOT / 'resolver-link.marker', os.readlink(resolver))
        atomic(resolver, 'nameserver ' + CFG['router_address'] + '\n', 0o644)
    for _ in range(15):
        try:
            if query(CFG['filter_address'], 53, 'www.google.com')['rcode'] == 0:
                break
        except OSError:
            pass
        time.sleep(1)
    else:
        raise RuntimeError('AdGuard did not become ready')
    print('AdGuard DNS upstream lists changed; other YAML sections retained')


def verify(all_targets=True, strict=True):
    targets = [(CFG['router_address'], p) for p in [53, 6053, 5335]]
    if all_targets:
        targets.append((CFG['filter_address'], 53))
    tasks = [(server, port, name, kind, tcp) for server, port in targets
             for name, kind, tcp in [('www.baidu.com', 1, False), ('www.google.com', 1, False),
                                     ('www.youtube.com', 1, False), ('www.google.com', 28, False),
                                     ('www.google.com', 1, True), ('example.com', 16, False),
                                     ('dns-care-check.invalid', 1, False)]]
    reference = [ipaddress.ip_network(value + '/16', strict=False) for value in doh('www.google.com')]

    def one(task):
        server, port, name, kind, tcp = task
        result = {'role': 'router' if server == CFG['router_address'] else 'filter',
                  'port': port, 'name': name, 'type': kind, 'tcp': tcp}
        try:
            reply = query(server, port, name, kind, tcp)
            expected = 3 if name.endswith('.invalid') else 0
            assert reply['rcode'] == expected, 'unexpected DNS response code'
            answers = [r['data'] for r in reply['answers'] if r['type'] == kind]
            if expected == 0:
                assert answers, 'missing answer records'
            if name == 'www.google.com' and kind == 1:
                assert any(ipaddress.ip_address(value) in net for value in answers for net in reference), 'reference address-prefix mismatch; investigate CDN/route or pollution'
            if name == 'www.google.com' and kind == 28:
                assert all(ipaddress.ip_address(value).is_global and ipaddress.ip_address(value).teredo is None for value in answers), 'unexpected IPv6 answer'
            result.update(ok=True, ms=reply['ms'])
        except (OSError, ValueError, AssertionError) as exc:
            result.update(ok=False, error=str(exc))
        return result

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(one, tasks))
    report = {'checks': len(results), 'failed': sum(not item['ok'] for item in results), 'results': results,
              'note': 'Reference-prefix consistency is a diagnostic clue, not DNSSEC validation.'}
    atomic(ROOT / ('verify-all.json' if all_targets else 'verify-router.json'), json.dumps(report, indent=2))
    print(json.dumps({'checks': report['checks'], 'failed': report['failed']}))
    if strict and report['failed']:
        raise RuntimeError('DNS validation failed; rollback required')


def rollback():
    marker = ROOT / 'adguard-path.marker'
    if marker.exists():
        run('docker', 'stop', '--timeout', '10', container)
        shutil.copy2(ROOT / 'adguard.original.yaml', Path(marker.read_text()))
        run('docker', 'start', container)
    marker = ROOT / 'resolver-link.marker'
    if marker.exists():
        path = Path('/etc/resolv.conf')
        path.unlink(missing_ok=True)
        path.symlink_to(marker.read_text())
    if (ROOT / 'adapter-created.marker').exists():
        unit = Path('/etc/systemd/system/dns-care-connect.service')
        if unit.exists():
            assert 'dns-care-managed' in unit.read_text(), 'Unexpected service file; preserve for review'
            run('systemctl', 'disable', '--now', 'dns-care-connect.service', check=False)
            unit.unlink()
        created = json.loads((ROOT / 'adapter-created.marker').read_text())
        for directory, filename in [('/etc/dns-care', 'adapter.json'), ('/usr/local/lib/dns-care', 'adapter.py')]:
            if directory in created:
                (Path(directory) / filename).unlink(missing_ok=True)
                try:
                    Path(directory).rmdir()
                except OSError:
                    print('Extra files in managed directory preserved for review')
        run('systemctl', 'daemon-reload')
    print('Filter-host rollback completed')


if args.mode == 'bootstrap': bootstrap()
elif args.mode == 'adapter': adapter()
elif args.mode == 'adguard': adguard()
elif args.mode == 'verify-router': verify(False)
elif args.mode == 'verify-all': verify(True)
elif args.mode == 'audit': verify(True, False)
elif args.mode == 'rollback': rollback()
