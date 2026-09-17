AdGuard Home DoH configuration toolkit
Requires Python 3.10+ (standard library only), a configured AdGuard Home,
and a trusted HTTPS management connection or a trusted SSH loopback tunnel.
No packages, cloud automation service, telemetry or runtime downloads.

Human use: run the platform launcher with --apply and answer local prompts.
Without --apply, only preflight and candidate-upstream tests are performed.
Agent use: provide --plan and --password-file pointing to private local files.
Plan keys: base_url (without /control), username, upstreams (HTTPS URL array).
Optional plan key: ca_file (trusted private CA file).

Only global upstream_dns and fallback_dns are changed. Fallbacks are cleared.
Bootstrap, client-specific DNS, router settings and OS DNS are not modified.
File-managed and domain-scoped upstream configurations are refused.
Run during a maintenance window without concurrent administrative edits.
Backups can contain private resolver data. Use an owner-only directory,
including an appropriate ACL on Windows. Never publish backups or secrets.
API success is not browser acceptance. Check A/AAAA, the query log, valid
HTTPS and expected page content after configuration.

Rollback: add --restore PATH_TO_BACKUP --apply using the same plan/credentials.
A newer configuration edit causes rollback to be refused.
An interrupted or disconnected run may require manual recovery from backup.

Validation: shared core tested against a simulated API; Bash syntax and
macOS launcher checked. Windows 11 and Ubuntu 26.04 are compatibility targets,
not claimed live production test environments.
