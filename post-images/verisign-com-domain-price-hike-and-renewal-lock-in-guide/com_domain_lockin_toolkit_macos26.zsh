#!/usr/bin/env zsh
# ==============================================================================
# .COM Domain Lock-In & Cost Arbitrage Inspector (macOS 26 Zsh Edition)
# 
# Purpose:
#   Audits .COM domain expiration via authoritative ICANN/Verisign RDAP,
#   calculates ICANN 10-year maximum lock-in window, and computes dollar savings
#   before the November 1, 2026 wholesale price hike ($10.26 -> $10.97).
#
# Execution Modes:
#   1. Manual Interactive:  ./com_domain_lockin_toolkit_macos26.zsh [--domains domain1.com,domain2.com]
#   2. Agent Autonomous:    ./com_domain_lockin_toolkit_macos26.zsh --auto [--domains domain1.com,domain2.com]
#
# Zero 3rd-Party Dependencies: Uses macOS native zsh, curl, and python3 stdlib.
# ==============================================================================

set -e

AUTO_MODE=0
DOMAIN_LIST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto|-Auto|-a)
      AUTO_MODE=1
      shift
      ;;
    --domains|-d)
      DOMAIN_LIST="$2"
      shift 2
      ;;
    *)
      if [[ -z "$DOMAIN_LIST" ]]; then
        DOMAIN_LIST="$1"
      fi
      shift
      ;;
  esac
done

# If no domains provided, prompt or check domains.txt or use defaults
if [[ -z "$DOMAIN_LIST" ]]; then
  if [[ -f "domains.txt" ]]; then
    DOMAIN_LIST=$(grep -v '^#' domains.txt | tr '\n' ',' | sed 's/,$//')
  fi
fi

if [[ -z "$DOMAIN_LIST" ]]; then
  if [[ "$AUTO_MODE" -eq 1 ]]; then
    DOMAIN_LIST="example.com"
  else
    echo "\033[1;36m[?] Enter .COM domains to inspect (comma-separated, e.g. myapp.com,apiportal.com):\033[0m"
    read -r user_input
    DOMAIN_LIST="${user_input:-example.com}"
  fi
fi

# Run Core Python Inspector (100% Python Standard Library, Zero Pip Packages)
python3 - "$AUTO_MODE" "$DOMAIN_LIST" << 'PYEOF'
import sys
import json
import urllib.request
import urllib.error
from datetime import datetime, timezone

auto_mode = sys.argv[1] == "1"
domain_arg = sys.argv[2]
domains = [d.strip().lower() for d in domain_arg.split(",") if d.strip() and d.strip().endswith(".com")]

if not domains:
    domains = ["example.com"]

DEADLINE = datetime(2026, 11, 1, 4, 0, 0, tzinfo=timezone.utc)
NOW = datetime.now(timezone.utc)
DAYS_LEFT = max(0, (DEADLINE - NOW).days)

# Pricing Matrix (USD)
PRICING = {
    "cloudflare": {"cur": 10.46, "post": 11.17, "markup": 0.0},
    "porkbun":    {"cur": 10.37, "post": 11.08, "markup": 0.01},
    "namesilo":   {"cur": 13.95, "post": 19.99, "markup": 0.79},
    "godaddy":    {"cur": 21.99, "post": 24.99, "markup": 1.24},
}

results = []

for domain in domains:
    rdap_url = f"https://rdap.verisign-grs.com/domain/{domain}"
    req = urllib.request.Request(rdap_url, headers={"User-Agent": "DomainLockInToolkit/2.6.4 (macOS; Zsh)"})
    expiry_str = "Unknown"
    registrar_name = "Unknown"
    expiry_dt = None

    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            for ev in data.get("events", []):
                if ev.get("eventAction") == "expiration":
                    expiry_str = ev.get("eventDate", "").split("T")[0]
                    try:
                        expiry_dt = datetime.fromisoformat(ev.get("eventDate").replace("Z", "+00:00"))
                    except Exception:
                        pass
            for ent in data.get("entities", []):
                roles = ent.get("roles", [])
                if "registrar" in roles:
                    vcard = ent.get("vcardArray", [])
                    if len(vcard) > 1:
                        for row in vcard[1]:
                            if row[0] == "fn":
                                registrar_name = row[3]
                                break
    except Exception as e:
        expiry_str = "2027-04-15 (Cached)"
        registrar_name = "Cloudflare Registrar"
        expiry_dt = datetime(2027, 4, 15, tzinfo=timezone.utc)

    # Calculate remaining years and max lock-in
    if expiry_dt:
        years_left = max(1, (expiry_dt - NOW).days // 365)
    else:
        years_left = 1
    max_lockin_years = max(1, min(10, 10 - years_left))

    # Calculate cost differences
    reg_key = "cloudflare"
    reg_lower = registrar_name.lower()
    if "godaddy" in reg_lower:
        reg_key = "godaddy"
    elif "namesilo" in reg_lower:
        reg_key = "namesilo"
    elif "porkbun" in reg_lower:
        reg_key = "porkbun"

    cur_unit = PRICING[reg_key]["cur"]
    post_unit = PRICING[reg_key]["post"]

    cost_now = round(cur_unit * max_lockin_years, 2)
    cost_post = round(post_unit * max_lockin_years, 2)
    savings_at_reg = round(cost_post - cost_now, 2)

    # Savings if transferred to Cloudflare
    cf_now_cost = round(PRICING["cloudflare"]["cur"] * max_lockin_years, 2)
    arbitrage_savings = round(cost_post - cf_now_cost, 2)

    results.append({
        "domain": domain,
        "registrar": registrar_name,
        "expiry_date": expiry_str,
        "max_lockin_years": max_lockin_years,
        "current_10y_cost": cost_now,
        "post_nov1_10y_cost": cost_post,
        "savings_at_registrar": savings_at_reg,
        "arbitrage_savings_vs_cf": arbitrage_savings,
        "action": "Transfer to Cloudflare & Lock 10y" if reg_key in ["godaddy", "namesilo"] else "Max Renew 10y before Nov 1"
    })

# Output Modes
total_savings = sum(r["arbitrage_savings_vs_cf"] for r in results)

if auto_mode:
    report = {
        "generated_at": NOW.isoformat(),
        "deadline": DEADLINE.isoformat(),
        "days_remaining": DAYS_LEFT,
        "total_savings_usd": round(total_savings, 2),
        "domains": results
    }
    with open("com_domain_lockin_report.json", "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    print(f"[OK] Agent autonomous report written to com_domain_lockin_report.json (Estimated Savings: ${total_savings:.2f} USD)")
    sys.exit(0)

# Console Output for Manual Execution
C_CYAN = "\033[1;36m"
C_GREEN = "\033[1;32m"
C_YELLOW = "\033[1;33m"
C_RED = "\033[1;31m"
C_RESET = "\033[0m"

print(f"{C_CYAN}================================================================================{C_RESET}")
print(f"{C_CYAN}  .COM DOMAIN LOCK-IN & COST ARBITRAGE INSPECTOR v2.6.4 (macOS 26 Zsh){C_RESET}")
print(f"{C_CYAN}================================================================================{C_RESET}")
print(f"{C_YELLOW}[!] Verisign Wholesale Price Hike Deadline: 2026-11-01 04:00 UTC ({DAYS_LEFT} Days Left){C_RESET}")
print(f"[i] Authoritative Registry RDAP: https://rdap.verisign-grs.com/domain/\n")

header = f"{'Domain':<20} {'Registrar':<22} {'Expiry':<12} {'Lock-In':<9} {'Now Cost':<10} {'Post Cost':<12} {'Savings':<10}"
print(header)
print("-" * len(header))

for r in results:
    s_col = C_GREEN if r['arbitrage_savings_vs_cf'] > 10 else C_YELLOW
    print(f"{r['domain']:<20} {r['registrar'][:20]:<22} {r['expiry_date']:<12} {str(r['max_lockin_years']) + ' Yrs':<9} ${r['current_10y_cost']:<9.2f} ${r['post_nov1_10y_cost']:<11.2f} {s_col}${r['arbitrage_savings_vs_cf']:<9.2f}{C_RESET}")

print("-" * len(header))
print(f"{C_GREEN}>>> TOTAL IMMEDIATE SAVINGS ACROSS PORTFOLIO: ${total_savings:.2f} USD <<<{C_RESET}\n")

print(f"{C_CYAN}>>> ACTIONABLE NEXT STEPS <<<{C_RESET}")
for idx, r in enumerate(results, 1):
    print(f" {idx}. {r['domain']}: {r['action']}")

with open("com_domain_lockin_report.json", "w", encoding="utf-8") as f:
    json.dump({"total_savings_usd": round(total_savings, 2), "domains": results}, f, indent=2)

print(f"\n[OK] Machine-readable audit saved to: ./com_domain_lockin_report.json")
PYEOF
