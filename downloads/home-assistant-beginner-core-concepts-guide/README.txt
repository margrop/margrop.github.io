# Home Assistant Beginner Diagnostic & Starter Toolkit (HA 新手三端巡检与治理工具箱)

适用于 Windows 11 / Ubuntu 26.04 / macOS 27 的零依赖本地自动化工具箱。

## 核心能力
1. `discover`: 自动扫描局域网并发现 Home Assistant 8123 / 8124 开放端口；
2. `audit`: 连接 REST API 深度体检所有实体状态，揪出掉线不可用的幽灵设备；
3. `bootstrap`: 一键生成标准区域划分、现代 Sections 瓷贴卡片仪表盘与三套黄金自动化模板。

## 使用方法 (Method 1: 人工手动执行)
- Windows 11 (PowerShell):
  powershell -ExecutionPolicy Bypass -File .\windows-11.ps1 discover
  powershell -ExecutionPolicy Bypass -File .\windows-11.ps1 audit --url http://homeassistant.local:8123 --token <YOUR_TOKEN>
  powershell -ExecutionPolicy Bypass -File .\windows-11.ps1 bootstrap

- Ubuntu 26.04 (Bash):
  bash ubuntu-26.04.sh discover
  bash ubuntu-26.04.sh audit --url http://homeassistant.local:8123 --token <YOUR_TOKEN>
  bash ubuntu-26.04.sh bootstrap

- macOS 27 (Zsh):
  zsh macos-27.sh discover
  zsh macos-27.sh audit --url http://homeassistant.local:8123 --token <YOUR_TOKEN>
  zsh macos-27.sh bootstrap

## 使用方法 (Method 2: AI Agent 自动化执行)
Agent 可通过管道调用 `python3 ha_beginner_kit.py audit --url <URL> --token <TOKEN>`，直接解析生成的 `ha_health_report.json` 并根据返回的 `unavailable_entities` 实施自愈逻辑。
