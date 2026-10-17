上海电信 IPTV -> OpenWrt/ImmortalWrt + rtp2httpd 一键配置工具
Shanghai Telecom IPTV -> OpenWrt/ImmortalWrt + rtp2httpd one-click toolkit

四个文件放在同一目录 / Keep all four files in one folder:
  iptv_router_payload.sh      路由器端逻辑（三平台共用）/ router-side logic (shared)
  iptv_toolkit_windows11.ps1  Windows 11 (PowerShell 5.1+)
  iptv_toolkit_ubuntu2604.sh  Ubuntu 26.04 (bash)
  iptv_toolkit_macos27.zsh    macOS 27 (zsh)

默认只读体检；--apply 一键配置；--rollback --yes 一键回滚。
Default is a read-only check; --apply configures; --rollback --yes undoes.
文章 / Article: https://blog.margrop.net/post/shanghai-telecom-iptv-openwrt-rtp2httpd/
