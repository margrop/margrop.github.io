#!/usr/bin/env python3
"""
Home Assistant Beginner Diagnostic, Audit & Starter Bootstrap Toolkit.
Pure Python 3 standard library implementation. Zero third-party dependencies.
"""
import argparse
import json
import os
import platform
import socket
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

BANNER = """
========================================================================
   Home Assistant Beginner Health Check & Onboarding Toolkit
   Zero-Cloud & Zero-Dependency | Windows 11 / Ubuntu 26.04 / macOS 27
========================================================================
"""

STARTER_DASHBOARD_YAML = """# Modern Home Assistant Beginner Dashboard (Sections + Tile Cards)
title: "智慧家庭概览"
views:
  - title: "主控台"
    path: "home"
    icon: "mdi:home-variant"
    type: "sections"
    max_columns: 3
    sections:
      - title: "环境与天气"
        cards:
          - type: weather-forecast
            entity: weather.forecast_home
            show_current: true
            show_forecast: true
          - type: tile
            entity: sun.sun
            name: "太阳轨迹"
            icon: "mdi:weather-sunset"
      - title: "常用照明与开关"
        cards:
          - type: tile
            entity: switch.living_room_light
            name: "客厅吸顶灯"
            icon: "mdi:ceiling-light"
          - type: tile
            entity: switch.balcony_plug
            name: "阳台智能插座"
            icon: "mdi:power-socket-cn"
      - title: "安防与门窗状态"
        cards:
          - type: tile
            entity: binary_sensor.front_door_contact
            name: "防盗入户门"
            icon: "mdi:door"
          - type: tile
            entity: sensor.living_room_temperature
            name: "客厅室内温度"
            icon: "mdi:thermometer"
"""

STARTER_AUTOMATIONS_YAML = """# Beginner Starter Automations (Triggers -> Conditions -> Actions)
# 1. 日落自动开玄关廊灯
- id: "auto_sunset_porch_light"
  alias: "日落自动开启玄关廊灯"
  description: "当太阳完全落入地平线且家中有人时，自动点亮走廊灯"
  trigger:
    - platform: sun
      event: sunset
      offset: "-00:15:00"
  condition:
    - condition: state
      entity_id: zone.home
      state: "1"
  action:
    - service: light.turn_on
      target:
        entity_id: light.hallway_light
      data:
        brightness_pct: 60
  mode: single

# 2. 夜间回家门开亮灯
- id: "auto_night_welcome_light"
  alias: "夜间开门自动亮灯并语音播报"
  description: "夜晚玄关门打开时，瞬间点亮客厅主灯"
  trigger:
    - platform: state
      entity_id: binary_sensor.front_door_contact
      from: "off"
      to: "on"
  condition:
    - condition: state
      entity_id: sun.sun
      state: "below_horizon"
  action:
    - service: light.turn_on
      target:
        entity_id: light.living_room_light
  mode: restart

# 3. 浴室湿度过高自动排气
- id: "auto_bathroom_ventilation"
  alias: "浴室湿度超标自动开启排气扇"
  description: "洗澡湿度突破 80% 时自动开启排气，恢复正常后关闭"
  trigger:
    - platform: numeric_state
      entity_id: sensor.bathroom_humidity
      above: 80
  action:
    - service: switch.turn_on
      target:
        entity_id: switch.bathroom_exhaust_fan
  mode: single
"""

RECOMMENDED_AREAS_JSON = {
    "living_room": {
        "name": "客厅",
        "icon": "mdi:sofa",
        "suggested_entities": ["light.living_room", "climate.living_room_ac", "sensor.living_room_temp"]
    },
    "master_bedroom": {
        "name": "主卧",
        "icon": "mdi:bed",
        "suggested_entities": ["light.bedroom_light", "climate.bedroom_ac", "cover.bedroom_curtain"]
    },
    "kitchen": {
        "name": "厨房",
        "icon": "mdi:countertop",
        "suggested_entities": ["sensor.water_leak", "switch.water_heater", "binary_sensor.gas_sensor"]
    },
    "entrance": {
        "name": "玄关",
        "icon": "mdi:door",
        "suggested_entities": ["binary_sensor.front_door", "light.entryway_light"]
    }
}


def probe_port(host: str, port: int, timeout: float = 0.5) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def get_local_ip_candidates():
    candidates = []
    # Test mDNS hostname
    try:
        ip = socket.gethostbyname("homeassistant.local")
        candidates.append(("homeassistant.local", ip))
    except Exception:
        pass

    # Inspect local interfaces
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        subnet_prefix = ".".join(local_ip.split(".")[:3])
        # Probe common addresses on subnet
        for last in [1, 2, 3, 5, 10, 50, 100, 101, 102, 103, 105, 110, 120, 140, 148, 150, 188, 200]:
            ip = f"{subnet_prefix}.{last}"
            candidates.append((ip, ip))
    except Exception:
        pass
    return candidates


def cmd_discover(args):
    print(BANNER)
    print("[*] 正在发起零云端局域网 Home Assistant 自动发现探测...")
    discovered = []
    
    # 1. Test direct host if specified
    if args.host:
        hosts_to_probe = [args.host]
    else:
        print("[*] 正在嗅探 homeassistant.local 与局域网活跃端口...")
        candidates = get_local_ip_candidates()
        hosts_to_probe = [c[0] for c in candidates]

    def check_host(h):
        for port in [8123, 8124]:
            if probe_port(h, port, timeout=0.8):
                service = "Home Assistant Core (主界面)" if port == 8123 else "Wintermelon Companion (冬瓜伴侣)"
                return (h, port, service)
        return None

    with ThreadPoolExecutor(max_workers=20) as pool:
        results = pool.map(check_host, hosts_to_probe)
        for r in results:
            if r and r not in discovered:
                discovered.append(r)

    if not discovered:
        print("[-] 未在局域网内检测到开放 8123 / 8124 端口的 Home Assistant 实例。")
        print("    建议检查：")
        print("    1. 小主机或虚拟机是否已正常通电并接入同一路由器局域网；")
        print("    2. 本机防火墙是否拦截了局域网 outbound 探测；")
        print("    3. 可尝试手动指定参数: --host <YOUR_HA_IP>")
        return 1

    print("[+] 成功发现局域网内的 Home Assistant 实例：")
    for host, port, desc in discovered:
        masked_host = ".".join(host.split(".")[:2]) + ".x.x" if "." in host and not host.endswith(".local") else host
        print(f"    - http://{masked_host}:{port} -> {desc}")
    print("
[+] 提示：可直接在浏览器中打开上方地址完成初始化入网。")
    return 0


def cmd_audit(args):
    print(BANNER)
    url = args.url.rstrip("/")
    token = args.token
    if not token and os.getenv("HA_TOKEN"):
        token = os.getenv("HA_TOKEN")

    print(f"[*] 正在对目标 Home Assistant 实例执行实体健康体检...")
    req = urllib.request.Request(f"{url}/api/states")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")

    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            elapsed = (time.time() - t0) * 1000
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 401:
            print("[-] HTTP 401 认证失败：需要提供长期访问令牌 (Long-Lived Access Token)。")
            print("    获取方法：进入 HA 界面 -> 点击左下角个人头像 -> 拉到最底部「长期访问令牌」-> 创建令牌。")
            return 2
        print(f"[-] HTTP 请求错误: {e}")
        return 1
    except Exception as e:
        print(f"[-] 无法连接至 {url}: {e}")
        return 1

    total_entities = len(data)
    domain_counts = {}
    unavailable = []
    unknown = []

    for item in data:
        eid = item.get("entity_id", "")
        state = item.get("state", "")
        domain = eid.split(".")[0] if "." in eid else "unknown"
        domain_counts[domain] = domain_counts.get(domain, 0) + 1
        if state == "unavailable":
            unavailable.append(eid)
        elif state == "unknown":
            unknown.append(eid)

    report = {
        "status": "healthy" if len(unavailable) == 0 else "needs_attention",
        "latency_ms": round(elapsed, 2),
        "total_entities": total_entities,
        "domain_breakdown": domain_counts,
        "unavailable_count": len(unavailable),
        "unavailable_entities": unavailable[:10],
        "unknown_count": len(unknown),
    }

    print(f"[+] API 响应耗时: {report['latency_ms']} ms")
    print(f"[+] 注册实体总数: {report['total_entities']}")
    print("[+] 实体类型分类统计:")
    for dom, cnt in sorted(domain_counts.items(), key=lambda x: -x[1])[:8]:
        print(f"    - {dom:15s}: {cnt} 个")

    if unavailable:
        print(f"[!] 发现 {len(unavailable)} 个处于「不可用 (unavailable)」状态的异常实体（前 10 个）：")
        for u in unavailable[:10]:
            print(f"    * {u}")
        print("    建议检查：相关物理设备是否断电、网络集成是否掉线或已被移除。")
    else:
        print("[+] 所有已加载实体状态健康，未发现掉线幽灵实体！")

    out_file = "ha_health_report.json"
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    print(f"[+] 完整体检诊断已输出至: {out_file}")
    return 0


def cmd_bootstrap(args):
    print(BANNER)
    out_dir = Path(args.output_dir or "ha_starter_templates")
    out_dir.mkdir(parents=True, exist_ok=True)

    dash_file = out_dir / "starter_dashboard.yaml"
    dash_file.write_text(STARTER_DASHBOARD_YAML.strip() + "\n", encoding="utf-8")

    auto_file = out_dir / "starter_automations.yaml"
    auto_file.write_text(STARTER_AUTOMATIONS_YAML.strip() + "\n", encoding="utf-8")

    area_file = out_dir / "recommended_areas.json"
    area_file.write_text(json.dumps(RECOMMENDED_AREAS_JSON, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(f"[+] 成功生成开箱即用新手治理模板包于目录: {out_dir}/")
    print(f"    1. {dash_file.name} - 现代 Sections 瓷贴卡片仪表盘模版")
    print(f"    2. {auto_file.name} - 黄金三要素经典自动化案例 (日落开灯/门开亮灯/湿度排气)")
    print(f"    3. {area_file.name} - 黄金四房标准区域空间分类字典")
    print("\n[+] 使用指南：在 HA 仪表盘中点击右上角「编辑仪表盘」-> 原始配置编辑器，粘贴模版即可秒级预览！")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Home Assistant Beginner Diagnostic & Starter Toolkit")
    subparsers = parser.add_subparsers(dest="command")

    p_discover = subparsers.add_parser("discover", help="自动发现局域网内的 Home Assistant 实例与开放端口")
    p_discover.add_argument("--host", help="指定探测的目标主机名或 IP 地址")

    p_audit = subparsers.add_parser("audit", help="连接 HA REST API 审计实体健康度与分类情况")
    p_audit.add_argument("--url", default="http://homeassistant.local:8123", help="HA 基础 URL，默认 http://homeassistant.local:8123")
    p_audit.add_argument("--token", help="长期访问令牌 (Long-Lived Access Token)")

    p_bootstrap = subparsers.add_parser("bootstrap", help="生成开箱即用的新手仪表盘与自动化治理模版")
    p_bootstrap.add_argument("--output-dir", default="ha_starter_templates", help="模版输出目录")

    args = parser.parse_args()
    if not args.command:
        # Default behavior: run discover, then bootstrap
        ret = cmd_discover(args)
        print("\n" + "-" * 72 + "\n")
        args.output_dir = "ha_starter_templates"
        cmd_bootstrap(args)
        return ret
    if args.command == "discover":
        return cmd_discover(args)
    elif args.command == "audit":
        return cmd_audit(args)
    elif args.command == "bootstrap":
        return cmd_bootstrap(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
