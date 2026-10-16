#!/usr/bin/env bash
# ==============================================================================
# Google Account 20-Year Vintage & Keepalive Toolkit (Ubuntu 26.04 LTS Bash Edition)
#
# Capabilities:
#   1. Google Takeout Inspector: Extracts exact birth date and service history from
#      Takeout .zip or SubscriberInfo.html, calculating exact account age.
#   2. 2-Year Inactivity Audit: Audits multiple accounts against Google Inactive
#      Account Policy (730-day deadline) and generates tiered health ratings.
#   3. Zero-Leakage Keepalive: Opens authenticated activity endpoints in default browser.
#
# Modes:
#   - Human Interactive:  ./google_account_toolkit_macos27.zsh
#   - Agent Autonomous:   ./google_account_toolkit_macos27.zsh --auto --audit --json
#
# Zero 3rd-Party Dependencies: macOS native Zsh + Python 3 standard library.
# ==============================================================================

set -e

AUTO_MODE=0
AUDIT_MODE=0
TAKEOUT_PATH=""
JSON_OUTPUT=0
KEEPALIVE_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto|-a)
      AUTO_MODE=1
      shift
      ;;
    --audit)
      AUDIT_MODE=1
      shift
      ;;
    --takeout|-t)
      TAKEOUT_PATH="$2"
      shift 2
      ;;
    --json|-j)
      JSON_OUTPUT=1
      shift
      ;;
    --keepalive|-k)
      KEEPALIVE_MODE=1
      shift
      ;;
    *)
      if [[ -z "$TAKEOUT_PATH" && -f "$1" ]]; then
        TAKEOUT_PATH="$1"
      fi
      shift
      ;;
  esac
done

python3 - "$AUTO_MODE" "$AUDIT_MODE" "$TAKEOUT_PATH" "$JSON_OUTPUT" "$KEEPALIVE_MODE" << 'PYEOF'
import sys, os, json, datetime, re, zipfile, webbrowser

auto_mode = (sys.argv[1] == "1")
audit_mode = (sys.argv[2] == "1")
takeout_path = sys.argv[3]
json_output = (sys.argv[4] == "1")
keepalive_mode = (sys.argv[5] == "1")

CLR_RESET = "[0m"
CLR_CYAN = "[1;36m"
CLR_GREEN = "[1;32m"
CLR_YELLOW = "[1;33m"
CLR_RED = "[1;31m"
CLR_BOLD = "[1m"
CLR_DIM = "[2m"

if json_output:
    CLR_RESET = CLR_CYAN = CLR_GREEN = CLR_YELLOW = CLR_RED = CLR_BOLD = CLR_DIM = ""

def mask_email(email: str) -> str:
    if not email or "@" not in email:
        return "unknown***@gmail.com"
    u, d = email.split("@", 1)
    if len(u) <= 2:
        return f"{u}***@{d}"
    return f"{u[:2]}***{u[-1]}@{d}"

def calculate_age_str(dt: datetime.datetime, ref_now: datetime.datetime) -> tuple:
    total_days = (ref_now - dt).days
    years = total_days // 365
    rem_days = total_days % 365
    months = rem_days // 30
    days = rem_days % 30
    return f"{years}y {months}m {days}d", total_days

def inspect_takeout(path: str):
    if not os.path.exists(path):
        return {"error": f"Path not found: {path}"}
    
    content = ""
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path, 'r') as z:
            for name in z.namelist():
                if "SubscriberInfo.html" in name:
                    content = z.read(name).decode("utf-8", errors="ignore")
                    break
    elif os.path.isdir(path):
        for root, dirs, files in os.walk(path):
            for file in files:
                if "SubscriberInfo.html" in file:
                    with open(os.path.join(root, file), "r", encoding="utf-8", errors="ignore") as f:
                        content = f.read()
                    break
    elif os.path.isfile(path) and "SubscriberInfo.html" in path:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

    if not content:
        return {"error": "Could not locate SubscriberInfo.html in Takeout archive or folder"}

    m_created = re.search(r"Created on:\s*([0-9]{4}-[0-9]{2}-[0-9]{2}\s+[0-9]{2}:[0-9]{2}:[0-9]{2}\s*Z)", content)
    services = re.findall(r"([0-9]{4}-[0-9]{2}-[0-9]{2}\s+[0-9]{2}:[0-9]{2}:[0-9]{2}\s*Z)\s+SERVICE_ADDED\s+([A-Za-z0-9 &]+)", content)
    
    created_str = m_created.group(1).strip() if m_created else None
    res = {
        "created_on": created_str,
        "services": [{"timestamp": s[0], "service": s[1]} for s in services]
    }
    if created_str:
        dt = datetime.datetime.strptime(created_str, "%Y-%m-%d %H:%M:%S Z")
        now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
        age_str, total_days = calculate_age_str(dt, now)
        res["account_age"] = age_str
        res["total_days"] = total_days
        res["vintage_badge"] = "Vintage Maotai (20+ Years)" if total_days >= 7300 else "Standard Active Account"
    return res

def run_audit(accounts_file: str = "accounts.json"):
    if not os.path.exists(accounts_file):
        sample = [
            {"email": "my_personal_account@gmail.com", "created_on": "2006-03-03", "last_active": "2026-10-04"},
            {"email": "work_project_dev@gmail.com", "created_on": "2018-06-15", "last_active": "2025-02-13"},
            {"email": "archive_backup_legacy@gmail.com", "created_on": "2007-11-20", "last_active": "2024-10-26"}
        ]
        with open(accounts_file, "w", encoding="utf-8") as f:
            json.dump(sample, f, indent=2)
    
    with open(accounts_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    now = datetime.datetime.now(datetime.timezone.utc).date()
    DEADLINE_DAYS = 730
    report = []
    has_critical = False
    has_warning = False

    for item in data:
        email = item.get("email", "unknown@gmail.com")
        c_date = datetime.datetime.strptime(item.get("created_on", "2020-01-01"), "%Y-%m-%d").date()
        l_date = datetime.datetime.strptime(item.get("last_active", "2024-01-01"), "%Y-%m-%d").date()
        
        age_days = (now - c_date).days
        age_str = f"{age_days // 365}y {(age_days % 365) // 30}m"
        inactive_days = (now - l_date).days
        days_left = DEADLINE_DAYS - inactive_days

        if days_left <= 30:
            status = "CRITICAL"
            has_critical = True
        elif days_left <= 180:
            status = "WARNING"
            has_warning = True
        else:
            status = "SAFE"

        report.append({
            "account_masked": mask_email(email),
            "created_on": str(c_date),
            "account_age": age_str,
            "last_active": str(l_date),
            "inactive_days": inactive_days,
            "days_left": days_left,
            "status": status,
            "action_required": "IMMEDIATE LOGIN" if status == "CRITICAL" else ("Keepalive Soon" if status == "WARNING" else "None")
        })

    return report, has_critical, has_warning

if not json_output:
    print(f"{CLR_BOLD}{CLR_CYAN}=== [ Google Account 20-Year Vintage & Keepalive Health Toolkit ] ==={CLR_RESET}")
    print(f"{CLR_DIM}Platform: Ubuntu 26.04 Bash | Policy: 2-Year Inactivity Purge (730 Days){CLR_RESET}\n")

if takeout_path:
    info = inspect_takeout(takeout_path)
    if json_output:
        print(json.dumps(info, indent=2, ensure_ascii=False))
        sys.exit(0)
    print(f"{CLR_BOLD}[*] Inspecting Google Takeout Archive:{CLR_RESET} {takeout_path}")
    if "error" in info:
        print(f"{CLR_RED}[!] Error: {info['error']}{CLR_RESET}")
    else:
        print(f"  {CLR_GREEN}✓ Created On:{CLR_RESET} {info['created_on']}")
        print(f"  {CLR_GREEN}✓ Account Age:{CLR_RESET} {info.get('account_age')} ({info.get('total_days')} days in service)")
        print(f"  {CLR_YELLOW}✓ Classification:{CLR_RESET} {info.get('vintage_badge')}")
        print("  Services Initialized:")
        for s in info.get("services", []):
            print(f"    - [{s['timestamp']}] {s['service']}")
    print("")

if audit_mode or (not takeout_path and not auto_mode):
    report, has_crit, has_warn = run_audit()
    if json_output:
        print(json.dumps(report, indent=2, ensure_ascii=False))
        sys.exit(1 if (has_crit or has_warn) else 0)

    print(f"{CLR_BOLD}[*] Auditing Accounts against Google 2-Year Inactivity Rule:{CLR_RESET}")
    print(f"{'ACCOUNT':<24} {'CREATED':<12} {'AGE':<8} {'LAST ACTIVE':<12} {'DAYS IDLE':<10} {'STATUS':<12} {'ACTION':<16}")
    print("-" * 100)
    for r in report:
        st_color = CLR_GREEN if r["status"] == "SAFE" else (CLR_YELLOW if r["status"] == "WARNING" else CLR_RED)
        print(f"{r['account_masked']:<24} {r['created_on']:<12} {r['account_age']:<8} {r['last_active']:<12} {str(r['inactive_days']) + 'd':<10} {st_color + r['status'] + CLR_RESET:<21} {r['action_required']:<16}")
    print("-" * 100)

    if has_crit or has_warn or keepalive_mode:
        if not auto_mode:
            print(f"\n{CLR_YELLOW}[?] Open default browser to Google Account Activity to refresh sessions? [Y/n]: {CLR_RESET}", end="")
            choice = input().strip().lower()
            if choice in ("", "y", "yes"):
                webbrowser.open("https://myaccount.google.com/activity")
                print(f"{CLR_GREEN}[✓] Browser opened to: https://myaccount.google.com/activity{CLR_RESET}")
        elif keepalive_mode:
            webbrowser.open("https://myaccount.google.com/activity")
            print(f"{CLR_GREEN}[✓] Autonomous keepalive browser opened.{CLR_RESET}")

    sys.exit(1 if has_crit else 0)

PYEOF
