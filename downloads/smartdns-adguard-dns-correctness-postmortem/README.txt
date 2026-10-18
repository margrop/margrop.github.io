DNS Care Kit — SmartDNS / AdGuard Home incident profile
======================================================

中文说明
--------
本套件为文章所述双主机拓扑提供三个平台入口：
  Windows 11: windows-11.ps1 (PowerShell 5.1+ / Windows OpenSSH)
  Ubuntu 26.04: ubuntu-26.04.sh (Bash / Python 3 / OpenSSH)
  macOS 27: macos-27.command (系统 Bash / plutil / OpenSSH；Mac 无需 Python)

默认 Audit 只审计，不应用配置。Apply 会修改指定设备的 DNS 配置。
脚本无需大模型 API、云自动化服务或新增镜像。代码与国内域名清单随包提供。
验证需要访问指定设备、既有 HTTP CONNECT 代理及 DNS 服务。

适用条件：
1. 软路由已有 SmartDNS 47.x、LuCI UCI、jsonfilter，主端口为 6053，dnsmasq 为 53。
2. 过滤主机是 Ubuntu 26.04，有系统 Python 3、systemd、Docker 和 AdGuard Home。
3. AdGuard 使用绑定挂载的普通 AdGuardHome.yaml 配置文件，不是命名卷或符号链接。
4. 已有无需认证的局域网 HTTP CONNECT 代理；不安装或修改代理订阅。
5. 两个角色使用 IPv4 管理地址；DNS AAAA 记录仍会检查。
6. 操作机已通过 SSH 密钥登录这两台设备，并核验过主机指纹。

开始：
复制 settings.example.json 为 settings.private.json，私下填写各字段。
router_ssh / filter_ssh：现有 SSH 别名，含需要的登录用户。
router_address / filter_address：两台设备的管理地址，仅保存在你的私有文件中。
proxy_url：既有 HTTP CONNECT 代理地址；adapter_port：过滤主机上的空闲端口。
reference_doh_url：你指定的可信标准 DoH 地址，用于 RFC 8484 对照查询，可使用自建服务。
upstreams：四个上游的 HTTPS URL 与连接地址。google/cloudflare 为两条境外角色，ali/tencent 为两条国内角色；键名沿用现场分类，URL 可以替换为你的自建 DoH，并不绑定这些厂商。
地址均由你私下填入；脚本不调用某厂商的专用 JSON API，也不从外部服务自动拉取配置。
adguard_container：现有容器名。
local_records：需要同步到备用 DNS 的静态记录，默认为空数组。
每条记录包含 name 和 address 字段；请填写自己的内容，不要上传私有配置。

Windows 11（当前目录）：
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows-11.ps1 -Mode Audit
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows-11.ps1 -Mode Apply
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows-11.ps1 -Mode Rollback -RunId RUN_ID
可用 -Config 指定其他私有配置文件。未安装 OpenSSH 的 Windows 需要先启用该系统可选组件。

Ubuntu 26.04：
  bash ./ubuntu-26.04.sh audit
  bash ./ubuntu-26.04.sh apply
  bash ./ubuntu-26.04.sh rollback RUN_ID

macOS 27：
  bash ./macos-27.command audit
  bash ./macos-27.command apply
  bash ./macos-27.command rollback RUN_ID

Unix 入口可通过 DNS_CARE_CONFIG 指定私有 JSON，DNS_CARE_SSH_CONFIG 指定私有 SSH 配置。
每次运行会打印 RUN_ID，两台服务器的私有记录位于 /root/dns-care-RUN_ID/。
备份必须保留，直到你确认不再需要撤回。SSH 不通时自动回滚只能尝试，仍需手动恢复访问后执行回滚。
不要在另一个 Apply 还未验收时重复运行 Apply；已存在的适配服务会使新应用停止并要求检查。

流程：可信 DoH 对照与端点信息 -> 受限适配器 -> 备份和 SmartDNS 配置 ->
软路由验证 -> AdGuard 上游调整 -> 两端验证。失败时尝试回滚两端。
普通 YAML 其他段落原样保留，配置只在容器停止后修改；失效系统解析链接仅在确认失效时修复。
不会修改 DHCP、网关、SSH 认证、代理订阅，也不修改客户端 DNS 地址列表。
不配置云端定时任务；附带国内清单为打包时快照，可按自己的维护流程离线替换。

验证范围：
- 文章现场修复：服务重启后的 56 项 DNS 检查、8 项局域网检查及过滤、代理失效场景通过。
- 参数化套件：macOS 27、Ubuntu 26.04 的真实 Audit 入口各通过 28 项精简检查。
- Windows 入口：PowerShell 语法及 Audit/Apply/失败双端回滚/显式回滚四种流程模拟通过。
- Windows 流程模拟运行于 Linux PowerShell 7.4，并非 Windows 11 真实系统 Apply 认证。
- 发布套件的 Apply/rollback 没有在真实 Windows 11 上执行，也没有用它再次覆盖已修复的生产设备。
- 原生产修复使用现场专用脚本完成；此包是其参数化整理版本，适用范围以前述条件为准。
- 对照地址前缀只是排障线索，CDN 会使合法答案不同；不是 DNSSEC 验证。

English
-------
This kit targets the article's two-host profile, rather than arbitrary network configurations.
Use existing key-authenticated SSH aliases and verify host fingerprints first.
Copy settings.example.json to settings.private.json and fill it locally. Never publish that file.
The router must already use dnsmasq:53 -> SmartDNS:6053, with UCI and jsonfilter.
The Ubuntu filter host needs Python 3, systemd, Docker and a bind-mounted regular AdGuard config.
An existing unauthenticated LAN HTTP CONNECT proxy must be working. IPv4 management transport is required.
No LLM API, cloud automation account, newly downloaded executable script or new container image is required.
The intended DNS providers and your devices are contacted for actual DNS verification.
Set reference_doh_url and the four upstream URL/address pairs locally. Self-hosted DoH is supported;
the historical google/cloudflare and ali/tencent keys identify overseas and domestic roles only.
Reference queries use standard RFC 8484 wire messages, with no provider-specific JSON API dependency.

Commands are listed above: Audit is the default; Apply mutates DNS; Rollback requires the printed RUN_ID.
All three entry points orchestrate the same bundled server code. The Mac does not require Python.
Backups and receipts remain on each server in /root/dns-care-RUN_ID/ with private permissions.
Apply failures attempt restoration of both hosts. Lost SSH access can prevent remote restoration.
Existing DHCP, gateways, SSH credentials, subscriptions and client DNS settings are not changed.
Optional local_records entries have name and address fields; keep those records private as well.

The compact verification set contains 28 checks. Reference-prefix agreement is a diagnostic clue,
not a substitute for DNSSEC, authoritative evidence or application verification.
Actual macOS 27 and Ubuntu 26.04 Audit runs passed. Windows parsing and four orchestration-contract
scenarios passed under Linux-hosted PowerShell 7.4; this is not Windows 11 end-to-end Apply certification.
The parameterized Apply was not reapplied to production merely to test the publication bundle.
The original incident repair was separately verified with 56 checks after service restarts.

Domain-list provenance:
https://github.com/felixonmars/dnsmasq-china-list
The bundled list contains 109797 entries. The upstream license is in LICENSE-domain-list.txt.
Script source is provided under LICENSE-scripts.txt.
