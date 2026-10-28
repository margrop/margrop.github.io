========================================================================
SGCC Electricity Beginner Toolkit for Home Assistant
网上国网接入 Home Assistant 新手一键持久化与防重启丢失工具箱
========================================================================

本工具箱为开源纯本地 Python 3 标准库脚本，不依赖任何第三方 pip 库，
不调用外部云端服务，不泄露任何家庭内网敏感信息。

【核心功能】
1. 自动为网上国网采集插件生成的 6 大核心传感器生成“触发式模板镜像”；
2. 彻底解决 Home Assistant Core 重启后卡片提示“找不到实体”的顽疾；
3. 为日用电量建立自动去重的 120 天滚动明细，支持真实业务日期回溯；
4. 修改前全量打时间戳快照，支持语法自动校验与一键安全回滚；
5. 生成高颜值的家庭用电概览 Lovelace 卡片配置。

【快速上手：人工一键执行】
第一步：准备映射文件
  复制 mapping.example.json 为 mapping.local.json，
  填入你自己在加载项中生成的 6 个实体 ID（如 sensor.electricity_charge_balance_xxxx 等）。

第二步：设置环境变量（仅在当前终端有效，不存盘）
  # Windows 11 (PowerShell):
  $env:HOME_ASSISTANT_URL = "http://homeassistant.local:8123"
  $env:HOME_ASSISTANT_TOKEN = "你的HA长期访问令牌"
  $env:HA_CONFIG_DIR = "Z:\config"  # 挂载的 HA 配置目录

  # Linux (Ubuntu 26.04) / macOS 27:
  export HOME_ASSISTANT_URL="http://homeassistant.local:8123"
  export HOME_ASSISTANT_TOKEN="你的HA长期访问令牌"
  export HA_CONFIG_DIR="/path/to/ha/config"

第三步：一键执行
  # Windows 11:
  .\windows-11.ps1 plan      # 预览变更（只读）
  .\windows-11.ps1 check     # 检查语法与连通性
  .\windows-11.ps1 apply --restart  # 安全注入并重启生效

  # Ubuntu 26.04 / macOS 27:
  bash ubuntu-26.04.sh plan
  bash ubuntu-26.04.sh check
  bash ubuntu-26.04.sh apply --restart

========================================================================
