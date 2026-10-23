#!/usr/bin/env zsh
# ==============================================================================
# Kimi K3.1 Pro & Highspeed One-Click Migration, Probe & Agent Config Script
# Target OS : macOS 27 (Zsh 5.9+, Apple Silicon & Intel, zero dependencies)
# Features  :
#   1. Static code audit for K2 -> K3.1 Pro breaking API changes (--scan-dir)
#   2. Official endpoint TLS latency check & live API probe (--verify-api)
#   3. Atomic backup & setup for Claude Code & Codex CLI (--apply-claude / --apply-codex)
#   4. Dual execution modes: Human-readable report & Agent JSON (--agent-mode)
# ==============================================================================
emulate -L zsh
set -euo pipefail

MODEL_ID="kimi-k3.1-pro"
REGION="cn"
SCAN_DIR=""
VERIFY_API=0
APPLY_CLAUDE=0
APPLY_CODEX=0
CLEAN_MODE=0
AGENT_MODE=0
API_KEY="${MOONSHOT_API_KEY:-}"

usage() {
  cat <<'EOF'
Usage: zsh kimi-k31-pro-macos27.zsh [OPTIONS]

Options:
  --model <id>         Model ID: kimi-k3.1-pro (default) or kimi-k3.1-pro-highspeed
  --region <cn|global> Endpoint region: cn (api.moonshot.cn) or global (api.moonshot.ai)
  --api-key <key>      Moonshot API Key (or export MOONSHOT_API_KEY)
  --scan-dir <dir>     Scan project directory for K2->K3.1 breaking API patterns
  --verify-api         Probe official endpoints and test K3.1 Pro API response
  --apply-claude       Configure ~/.claude/settings.json (with automatic backup)
  --apply-codex        Configure ~/.codex/config.toml (with automatic backup)
  --clean              Restore Claude Code / Codex configs from latest backup
  --agent-mode         Output strict single-line JSON for AI Agent automation
  -h, --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL_ID="${2:-}"; shift 2 ;;
    --region) REGION="${2:-}"; shift 2 ;;
    --api-key) API_KEY="${2:-}"; shift 2 ;;
    --scan-dir) SCAN_DIR="${2:-}"; shift 2 ;;
    --verify-api) VERIFY_API=1; shift ;;
    --apply-claude) APPLY_CLAUDE=1; shift ;;
    --apply-codex) APPLY_CODEX=1; shift ;;
    --clean) CLEAN_MODE=1; shift ;;
    --agent-mode) AGENT_MODE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) print -u2 "Unknown option: $1"; usage >&2; exit 2 ;;
  esac
done

if [[ "$MODEL_ID" != "kimi-k3.1-pro" && "$MODEL_ID" != "kimi-k3.1-pro-highspeed" ]]; then
  print -u2 "Error: --model must be kimi-k3.1-pro or kimi-k3.1-pro-highspeed"
  exit 2
fi

if [[ "$REGION" == "global" ]]; then
  BASE_HOST="api.moonshot.ai"
else
  REGION="cn"
  BASE_HOST="api.moonshot.cn"
fi

OPENAI_BASE="https://${BASE_HOST}/v1"
ANTHROPIC_BASE="https://${BASE_HOST}/anthropic"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

mask_key() {
  local k="${1:-}"
  if [[ -z "$k" ]]; then
    printf "not-set"
  elif [[ ${#k} -le 10 ]]; then
    printf "***masked***"
  else
    printf "%s...%s" "${k[1,6]}" "${k[-4,-1]}"
  fi
}

log_info() {
  if [[ "$AGENT_MODE" -eq 0 ]]; then
    printf "[INFO] %s\n" "$1"
  fi
}

SCAN_K2_HITS=0
SCAN_TEMP_HITS=0
SCAN_THINKING_HITS=0
SCAN_IMAGE_URL_HITS=0

run_scan() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    log_info "Scan directory not found: $dir"
    return 0
  fi
  log_info "Scanning directory for K2 -> K3.1 Pro migration risks: $dir"
  SCAN_K2_HITS="$( (grep -RInE --exclude-dir={.git,node_modules,dist,build,public,.venv,venv} 'kimi-k2(\.[0-9]+|-thinking|-turbo)?|moonshot-v1-(8k|32k|128k)' "$dir" 2>/dev/null || true) | wc -l | tr -d ' ' )"
  SCAN_TEMP_HITS="$( (grep -RInE --exclude-dir={.git,node_modules,dist,build,public,.venv,venv} '"temperature"[[:space:]]*:[[:space:]]*0\.[0-9]+' "$dir" 2>/dev/null || true) | wc -l | tr -d ' ' )"
  SCAN_THINKING_HITS="$( (grep -RInE --exclude-dir={.git,node_modules,dist,build,public,.venv,venv} '"thinking"[[:space:]]*:[[:space:]]*\{' "$dir" 2>/dev/null || true) | wc -l | tr -d ' ' )"
  SCAN_IMAGE_URL_HITS="$( (grep -RInE --exclude-dir={.git,node_modules,dist,build,public,.venv,venv} '"image_url"[[:space:]]*:[[:space:]]*\{[^}]*https?://' "$dir" 2>/dev/null || true) | wc -l | tr -d ' ' )"

  if [[ "$AGENT_MODE" -eq 0 ]]; then
    printf "  - Legacy K2 / moonshot-v1 model IDs : %s\n" "$SCAN_K2_HITS"
    printf "  - Locked temperature != 1.0 hits    : %s\n" "$SCAN_TEMP_HITS"
    printf "  - Deprecated thinking dict hits     : %s\n" "$SCAN_THINKING_HITS"
    printf "  - Remote HTTP image_url hits        : %s\n" "$SCAN_IMAGE_URL_HITS"
  fi
}

PROBE_HTTP_CODE="skipped"
PROBE_LATENCY_MS="0"
API_TEST_STATUS="skipped"

run_verify_api() {
  log_info "Probing TLS connectivity to ${OPENAI_BASE}/models ..."
  local out
  out="$(curl -sS -o /dev/null -w "%{http_code} %{time_total}" --connect-timeout 8 "${OPENAI_BASE}/models" 2>/dev/null || echo "000 0")"
  PROBE_HTTP_CODE="$(echo "$out" | awk '{print $1}')"
  local sec
  sec="$(echo "$out" | awk '{print $2}')"
  PROBE_LATENCY_MS="$(awk -v s="$sec" 'BEGIN { printf "%d", s * 1000 }')"
  log_info "Endpoint ${BASE_HOST} responded with HTTP ${PROBE_HTTP_CODE} (${PROBE_LATENCY_MS} ms)"

  if [[ -n "$API_KEY" ]]; then
    log_info "Testing live chat completion on ${MODEL_ID} (reasoning_effort=low) ..."
    local resp
    resp="$(curl -sS --connect-timeout 15 "${OPENAI_BASE}/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${API_KEY}" \
      -d "{\"model\":\"${MODEL_ID}\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with OK\"}],\"reasoning_effort\":\"low\",\"max_tokens\":32}" 2>/dev/null || true)"
    if echo "$resp" | grep -q '"choices"'; then
      API_TEST_STATUS="ok"
      log_info "Live API test succeeded for ${MODEL_ID}."
    else
      API_TEST_STATUS="error"
      log_info "Live API test failed or returned error payload."
    fi
  fi
}

CLAUDE_STATUS="unchanged"
CODEX_STATUS="unchanged"

apply_claude_config() {
  local claude_dir="${HOME}/.claude"
  local settings="${claude_dir}/settings.json"
  mkdir -p "$claude_dir"
  if [[ -f "$settings" ]]; then
    cp "$settings" "${settings}.bak.${TIMESTAMP}"
    log_info "Backed up existing Claude Code config to ${settings}.bak.${TIMESTAMP}"
  fi
  local key_val="${API_KEY:-YOUR_MOONSHOT_API_KEY}"
  cat > "$settings" <<EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "${ANTHROPIC_BASE}",
    "ANTHROPIC_AUTH_TOKEN": "${key_val}",
    "ANTHROPIC_MODEL": "${MODEL_ID}",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "${MODEL_ID}",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "${MODEL_ID}",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "${MODEL_ID}",
    "CLAUDE_CODE_SUBAGENT_MODEL": "${MODEL_ID}",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "1000000",
    "ENABLE_TOOL_SEARCH": "false"
  }
}
EOF
  CLAUDE_STATUS="configured"
  log_info "Updated ${settings} for ${MODEL_ID} (1M context window enabled)."
}

apply_codex_config() {
  local codex_dir="${HOME}/.codex"
  local cfg="${codex_dir}/config.toml"
  mkdir -p "$codex_dir"
  if [[ -f "$cfg" ]]; then
    cp "$cfg" "${cfg}.bak.${TIMESTAMP}"
    log_info "Backed up existing Codex config to ${cfg}.bak.${TIMESTAMP}"
  fi
  cat > "$cfg" <<EOF
# KIMI-K31-PRO-BEGIN
model_provider = "kimi"
model = "${MODEL_ID}"
model_context_window = 1048576
model_auto_compact_token_limit = 900000

[model_providers.kimi]
name = "Kimi K3.1 Pro (${REGION})"
base_url = "${OPENAI_BASE}"
env_key = "MOONSHOT_API_KEY"
wire_api = "responses"
# KIMI-K31-PRO-END
EOF
  CODEX_STATUS="configured"
  log_info "Updated ${cfg} for ${MODEL_ID} (wire_api=responses, 1M context)."
}

run_clean() {
  local latest_claude
  latest_claude="$(ls -1t "${HOME}/.claude/settings.json.bak."* 2>/dev/null | head -n 1 || true)"
  if [[ -n "$latest_claude" ]]; then
    cp "$latest_claude" "${HOME}/.claude/settings.json"
    CLAUDE_STATUS="restored_backup"
    log_info "Restored ~/.claude/settings.json from ${latest_claude}"
  fi
  local latest_codex
  latest_codex="$(ls -1t "${HOME}/.codex/config.toml.bak."* 2>/dev/null | head -n 1 || true)"
  if [[ -n "$latest_codex" ]]; then
    cp "$latest_codex" "${HOME}/.codex/config.toml"
    CODEX_STATUS="restored_backup"
    log_info "Restored ~/.codex/config.toml from ${latest_codex}"
  fi
}

if [[ "$CLEAN_MODE" -eq 1 ]]; then
  run_clean
else
  [[ -n "$SCAN_DIR" ]] && run_scan "$SCAN_DIR"
  [[ "$VERIFY_API" -eq 1 ]] && run_verify_api
  [[ "$APPLY_CLAUDE" -eq 1 ]] && apply_claude_config
  [[ "$APPLY_CODEX" -eq 1 ]] && apply_codex_config
fi

if [[ "$AGENT_MODE" -eq 1 ]]; then
  printf '{"status":"ok","os":"macos-27","model":"%s","region":"%s","endpoint":"%s","api_key_masked":"%s","scan":{"k2_model_hits":%s,"locked_temperature_hits":%s,"deprecated_thinking_hits":%s,"http_image_url_hits":%s},"probe":{"http_code":"%s","latency_ms":%s,"live_api_status":"%s"},"config":{"claude_code":"%s","codex_cli":"%s"}}\n' \
    "$MODEL_ID" "$REGION" "$BASE_HOST" "$(mask_key "$API_KEY")" \
    "$SCAN_K2_HITS" "$SCAN_TEMP_HITS" "$SCAN_THINKING_HITS" "$SCAN_IMAGE_URL_HITS" \
    "$PROBE_HTTP_CODE" "$PROBE_LATENCY_MS" "$API_TEST_STATUS" \
    "$CLAUDE_STATUS" "$CODEX_STATUS"
else
  log_info "Done. Model=${MODEL_ID}, Region=${REGION} (${BASE_HOST}), Key=$(mask_key "$API_KEY")"
fi
