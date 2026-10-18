Tunnel Doctor Kit
=================

中文说明
--------
用途：排查 Cloudflare Tunnel 公网返回 530 / 1033、而源站本身正常的情况。
重点处理 cloudflared 的 QUIC（UDP 7844）连接间歇失败，把连接器固定为 http2（TCP 7844），
可选升级 Docker 镜像，并支持回滚。

文件：
  windows-11.ps1      Windows 11：Windows 服务 + Docker Desktop
  ubuntu-26.04.sh     Ubuntu 26.04：systemd 服务 + Docker / Docker Compose / Portainer 栈
  macos-27.command    macOS 27：launchd 服务 + Docker Desktop
  agent-prompt.txt    交给本地运维 Agent 的任务说明
  MANIFEST.sha256     文件校验值

四种模式：
  audit     只读：检查 TCP 7844、连接器版本、协议设置、最近 24 小时日志
  apply     固定 http2；先备份，修改后等待 "Registered tunnel connection"，等不到就自动回滚
  upgrade   只针对 compose 管理的容器：先拉取新镜像，成功后再改 image 并重建，失败自动回滚
  rollback  按运行编号恢复所有备份

用法：
  Windows 11（管理员 PowerShell）：
    powershell -NoProfile -ExecutionPolicy Bypass -File .\windows-11.ps1 -Mode Audit
    powershell -NoProfile -ExecutionPolicy Bypass -File .\windows-11.ps1 -Mode Apply
    powershell -NoProfile -ExecutionPolicy Bypass -File .\windows-11.ps1 -Mode Upgrade -Version 2026.10.1
    powershell -NoProfile -ExecutionPolicy Bypass -File .\windows-11.ps1 -Mode Rollback -RunId RUN_ID
  Ubuntu 26.04：
    sudo bash ./ubuntu-26.04.sh audit
    sudo bash ./ubuntu-26.04.sh apply
    sudo bash ./ubuntu-26.04.sh upgrade 2026.10.1
    sudo bash ./ubuntu-26.04.sh rollback RUN_ID
  macOS 27（系统级 LaunchDaemon 需要 sudo，Docker Desktop 不需要）：
    bash ./macos-27.command audit
    bash ./macos-27.command apply
    bash ./macos-27.command upgrade 2026.10.1
    bash ./macos-27.command rollback RUN_ID

可选参数：--target NAME（-Target）只处理指定容器、服务或 plist；--image REPO（-Image）指定镜像仓库，
默认 cloudflare/cloudflared。环境变量 TUNNEL_DOCTOR_WAIT 控制等待注册的秒数（默认 25）。

依赖：只用系统自带工具和你已经安装的 Docker / cloudflared。不调用任何云端 API，不下载远程脚本。
upgrade 模式会从你配置的镜像仓库拉取镜像，这是升级本身需要的网络访问。

不会做的事：不读取、不打印、不修改隧道 Token（日志里出现的 Token 会被替换为 <TOKEN>）；
不改 Cloudflare 后台的路由；不改不是 compose 管理的容器（只给出手动步骤）。

测试范围：
  Ubuntu 脚本：在 Ubuntu 24.04 + Docker Compose v2 上实机跑通 audit / apply（字符串和列表两种 command 写法）/
    幂等 / upgrade / 拉取失败 / 注册失败自动回滚 / 手动回滚，并识别了 Portainer 栈的 compose 路径；
    systemd 分支未在真实 systemd 版 cloudflared 上执行。
  macOS 脚本：在 macOS 上用用户级 LaunchAgent 实机跑通 audit / apply / 幂等 / 自动回滚 / 手动回滚。
  Windows 脚本：PowerShell 7.6 语法解析与 compose 编辑、Token 遮盖、日志统计等函数测试通过；
    未在真实 Windows 11 服务上执行，使用前请先运行 Audit 并阅读源码。

English
-------
Tunnel Doctor diagnoses a Cloudflare Tunnel that returns 530 / 1033 while the origin is healthy.
It pins cloudflared to the http2 transport (TCP 7844) when QUIC over UDP 7844 is flaky, can upgrade
compose-managed images, and keeps backups for rollback.

Modes: audit (read-only), apply, upgrade VERSION, rollback RUN_ID. See the commands above; the flags and
behaviour are the same on all three platforms. No cloud API calls, no remote script downloads, tokens are
never printed. Test coverage is listed above: Ubuntu and macOS paths were exercised end to end, the Windows
script passed parser and function tests on PowerShell 7.6 but was not run against a real Windows 11 service.
