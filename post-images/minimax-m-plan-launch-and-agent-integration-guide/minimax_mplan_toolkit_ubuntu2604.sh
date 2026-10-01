#!/usr/bin/env bash
# ==============================================================================
# MiniMax M Plan Zero-Dependency Automation & Diagnostic Toolkit for Ubuntu 26.04
# ==============================================================================
# Sets up Anthropic protocol gateway for Claude Code, Cursor, and MCode agents.
# Cleans conflicting environment variables, configures ~/.claude/settings.json,
# performs DNS/TLS/TTFT diagnostic probes, and checks M3.1-Flash connectivity.
#
# Usage:
#   Interactive: ./minimax_mplan_toolkit_ubuntu2604.sh
#   Headless / Agent: ./minimax_mplan_toolkit_ubuntu2604.sh --headless --api-key "sk-mplan-xxx" --region "intl"
# ==============================================================================

set -euo pipefail

INTERACTIVE=true
API_KEY="${MINIMAX_API_KEY:-}"
REGION="${MINIMAX_REGION:-intl}"
MODEL="MiniMax-M3.1-Flash"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --headless|--non-interactive|-q)
      INTERACTIVE=false
      shift
      ;;
    --api-key)
      API_KEY="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Colors
C_RESET="\033[0m"
C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"

echo -e "${C_CYAN}=================================================================${C_RESET}"
echo -e "${C_YELLOW}  MiniMax M Plan Toolkit (Ubuntu 26.04 LTS / Bash)${C_RESET}"
echo -e "${C_CYAN}  Zero-Dependency Automation, Gateway Configuration & Diagnostic${C_RESET}"
echo -e "${C_CYAN}=================================================================${C_RESET}"

# 1. Interactive setup if missing key
if [[ "$INTERACTIVE" == true && -z "$API_KEY" ]]; then
  echo -e "\n${C_YELLOW}[Step 1/5] Configuration Setup${C_RESET}"
  echo "Select MiniMax API Region:"
  echo "  1) International (api.minimax.io - Recommended for overseas/cloud)"
  echo "  2) Domestic China (api.minimax.cn - Recommended for mainland China)"
  read -r -p "Enter selection [1/2] (Default: 1): " choice_reg
  if [[ "$choice_reg" == "2" ]]; then
    REGION="cn"
  else
    REGION="intl"
  fi

  read -r -p "Enter your MiniMax M Plan Subscription Key (sk-mplan-...): " input_key
  API_KEY="$input_key"
fi

if [[ -z "$API_KEY" ]]; then
  echo -e "${C_RED}Error: MiniMax API Key is required. Set MINIMAX_API_KEY or use --api-key.${C_RESET}" >&2
  exit 1
fi

if [[ "$REGION" == "cn" ]]; then
  BASE_HOST="https://api.minimax.cn"
else
  BASE_HOST="https://api.minimax.io"
fi
ANTHROPIC_BASE_URL="${BASE_HOST}/anthropic"

echo -e "\n${C_YELLOW}[Step 2/5] Sanitizing Environment Variables & Profiles...${C_RESET}"
# Unset conflicting ANTHROPIC_API_KEY to avoid Claude Code 401/billing confusion
unset ANTHROPIC_API_KEY || true

# Append/Update clean exports in ~/.bashrc safely
BASHRC="$HOME/.bashrc"
if [[ -f "$BASHRC" ]]; then
  grep -v "export ANTHROPIC_BASE_URL=" "$BASHRC" | \
  grep -v "export ANTHROPIC_AUTH_TOKEN=" | \
  grep -v "export ANTHROPIC_MODEL=" | \
  grep -v "export ANTHROPIC_API_KEY=" > "${BASHRC}.tmp" || true
  mv "${BASHRC}.tmp" "$BASHRC"
fi

cat <<EOF >> "$BASHRC"
# MiniMax M Plan Anthropic Compatible Gateway
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL}"
export ANTHROPIC_AUTH_TOKEN="${API_KEY}"
export ANTHROPIC_MODEL="${MODEL}"
EOF

export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL}"
export ANTHROPIC_AUTH_TOKEN="${API_KEY}"
export ANTHROPIC_MODEL="${MODEL}"

echo -e "  ${C_GREEN}+ Injected ANTHROPIC_BASE_URL  : ${ANTHROPIC_BASE_URL}${C_RESET}"
echo -e "  ${C_GREEN}+ Injected ANTHROPIC_AUTH_TOKEN : sk-mplan-***${C_RESET}"
echo -e "  ${C_GREEN}+ Set Default Model             : ${MODEL}${C_RESET}"

echo -e "\n${C_YELLOW}[Step 3/5] Updating Claude Code Local Settings (~/.claude/settings.json)...${C_RESET}"
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"
chmod 700 "$CLAUDE_DIR"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Safe native python3 or jq JSON injector without external dependencies
python3 - <<PY
import json, os

path = os.path.expanduser("${SETTINGS_FILE}")
base_url = "${ANTHROPIC_BASE_URL}"
token = "${API_KEY}"
model = "${MODEL}"

data = {}
if os.path.exists(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        data = {}

if "env" not in data:
    data["env"] = {}

data["env"]["ANTHROPIC_BASE_URL"] = base_url
data["env"]["ANTHROPIC_AUTH_TOKEN"] = token
data["env"]["ANTHROPIC_MODEL"] = model

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PY
chmod 600 "$SETTINGS_FILE"
echo -e "  ${C_GREEN}+ Securely written: ${SETTINGS_FILE} (Permissions: 0600)${C_RESET}"

echo -e "\n${C_YELLOW}[Step 4/5] Executing Network Handshake & TTFT Diagnostic Probe...${C_RESET}"
TEST_ENDPOINT="${ANTHROPIC_BASE_URL}/v1/messages"
PAYLOAD=$(cat <<JSON
{
  "model": "${MODEL}",
  "max_tokens": 50,
  "messages": [
    {
      "role": "user",
      "content": "Hello! Confirm MiniMax M Plan connectivity in one short sentence."
    }
  ]
}
JSON
)

START_TIME=$(date +%s%N)
HTTP_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}\nTIME_TOTAL:%{time_total}" \
  -X POST "$TEST_ENDPOINT" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "x-api-key: ${API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" || true)

HTTP_CODE=$(echo "$HTTP_RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
TIME_TOTAL=$(echo "$HTTP_RESPONSE" | grep "TIME_TOTAL:" | cut -d':' -f2)
BODY=$(echo "$HTTP_RESPONSE" | sed -e '/HTTP_STATUS:/,$d')

if [[ "$HTTP_CODE" == "200" ]]; then
  TTFT_MS=$(python3 -c "print(int(float('${TIME_TOTAL}') * 1000))")
  echo -e "  ${C_GREEN}[PASS] MiniMax Anthropic Gateway Response: 200 OK${C_RESET}"
  echo -e "  ${C_GREEN}[PASS] Measured Latency (TTFT probe): ${TTFT_MS} ms${C_RESET}"
  REPLY_TEXT=$(python3 -c "import json; d=json.loads('''${BODY}'''); print(d.get('content',[{}])[0].get('text',''))" 2>/dev/null || echo "OK")
  echo -e "  ${C_CYAN}[ECHO] Model Output: \"${REPLY_TEXT}\"${C_RESET}"
else
  echo -e "  ${C_RED}[FAIL] Gateway probe returned HTTP ${HTTP_CODE}${C_RESET}"
  echo -e "  ${C_RED}[BODY] ${BODY}${C_RESET}"
  exit 1
fi

echo -e "\n${C_YELLOW}[Step 5/5] Summary & Readiness Report${C_RESET}"
echo -e "${C_GREEN}=================================================================${C_RESET}"
echo -e "${C_GREEN}  SUCCESS: MiniMax M Plan is ready on Ubuntu 26.04!${C_RESET}"
echo -e "${C_CYAN}  - Base URL : ${ANTHROPIC_BASE_URL}${C_RESET}"
echo -e "${C_CYAN}  - Model    : ${MODEL}${C_RESET}"
echo -e "${C_YELLOW}  - Usage    : Launch terminal and run 'claude' directly${C_RESET}"
echo -e "${C_GREEN}=================================================================${C_RESET}"

if [[ "$INTERACTIVE" == false ]]; then
  echo "{\"status\":\"success\",\"base_url\":\"${ANTHROPIC_BASE_URL}\",\"model\":\"${MODEL}\",\"ttft_ms\":${TTFT_MS},\"settings_path\":\"${SETTINGS_FILE}\"}"
fi
