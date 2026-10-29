# Home Assistant AI Agent Custom Integration Toolkit
智能家居新手专属：AI Agent 手搓自定义集成三端脚手架与自动化工具箱

## 功能特性
1. **0 外部第三方服务依赖**：基于 Python 3 标准库，无需 `pip install` 任何包。
2. **协议嗅探与探测 (`probe`)**：自动探测局域网内智能设备 API 响应，内置敏感 IP 脱敏。
3. **现代架构脚手架 (`scaffold`)**：一键生成符合 Home Assistant 最新标准的 8 个核心代码文件（含 ConfigFlow、DataUpdateCoordinator、Sensor、Switch 及多语言翻译）。
4. **AST 语法与阻塞审查 (`lint`)**：静态代码分析，严禁在异步事件循环中出现 `requests.get`、`time.sleep` 等导致 HA 卡死的同步阻塞调用。
5. **安全热部署 (`deploy`)**：自动备份原版本并同步到 Home Assistant 的 `/config/custom_components/` 目录。

## 快速使用

### 1. 人工一键执行
- **Windows 11**:
  ```powershell
  .\windows-11.ps1 all
  ```
- **Ubuntu 26.04**:
  ```bash
  bash ubuntu-26.04.sh all
  ```
- **macOS 27**:
  ```zsh
  zsh macos-27.sh all
  ```

### 2. AI Agent 自动接管
将博客文章中的标准指令粘贴给 Claude Code / Codex / Antigravity Agent，Agent 将自动调用本工具链完成设备协议嗅探、骨架生成与合规检查。
