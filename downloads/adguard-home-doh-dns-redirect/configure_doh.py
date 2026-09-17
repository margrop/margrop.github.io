#!/usr/bin/env python3
"""Local-only AGH configuration client. Python 3.10+, standard library only."""
import argparse
import base64
import getpass
import ipaddress
import json
import os
from pathlib import Path
import ssl
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request

FIELDS = ('upstream_dns', 'fallback_dns')

class SafeError(Exception):
    pass

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise SafeError('Management API redirect refused; use the final trusted URL.')

class API:
    def __init__(self, url, user, password, ca=None):
        u = urllib.parse.urlsplit(url)
        loopback = u.hostname == 'localhost'
        try:
            loopback = loopback or ipaddress.ip_address(u.hostname or '').is_loopback
        except ValueError:
            pass
        if not u.hostname or u.username or u.password or u.query or u.fragment:
            raise SafeError('Invalid management URL; credentials must be supplied separately.')
        if u.scheme != 'https' and not (u.scheme == 'http' and loopback):
            raise SafeError('Use verified HTTPS, or HTTP loopback through a trusted SSH tunnel.')
        self.base = url.rstrip('/') + '/control/'
        self.auth = 'Basic ' + base64.b64encode((user+':'+password).encode()).decode()
        self.opener = urllib.request.build_opener(
            urllib.request.ProxyHandler({}), NoRedirect(),
            urllib.request.HTTPSHandler(context=ssl.create_default_context(cafile=ca)))

    def call(self, path, data=None):
        payload = None if data is None else json.dumps(data).encode()
        req = urllib.request.Request(self.base+path, data=payload,
              headers={'Authorization': self.auth, 'Content-Type': 'application/json'})
        try:
            with self.opener.open(req, timeout=45) as response:
                raw = response.read()
            return json.loads(raw) if raw.strip() else {}
        except SafeError:
            raise
        except urllib.error.HTTPError as e:
            code = e.code
            e.close()
            raise SafeError('Management API HTTP failure: '+str(code)) from None
        except Exception:
            raise SafeError('API transport or JSON failure; check connectivity, CA and server version.') from None

def load_json(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)

def private_save(directory, data):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, path = tempfile.mkstemp(prefix='agh-backup-', suffix='.json', dir=directory)
    with os.fdopen(fd, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)
    return path

def check_snapshot(info):
    if not isinstance(info, dict) or any(not isinstance(info.get(k), list) for k in FIELDS):
        raise SafeError('Unsupported DNS API schema; no changes made.')
    if not info['upstream_dns']:
        raise SafeError('Empty/default upstream list cannot be restored exactly; use the UI.')
    if info.get('upstream_dns_file'):
        raise SafeError('File-managed upstreams detected; use your existing configuration workflow.')

def test(api, upstreams, bootstrap):
    result = api.call('test_upstream_dns', {'upstream_dns': upstreams,
                      'bootstrap_dns': bootstrap, 'fallback_dns': []})
    if not isinstance(result, dict) or any(result.get(u) != 'OK' for u in upstreams):
        raise SafeError('At least one upstream failed the server-side test; details withheld for privacy.')

def transact(api, desired, directory, test_first=True):
    before = api.call('dns_info')
    check_snapshot(before)
    old = {k: before[k] for k in FIELDS}
    if test_first:
        test(api, desired['upstream_dns'], before.get('bootstrap_dns', []))
    backup = private_save(directory, {'schema': 1, 'restore': old, 'applied': desired})
    print('Backup created in the requested private directory.')
    try:
        # Treat ambiguous write failures as possibly committed, and attempt rollback.
        api.call('dns_config', desired)
        after = api.call('dns_info')
        if any(after.get(k) != desired[k] for k in FIELDS):
            raise SafeError('Configuration read-back mismatch.')
        if test_first:
            test(api, desired['upstream_dns'], after.get('bootstrap_dns', []))
        api.call('cache_clear', {})
    except (Exception, KeyboardInterrupt):
        try:
            api.call('dns_config', old)
            actual = api.call('dns_info')
            if any(actual.get(k) != old[k] for k in FIELDS):
                raise SafeError('Rollback mismatch.')
            api.call('cache_clear', {})
            print('FAILED: previous settings restored and verified.', file=sys.stderr)
        except (Exception, KeyboardInterrupt):
            print('FAILED: automatic rollback unverified. Restore from the private backup via the UI.', file=sys.stderr)
        raise SafeError('Transaction failed; do not treat this run as successful.') from None
    print('APPLIED_AND_READ_BACK: now verify A/AAAA, query logs and the actual browser.')
    return backup

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--plan', help='Private JSON file: base_url, username, upstreams; optional ca_file')
    p.add_argument('--password-file', help='Private local secret file for unattended runs')
    p.add_argument('--backup-dir', default=str(Path.home()/'.agh-doh-backups'))
    p.add_argument('--apply', action='store_true', help='Apply after preflight; otherwise test only')
    p.add_argument('--restore', help='Private backup created by this tool; requires --apply')
    a = p.parse_args()
    plan = load_json(a.plan) if a.plan else {
        'base_url': input('Trusted management URL (no /control suffix): ').strip(),
        'username': input('Administrator username: ').strip(),
        'upstreams': input('HTTPS upstream URL(s), separated by spaces: ').split()}
    password = Path(a.password_file).read_text().rstrip('\r\n') if a.password_file else getpass.getpass('Password: ')
    api = API(plan['base_url'], plan['username'], password, plan.get('ca_file'))
    before = api.call('dns_info')
    check_snapshot(before)
    if a.restore:
        saved = load_json(a.restore)
        if saved.get('schema') != 1:
            raise SafeError('Unknown backup format.')
        desired = saved['restore']
        if any(before[k] != saved['applied'][k] for k in FIELDS):
            raise SafeError('Configuration changed since backup; refusing to overwrite a newer edit.')
        if not a.apply:
            raise SafeError('Restoring requires --apply.')
        transact(api, desired, a.backup_dir, test_first=False)
        return
    upstreams = plan.get('upstreams')
    if not isinstance(upstreams, list) or not upstreams:
        raise SafeError('Supply at least one HTTPS upstream.')
    for u in upstreams:
        v = urllib.parse.urlsplit(u)
        if v.scheme != 'https' or not v.hostname or v.username or v.password or v.fragment:
            raise SafeError('Only plain HTTPS upstream URLs are accepted; scoped rules require manual review.')
    # Do not silently replace split DNS rules used by existing deployments.
    if any(u.lstrip().startswith('[') for u in before['upstream_dns']):
        raise SafeError('Domain-specific routing detected; preserve those rules through the UI.')
    desired = {'upstream_dns': list(dict.fromkeys(upstreams)), 'fallback_dns': []}
    if not a.apply:
        test(api, desired['upstream_dns'], before.get('bootstrap_dns', []))
        print('PREFLIGHT_OK: no persistent settings changed. Use --apply to configure.')
        return
    transact(api, desired, a.backup_dir)

if __name__ == '__main__':
    try:
        main()
    except (Exception, KeyboardInterrupt) as e:
        print(str(e) if isinstance(e, SafeError) else 'Stopped: invalid input, local file or interrupted operation.', file=sys.stderr)
        sys.exit(1)
