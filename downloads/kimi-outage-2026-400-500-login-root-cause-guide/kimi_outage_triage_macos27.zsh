#!/usr/bin/env zsh
# ==============================================================================
# Kimi / Moonshot Outage Triage & Recovery Toolkit (macOS 27)
# ------------------------------------------------------------------------------
# Zero-dependency diagnostic & safe self-healing script for macOS 27 (Zsh 5.9+).
# Directly probes Moonshot's own public endpoints (no third-party status APIs),
# audits local Kimi Code / Claude / Codex / proxy state for 400/401/403/500 loops,
# and supports both Human Interactive Dashboard and AI Agent JSON modes.
# ==============================================================================
emulate -L zsh
set -euo pipefail

AUTO_MODE=0
JSON_MODE=0
FIX_MODE=0
CLEAN_MODE=0
REGION="all"
API_KEY="${KIMI_API_KEY:-${MOONSHOT_API_KEY:-}}"

usage() {
  cat <<'EOF'
Usage: zsh kimi_outage_triage_macos27.zsh [OPTIONS]

Options:
  --auto, -a           Non-interactive execution mode
  --json, -j           Output strict single-line JSON for AI Agents
  --region <cn|intl|all>  Endpoint scope to probe (default: all)
  --api-key <key>      Optional API key (or set KIMI_API_KEY / MOONSHOT_API_KEY)
  --fix                Safe local remediation (flush DNS cache, backup & isolate broken session locks)
  --clean              Restore local config files backed up by --fix
  -h, --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto|-a) AUTO_MODE=1; shift ;;
    --json|-j) JSON_MODE=1; AUTO_MODE=1; shift ;;
    --region) REGION="${2:-all}"; shift 2 ;;
    --api-key) API_KEY="${2:-}"; shift 2 ;;
    --fix) FIX_MODE=1; shift ;;
    --clean) CLEAN_MODE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) print -u2 "Unknown option: $1"; usage >&2; exit 2 ;;
  esac
done

if [[ $JSON_MODE -eq 1 ]]; then
  GREEN=""; YELLOW=""; RED=""; BLUE=""; CYAN=""; BOLD=""; RESET=""
else
  GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; BLUE="\033[34m"; CYAN="\033[36m"; BOLD="\033[1m"; RESET="\033[0m"
fi

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OS_INFO="macOS 27 (Darwin $(uname -r))"
BACKUP_ROOT="$HOME/.kimi-triage-backups"

mask_key() {
  local k="${1:-}"
  if [[ -z "$k" ]]; then printf "not-set"
  elif [[ ${#k} -le 10 ]]; then printf "***masked***"
  else printf "%s...%s" "${k:0:6}" "${k: -4}"
  fi
}

if [[ $CLEAN_MODE -eq 1 ]]; then
  RESTORED=0
  if [[ -d "$BACKUP_ROOT/latest" ]]; then
    for bak in "$BACKUP_ROOT/latest"/*(N); do
      local bname="${bak:t}"
      case "$bname" in
        kimi-config.toml) mkdir -p "$HOME/.kimi"; cp -f "$bak" "$HOME/.kimi/config.toml"; ((RESTORED++)) ;;
        claude-settings.json) mkdir -p "$HOME/.claude"; cp -f "$bak" "$HOME/.claude/settings.json"; ((RESTORED++)) ;;
        codex-config.toml) mkdir -p "$HOME/.codex"; cp -f "$bak" "$HOME/.codex/config.toml"; ((RESTORED++)) ;;
      esac
    done
  fi
  if [[ $JSON_MODE -eq 1 ]]; then
    printf '{"status":"ok","action":"clean","restored_files":%d}\n' "$RESTORED"
  else
    print -P "${GREEN}[OK]${RESET} Restored $RESTORED backed-up config file(s) from $BACKUP_ROOT/latest"
  fi
  exit 0
fi

# 1. Probe Moonshot official status API directly (zero third-party services)
STATUS_JSON="$(curl -sS --max-time 8 "https://status.moonshot.cn/api/v2/summary.json" 2>/dev/null || true)"
INCIDENTS_JSON="$(curl -sS --max-time 8 "https://status.moonshot.cn/api/v2/incidents.json" 2>/dev/null || true)"

eval_status="$(python3 - "$STATUS_JSON" "$INCIDENTS_JSON" <<'PY'
import json, sys, shlex
s_raw, i_raw = sys.argv[1], sys.argv[2]
indicator = "unreachable"
desc = "Unable to fetch status.moonshot.cn"
degraded = []
latest_inc = ""
k3_uptime = "unknown"
if s_raw:
    try:
        d = json.loads(s_raw)
        indicator = d.get("status", {}).get("indicator", "unknown")
        desc = d.get("status", {}).get("description", "unknown")
        for c in d.get("components", []):
            if c.get("status") != "operational":
                degraded.append(f"{c.get('name')}:{c.get('status')}")
    except Exception:
        pass
if i_raw:
    try:
        inc = json.loads(i_raw).get("incidents", [])
        if inc:
            top = inc[0]
            latest_inc = f"{top.get('created_at','')} | {top.get('name','')} | {top.get('status','')}"
    except Exception:
        pass
print(f"UPSTREAM_INDICATOR={shlex.quote(indicator)}")
print(f"UPSTREAM_DESC={shlex.quote(desc)}")
print(f"DEGRADED_LIST={shlex.quote(','.join(degraded) if degraded else 'none')}")
print(f"LATEST_INCIDENT={shlex.quote(latest_inc)}")
PY
)"
eval "$eval_status"

# 2. Probe live Kimi web, auth, status split-brain, and API planes
probe_endpoint() {
  local url="$1" method="$2" ua="$3" body="$4" auth_hdr="$5"
  local tmp_body
  tmp_body="$(mktemp)"
  local -a hdrs=(-H "Content-Type: application/json")
  [[ -n "$auth_hdr" ]] && hdrs+=(-H "$auth_hdr")
  local meta
  if [[ "$method" == "GET" ]]; then
    meta="$(curl -sS -m 8 -A "$ua" -o "$tmp_body" -w "%{http_code}|%{time_total}" "$url" 2>/dev/null || true)"
  else
    meta="$(curl -sS -m 8 -A "$ua" -X POST "${hdrs[@]}" -d "$body" -o "$tmp_body" -w "%{http_code}|%{time_total}" "$url" 2>/dev/null || true)"
  fi
  [[ -z "$meta" ]] && meta="000|0"
  local code="${meta%%|*}"
  local secs="${meta##*|}"
  local ms
  ms="$(python3 -c "print(int(float('${secs:-0}')*1000))" 2>/dev/null || echo 0)"
  local snippet
  snippet="$(head -c 180 "$tmp_body" 2>/dev/null | tr '\n\r\t' ' ' | sed 's/"/\\"/g')"
  rm -f "$tmp_body"
  printf "%s|%s|%s" "$code" "$ms" "$snippet"
}

WEB_RES="$(probe_endpoint "https://www.kimi.com/" "GET" "Mozilla/5.0" "" "")"
AUTH_QUOTA_RES="$(probe_endpoint "https://www.kimi.com/apiv2/kimi.gateway.storage.v1.StorageService/GetUserStorageQuota" "POST" "Mozilla/5.0" '{}' "")"
CN_API_RES="$(probe_endpoint "https://api.moonshot.cn/v1/chat/completions" "POST" "kimi-triage/1.0" '{"model":"kimi-k3.1-pro","messages":[{"role":"user","content":"ping"}]}' "${API_KEY:+Authorization: Bearer $API_KEY}")"
CN_CODE_RES="$(probe_endpoint "https://api.kimi.com/coding/v1/messages" "POST" "kimi-triage/1.0" '{"model":"kimi-for-coding","max_tokens":4,"messages":[{"role":"user","content":"ping"}]}' "${API_KEY:+x-api-key: $API_KEY}")"
INTL_CODE_RES="$(probe_endpoint "https://api.kimi.ai/coding/v1/messages" "POST" "kimi-triage/1.0" '{"model":"kimi-for-coding","max_tokens":4,"messages":[{"role":"user","content":"ping"}]}' "${API_KEY:+x-api-key: $API_KEY}")"
STATUS_ALT_CODE="$(curl -sS -m 5 -o /dev/null -w "%{http_code}" "https://status.kimi.com/" 2>/dev/null || true)"
[[ -z "$STATUS_ALT_CODE" ]] && STATUS_ALT_CODE="000"

WEB_CODE="${WEB_RES%%|*}"; rest="${WEB_RES#*|}"; WEB_MS="${rest%%|*}"
AUTH_CODE="${AUTH_QUOTA_RES%%|*}"
CN_API_CODE="${CN_API_RES%%|*}"; rest="${CN_API_RES#*|}"; CN_API_MS="${rest%%|*}"
CN_CODE_CODE="${CN_CODE_RES%%|*}"; rest="${CN_CODE_RES#*|}"; CN_CODE_MS="${rest%%|*}"
INTL_CODE_CODE="${INTL_CODE_RES%%|*}"; rest="${INTL_CODE_RES#*|}"; INTL_CODE_MS="${rest%%|*}"

# 3. Audit local proxy & config traps (masking any secrets/IPs)
PROXY_SET=0
[[ -n "${http_proxy:-}${https_proxy:-}${HTTP_PROXY:-}${HTTPS_PROXY:-}${all_proxy:-}${ALL_PROXY:-}" ]] && PROXY_SET=1

K2_HITS=0
TEMP_HITS=0
BASE_MISMATCH=0
SESSION_WARN=0

for cfg in "$HOME/.kimi/config.toml" "$HOME/.claude/settings.json" "$HOME/.codex/config.toml"; do
  if [[ -f "$cfg" ]]; then
    if grep -qE "kimi-k2|moonshot-v1-" "$cfg" 2>/dev/null; then ((K2_HITS++)) || true; fi
    if grep -qE '"temperature"[[:space:]]*:[[:space:]]*0\.[0-9]+|temperature[[:space:]]*=[[:space:]]*0\.[0-9]+' "$cfg" 2>/dev/null; then ((TEMP_HITS++)) || true; fi
    if grep -q "api.kimi.ai" "$cfg" 2>/dev/null && grep -q "api.moonshot.cn" "$cfg" 2>/dev/null; then ((BASE_MISMATCH++)) || true; fi
  fi
done

if [[ -d "$HOME/.kimi/sessions" ]]; then
  SESSION_WARN="$(find "$HOME/.kimi/sessions" -type f -name "*.jsonl" -size 0c 2>/dev/null | wc -l | tr -d ' ')"
fi

# 4. Determine root assessment & safe remediation actions
DIAGNOSIS="HEALTHY"
if [[ "$UPSTREAM_INDICATOR" != "none" && "$UPSTREAM_INDICATOR" != "operational" && "$UPSTREAM_INDICATOR" != "unreachable" ]]; then
  DIAGNOSIS="UPSTREAM_PARTIAL_OUTAGE"
fi
if [[ "$CN_API_CODE" =~ ^5 || "$CN_CODE_CODE" =~ ^5 ]]; then
  DIAGNOSIS="UPSTREAM_5XX_DEGRADED"
elif [[ "$INTL_CODE_CODE" == "403" ]]; then
  DIAGNOSIS="WAF_OR_UA_BLOCK_1010"
elif [[ "$K2_HITS" -gt 0 || "$TEMP_HITS" -gt 0 || "$BASE_MISMATCH" -gt 0 ]]; then
  DIAGNOSIS="LOCAL_CLIENT_400_RISK"
fi

ACTIONS_TAKEN=()
if [[ $FIX_MODE -eq 1 ]]; then
  mkdir -p "$BACKUP_ROOT/latest"
  for pair in "kimi-config.toml:$HOME/.kimi/config.toml" "claude-settings.json:$HOME/.claude/settings.json" "codex-config.toml:$HOME/.codex/config.toml"; do
    local bname="${pair%%:*}"
    local src="${pair#*:}"
    if [[ -f "$src" ]]; then
      cp -f "$src" "$BACKUP_ROOT/latest/$bname"
    fi
  done
  dscacheutil -flushcache 2>/dev/null || true
  ACTIONS_TAKEN+=("flushed_macos_dns_cache")
  if [[ -d "$HOME/.kimi/sessions" && "$SESSION_WARN" -gt 0 ]]; then
    mkdir -p "$BACKUP_ROOT/empty-sessions"
    find "$HOME/.kimi/sessions" -type f -name "*.jsonl" -size 0c -exec mv {} "$BACKUP_ROOT/empty-sessions/" \; 2>/dev/null || true
    ACTIONS_TAKEN+=("quarantined_zero_byte_sessions")
  fi
fi

# 5. Output
if [[ $JSON_MODE -eq 1 ]]; then
  python3 - "$TIMESTAMP" "$OS_INFO" "$UPSTREAM_INDICATOR" "$UPSTREAM_DESC" "$DEGRADED_LIST" "$LATEST_INCIDENT" \
    "$WEB_CODE" "$WEB_MS" "$AUTH_CODE" "$CN_API_CODE" "$CN_API_MS" "$CN_CODE_CODE" "$CN_CODE_MS" \
    "$INTL_CODE_CODE" "$INTL_CODE_MS" "$STATUS_ALT_CODE" "$PROXY_SET" "$K2_HITS" "$TEMP_HITS" \
    "$BASE_MISMATCH" "$SESSION_WARN" "$DIAGNOSIS" "$(mask_key "$API_KEY")" "${ACTIONS_TAKEN[*]:-none}" <<'PY'
import json, sys
a = sys.argv[1:]
recs = []
if a[2] not in ("none", "operational"):
    recs.append("UPSTREAM_DEGRADED: Monitor https://status.moonshot.cn and avoid rapid blind retries.")
if a[12].startswith("5") or a[9].startswith("5"):
    recs.append("RETRY_WITH_BACKOFF: Apply exponential backoff (2s, 4s, 8s) and rotate corrupted session.")
if a[13] == "403":
    recs.append("WAF_1010: Do not send generic scripting User-Agent to api.kimi.ai; check proxy/UA headers.")
if int(a[17]) > 0 or int(a[18]) > 0 or int(a[19]) > 0:
    recs.append("FIX_CLIENT_400: Remove deprecated K2 IDs, non-0.6/1.0 temperature overrides, or CN/Intl key mixups.")
if not recs:
    recs.append("HEALTHY_OR_UNAUTHENTICATED_OK: Set KIMI_API_KEY and re-run if testing authenticated chat.")
out = {
    "timestamp": a[0],
    "os": a[1],
    "api_key_masked": a[22],
    "upstream_status": {
        "indicator": a[2],
        "description": a[3],
        "degraded_components": [] if a[4] == "none" else a[4].split(","),
        "latest_incident": a[5],
        "status_kimi_com_http": a[15]
    },
    "endpoint_probes": {
        "www_kimi_com": {"http": a[6], "latency_ms": int(a[7])},
        "kimi_auth_probe": {"http": a[8]},
        "api_moonshot_cn": {"http": a[9], "latency_ms": int(a[10])},
        "api_kimi_com_coding": {"http": a[11], "latency_ms": int(a[12])},
        "api_kimi_ai_coding": {"http": a[13], "latency_ms": int(a[14])}
    },
    "local_audit": {
        "proxy_env_active": a[16] == "1",
        "legacy_k2_config_hits": int(a[17]),
        "temperature_override_hits": int(a[18]),
        "cn_intl_endpoint_mix": int(a[19]),
        "zero_byte_session_files": int(a[20])
    },
    "diagnosis": a[21],
    "actions_taken": [] if a[23] == "none" else a[23].split(),
    "recommended_actions": recs
}
print(json.dumps(out, ensure_ascii=False))
PY
  exit 0
fi

echo -e "${BOLD}${BLUE}======================================================================${RESET}"
echo -e "${BOLD}${BLUE}   Kimi / Moonshot 400·500·登录异常 一键分层排障探针 (macOS 27)       ${RESET}"
echo -e "${BOLD}${BLUE}======================================================================${RESET}"
echo -e " 检查时间 : ${TIMESTAMP}"
echo -e " 运行环境 : ${OS_INFO}"
echo -e " API Key  : $(mask_key "$API_KEY")"
echo ""
echo -e "${BOLD}[1/4] 官方状态源直连核验 (status.moonshot.cn vs status.kimi.com)${RESET}"
echo -e "  - status.moonshot.cn 指标 : ${YELLOW}${UPSTREAM_INDICATOR} (${UPSTREAM_DESC})${RESET}"
echo -e "  - 仍处于降级/异常的组件   : ${RED}${DEGRADED_LIST}${RESET}"
echo -e "  - 最近官方故障通报        : ${LATEST_INCIDENT:-无}"
echo -e "  - status.kimi.com 探测    : HTTP ${STATUS_ALT_CODE} (000/502 表示域名不可达/状态裂脑)"
echo ""
echo -e "${BOLD}[2/4] 四端网关实时连通与 HTTP 状态码探测${RESET}"
echo -e "  - 网页壳 www.kimi.com             : HTTP ${WEB_CODE} (${WEB_MS} ms)"
echo -e "  - 鉴权网关 GetUserStorageQuota    : HTTP ${AUTH_CODE} (未登录预期 401)"
echo -e "  - 国内开放平台 api.moonshot.cn    : HTTP ${CN_API_CODE} (${CN_API_MS} ms)"
echo -e "  - 国内 Kimi Code api.kimi.com     : HTTP ${CN_CODE_CODE} (${CN_CODE_MS} ms)"
echo -e "  - 国际 Kimi Code api.kimi.ai      : HTTP ${INTL_CODE_CODE} (${INTL_CODE_MS} ms)"
echo ""
echo -e "${BOLD}[3/4] 本地客户端 400 陷阱与网络代理自检${RESET}"
echo -e "  - 系统环境变量代理已启用          : $([[ $PROXY_SET -eq 1 ]] && echo "${YELLOW}是 (留意 auth/502 干扰)${RESET}" || echo "${GREEN}否${RESET}")"
echo -e "  - 遗留 K2/moonshot-v1 模型引用    : ${K2_HITS} 处"
echo -e "  - 采样 temperature 锁定风险       : ${TEMP_HITS} 处"
echo -e "  - 国内/国际 Base URL 混用风险     : ${BASE_MISMATCH} 处"
echo -e "  - 损坏/空会话 .jsonl 残留         : ${SESSION_WARN} 个"
echo ""
echo -e "${BOLD}[4/4] 综合结论与下一步建议${RESET}"
echo -e "  - 综合研判 : ${BOLD}${CYAN}${DIAGNOSIS}${RESET}"
if [[ $FIX_MODE -eq 1 ]]; then
  echo -e "  - 已执行自愈动作 : ${GREEN}${ACTIONS_TAKEN[*]:-无}${RESET}"
elif [[ $AUTO_MODE -eq 0 ]]; then
  echo -e "  - 如需自动刷新 DNS 并隔离损坏的零字节会话文件，可追加 ${BOLD}--fix${RESET} 参数运行；支持 ${BOLD}--clean${RESET} 回滚。"
fi
