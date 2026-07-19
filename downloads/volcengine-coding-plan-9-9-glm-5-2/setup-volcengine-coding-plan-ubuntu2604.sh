#!/usr/bin/env bash
set -euo pipefail
MODEL="${2:-glm-5.2}"
KEY="${1:-}"
if [[ -z "$KEY" ]]; then read -rsp "请输入方舟 Coding Plan API Key: " KEY; echo; fi
[[ -n "$KEY" ]] || { echo "API Key 不能为空" >&2; exit 1; }
PROFILE="$HOME/.profile"
cp "$PROFILE" "$PROFILE.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
sed -i '/# volcengine-coding-plan begin/,/# volcengine-coding-plan end/d' "$PROFILE"
cat >> "$PROFILE" <<EOT
# volcengine-coding-plan begin
export ANTHROPIC_BASE_URL="https://ark.cn-beijing.volces.com/api/coding"
export ANTHROPIC_AUTH_TOKEN="$KEY"
export ANTHROPIC_MODEL="$MODEL"
# volcengine-coding-plan end
EOT
chmod 600 "$PROFILE"
echo "配置完成。执行 source ~/.profile 后启动 Claude Code。"
