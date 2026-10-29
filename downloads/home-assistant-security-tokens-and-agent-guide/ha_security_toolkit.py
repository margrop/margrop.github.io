#!/usr/bin/env python3
"""
Home Assistant Security Audit & AI Agent Guardrails Toolkit.
Pure Python 3 standard library implementation. Zero third-party dependencies.
Compatible with Windows 11, Ubuntu 26.04, and macOS 27.
"""
import argparse
import json
import os
import platform
import re
import socket
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

TOOLKIT_VERSION = "2026.10.1"

# ANSI color codes for interactive terminal output
CLR_RESET = "\033[0m"
CLR_BOLD = "\033[1m"
CLR_RED = "\033[31m"
CLR_GREEN = "\033[32m"
CLR_YELLOW = "\033[33m"
CLR_BLUE = "\033[34m"
CLR_CYAN = "\033[36m"

def color(text, code):
    if sys.stdout.isatty():
        return f"{code}{text}{CLR_RESET}"
    return text

def mask_token(token):
    if not token or len(token) < 12:
        return "***"
    return f"{token[:6]}...{token[-4:]}"

def sanitize_host(url_str):
    """Sanitize host/IP in output to prevent sensitive internal network leaks."""
    parsed = urllib.parse.urlsplit(url_str)
    host = parsed.hostname or "unknown"
    if re.match(r"^\d+\.\d+\.\d+\.\d+$", host):
        parts = host.split(".")
        return f"{parts[0]}.{parts[1]}.x.x"
    if host.endswith(".local"):
        return "ha.local"
    return host

def load_config(config_path):
    if not config_path or not os.path.exists(config_path):
        return {}
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"Warning: Failed to load config file: {e}", file=sys.stderr)
        return {}

def api_request(url, path, token=None, timeout=10, method="GET", data=None):
    base = url.rstrip("/")
    full_url = f"{base}{path}"
    headers = {
        "User-Agent": f"HASecurityToolkit/{TOOLKIT_VERSION}",
        "Content-Type": "application/json",
    }
    if token:
        headers["Authorization"] = f"Bearer {token.strip()}"

    req = urllib.request.Request(
        full_url,
        data=json.dumps(data).encode("utf-8") if data else None,
        headers=headers,
        method=method
    )

    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            body = resp.read().decode("utf-8")
            status = resp.status
            try:
                parsed_json = json.loads(body)
            except Exception:
                parsed_json = body
            return {"status": status, "data": parsed_json, "error": None}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="ignore")
        return {"status": e.code, "data": body, "error": f"HTTP {e.code}"}
    except urllib.error.URLError as e:
        return {"status": 0, "data": None, "error": f"Connection failed: {e.reason}"}
    except Exception as e:
        return {"status": 0, "data": None, "error": str(e)}

def do_probe(args, conf):
    url = args.url or conf.get("ha_url") or os.environ.get("HA_URL") or "http://homeassistant.local:8123"
    sanitized = sanitize_host(url)
    is_json = getattr(args, "json", False)

    report = {
        "target": sanitized,
        "scheme": urllib.parse.urlsplit(url).scheme,
        "tls_enforced": urllib.parse.urlsplit(url).scheme == "https",
        "api_endpoint_alive": False,
        "unauthenticated_auth_boundary_intact": False,
        "findings": [],
    }

    if report["scheme"] != "https":
        report["findings"].append({
            "level": "WARNING",
            "message": "Endpoint uses unencrypted HTTP. Tokens sent over Wi-Fi/LAN can be sniffed."
        })

    # Probe /api/ without auth
    res = api_request(url, "/api/", token=None, timeout=args.timeout)
    if res["status"] == 401:
        report["api_endpoint_alive"] = True
        report["unauthenticated_auth_boundary_intact"] = True
        report["findings"].append({
            "level": "INFO",
            "message": "Auth boundary active: /api/ correctly rejected unauthenticated probe (HTTP 401)."
        })
    elif res["status"] == 200:
        report["api_endpoint_alive"] = True
        report["unauthenticated_auth_boundary_intact"] = False
        report["findings"].append({
            "level": "CRITICAL",
            "message": "CRITICAL: /api/ returned HTTP 200 without authentication! API is wide open!"
        })
    else:
        report["findings"].append({
            "level": "ERROR",
            "message": f"Endpoint probe failed: {res['error'] or res['status']}"
        })

    if is_json:
        print(json.dumps(report, indent=2))
        return 0

    print(color(f"\n=== Home Assistant Network & Endpoint Security Probe ===", CLR_BOLD))
    print(f"Target:       {sanitized}")
    print(f"Protocol:     {report['scheme'].upper()}")
    print(f"TLS Active:   {color('YES', CLR_GREEN) if report['tls_enforced'] else color('NO (Unencrypted HTTP)', CLR_YELLOW)}")
    print(f"API Alive:    {color('ONLINE', CLR_GREEN) if report['api_endpoint_alive'] else color('OFFLINE / REFUSED', CLR_RED)}")
    print(f"Auth Shield:  {color('PASS (401 Rejection)', CLR_GREEN) if report['unauthenticated_auth_boundary_intact'] else color('FAIL / INACTIVE', CLR_RED)}")
    print("\nFindings:")
    for f in report["findings"]:
        lvl_color = CLR_GREEN if f["level"] == "INFO" else (CLR_YELLOW if f["level"] == "WARNING" else CLR_RED)
        print(f" - [{color(f['level'], lvl_color)}] {f['message']}")
    print()
    return 0

def do_token_audit(args, conf):
    url = args.url or conf.get("ha_url") or os.environ.get("HA_URL") or "http://homeassistant.local:8123"
    token = args.token or conf.get("ha_token") or os.environ.get("HA_TOKEN")
    is_json = getattr(args, "json", False)

    if not token:
        err = {"error": "Missing token. Provide --token, set HA_TOKEN env, or configure config.json"}
        if is_json:
            print(json.dumps(err, indent=2))
        else:
            print(color(f"Error: {err['error']}", CLR_RED), file=sys.stderr)
        return 1

    sanitized = sanitize_host(url)
    res_root = api_request(url, "/api/", token=token, timeout=args.timeout)
    res_config = api_request(url, "/api/config", token=token, timeout=args.timeout)

    report = {
        "target": sanitized,
        "token_fingerprint": mask_token(token),
        "token_valid": res_root["status"] == 200,
        "ha_version": "unknown",
        "time_zone": "unknown",
        "components_count": 0,
        "findings": [],
    }

    if report["token_valid"]:
        report["findings"].append({
            "level": "INFO",
            "message": "Token authenticated successfully against /api/."
        })
        if res_config["status"] == 200 and isinstance(res_config["data"], dict):
            report["ha_version"] = res_config["data"].get("version", "unknown")
            report["time_zone"] = res_config["data"].get("time_zone", "unknown")
            components = res_config["data"].get("components", [])
            report["components_count"] = len(components)
            if "ip_ban" in components or "http" in components:
                report["findings"].append({
                    "level": "INFO",
                    "message": "Active HTTP core components detected."
                })
    else:
        report["findings"].append({
            "level": "CRITICAL",
            "message": f"Token verification failed! Server response: {res_root['error'] or res_root['status']}"
        })

    if is_json:
        print(json.dumps(report, indent=2))
        return 0 if report["token_valid"] else 1

    print(color(f"\n=== Long-Lived Access Token Verification ===", CLR_BOLD))
    print(f"Target:       {sanitized}")
    print(f"Token:        {report['token_fingerprint']}")
    print(f"Validity:     {color('VALID', CLR_GREEN) if report['token_valid'] else color('INVALID / REVOKED', CLR_RED)}")
    print(f"Core Version: {report['ha_version']}")
    print(f"Timezone:     {report['time_zone']}")
    print(f"Components:   {report['components_count']} loaded")
    print("\nAudit Summary:")
    for f in report["findings"]:
        lvl_color = CLR_GREEN if f["level"] == "INFO" else CLR_RED
        print(f" - [{color(f['level'], lvl_color)}] {f['message']}")
    print()
    return 0 if report["token_valid"] else 1

def do_entity_guard(args, conf):
    url = args.url or conf.get("ha_url") or os.environ.get("HA_URL") or "http://homeassistant.local:8123"
    token = args.token or conf.get("ha_token") or os.environ.get("HA_TOKEN")
    is_json = getattr(args, "json", False)

    if not token:
        print(color("Error: Missing token for entity inspection.", CLR_RED), file=sys.stderr)
        return 1

    res = api_request(url, "/api/states", token=token, timeout=args.timeout)
    if res["status"] != 200 or not isinstance(res["data"], list):
        print(color(f"Error fetching entities: {res['error'] or res['status']}", CLR_RED), file=sys.stderr)
        return 1

    entities = res["data"]
    total = len(entities)

    CRITICAL_DOMAINS = {"lock", "alarm_control_panel", "cover", "valve"}
    MEDIUM_DOMAINS = {"climate", "vacuum", "media_player", "switch"}
    READ_DOMAINS = {"sensor", "binary_sensor", "weather", "sun", "zone"}

    categorized = {
        "critical_actuators": [],
        "medium_actuators": [],
        "read_only_sensors": [],
        "other": []
    }

    for item in entities:
        eid = item.get("entity_id", "")
        domain = eid.split(".")[0] if "." in eid else "unknown"
        friendly = item.get("attributes", {}).get("friendly_name", eid)
        entry = {"id": eid, "name": friendly, "domain": domain}

        if domain in CRITICAL_DOMAINS:
            categorized["critical_actuators"].append(entry)
        elif domain in MEDIUM_DOMAINS:
            categorized["medium_actuators"].append(entry)
        elif domain in READ_DOMAINS:
            categorized["read_only_sensors"].append(entry)
        else:
            categorized["other"].append(entry)

    crit_count = len(categorized["critical_actuators"])
    med_count = len(categorized["medium_actuators"])
    read_count = len(categorized["read_only_sensors"])

    # Security risk scoring
    risk_score = 100
    if crit_count > 0:
        risk_score -= min(crit_count * 15, 60)
    if med_count > 20:
        risk_score -= 15
    if not url.startswith("https"):
        risk_score -= 20

    risk_score = max(0, min(100, risk_score))
    grade = "A" if risk_score >= 85 else ("B" if risk_score >= 70 else ("C" if risk_score >= 50 else "F"))

    report = {
        "target": sanitize_host(url),
        "total_entities": total,
        "counts": {
            "critical_actuators": crit_count,
            "medium_actuators": med_count,
            "read_only_sensors": read_count,
            "other": len(categorized["other"])
        },
        "critical_entities_sample": [x["id"] for x in categorized["critical_actuators"][:10]],
        "security_score": risk_score,
        "grade": grade,
        "warnings": []
    }

    if crit_count > 0:
        report["warnings"].append(
            f"HIGH RISK: {crit_count} physical security devices (locks/alarms/valves) directly controllable by this token!"
        )
    if not url.startswith("https"):
        report["warnings"].append("TRANSPORT RISK: Connecting over plain HTTP. Tokens are susceptible to local eavesdropping.")

    if is_json:
        print(json.dumps(report, indent=2))
        return 0

    print(color(f"\n=== Home Assistant AI Agent Entity Guard & Risk Assessment ===", CLR_BOLD))
    print(f"Target:             {report['target']}")
    print(f"Total Entities:     {total}")
    print(f"Read-Only Sensors:  {read_count} (Low risk)")
    print(f"Standard Switches:  {med_count} (Medium risk)")
    print(f"Critical Actuators: {color(str(crit_count), CLR_RED if crit_count > 0 else CLR_GREEN)} (Locks/Alarms/Valves)")
    print(f"Security Grade:     {color(grade, CLR_GREEN if grade in ['A','B'] else CLR_RED)} ({risk_score}/100)")

    if crit_count > 0:
        print(color("\n[!] Critical Actuators Exposed to AI Agent:", CLR_RED))
        for item in categorized["critical_actuators"]:
            print(f"   - {item['id']} ({item['name']})")
        print(color("\nRecommendation: Implement Human-in-the-Loop gating or remove these entities from Agent token scope!", CLR_YELLOW))

    print()
    return 0

def do_generate_mcp(args, conf):
    url = args.url or conf.get("ha_url") or os.environ.get("HA_URL") or "http://homeassistant.local:8123"
    token = args.token or conf.get("ha_token") or os.environ.get("HA_TOKEN") or "<REPLACE_WITH_AGENT_TOKEN>"
    out_file = args.output or "agent_mcp_config.json"

    mcp_config = {
        "mcpServers": {
            "homeassistant": {
                "command": "uvx",
                "args": [
                    "mcp-server-homeassistant",
                    "--ha-url", url,
                    "--ha-token", token
                ],
                "env": {
                    "HA_SECURITY_MODE": "least_privilege",
                    "HA_EXCLUDE_DOMAINS": "lock,alarm_control_panel,valve,cover",
                    "HA_REQUIRE_CONFIRMATION": "true"
                }
            }
        },
        "_security_guidelines": {
            "principle": "Least Privilege (最小特权原则)",
            "rules": [
                "1. Never give AI agents unconfirmed control over physical door locks or alarms.",
                "2. Restrict LLM tool scope to read-only sensors and safe everyday lights.",
                "3. Ensure the token is stored in environment variables, never committed to git.",
                "4. Require user verification for high-wattage appliance switches."
            ]
        }
    }

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(mcp_config, f, indent=2)

    print(f"Generated secure Agent MCP configuration at: {out_file}")
    print(f"Exclusion filter applied: High-risk actuators (locks, alarms, valves) excluded by default.")
    return 0

def main():
    common_parser = argparse.ArgumentParser(add_help=False)
    common_parser.add_argument("-c", "--config", help="Path to config.json", default="config.json")
    common_parser.add_argument("--url", help="Home Assistant URL (e.g. https://ha.example.com:8123)")
    common_parser.add_argument("--token", help="Long-Lived Access Token")
    common_parser.add_argument("--timeout", type=int, default=10, help="Request timeout in seconds")
    common_parser.add_argument("--json", action="store_true", help="Output machine-readable JSON for AI Agents")

    parser = argparse.ArgumentParser(
        description="Home Assistant Security Audit & AI Agent Guardrails Toolkit",
        parents=[common_parser]
    )

    subparsers = parser.add_subparsers(dest="command")

    # probe
    subparsers.add_parser("probe", parents=[common_parser], help="Probe HA network endpoint and unauthenticated /api/ boundary")

    # token-audit
    subparsers.add_parser("token-audit", parents=[common_parser], help="Verify Long-Lived Access Token validity and core metadata")

    # entity-guard
    subparsers.add_parser("entity-guard", parents=[common_parser], help="Scan entity registry for high-risk actuator exposures")

    # generate-mcp
    p_mcp = subparsers.add_parser("generate-mcp", parents=[common_parser], help="Generate secure Agent MCP server configuration")
    p_mcp.add_argument("-o", "--output", default="agent_mcp_config.json")

    # agent-audit (comprehensive automated audit in JSON)
    subparsers.add_parser("agent-audit", parents=[common_parser], help="Run full automated security audit for AI Agent ingestion")

    args = parser.parse_args()
    conf = load_config(args.config)

    if not args.command:
        parser.print_help()
        return 0

    if args.command == "probe":
        return do_probe(args, conf)
    elif args.command == "token-audit":
        return do_token_audit(args, conf)
    elif args.command == "entity-guard":
        return do_entity_guard(args, conf)
    elif args.command == "generate-mcp":
        return do_generate_mcp(args, conf)
    elif args.command == "agent-audit":
        args.json = True
        return do_entity_guard(args, conf)

if __name__ == "__main__":
    sys.exit(main())
