#!/bin/zsh
set -euo pipefail
MODEL="${2:-glm-5.2}"
KEY="${1:-}"
if [[ -z "$KEY" ]]; then read -rs "KEY?请输入方舟 Coding Plan API Key: "; echo; fi
[[ -n "$KEY" ]] || { echo "API Key 不能为空" >&2; exit 1; }
PROFILE="$HOME/.zshrc"
cp "$PROFILE" "$PROFILE.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
python3 - "$PROFILE" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); s=p.read_text() if p.exists() else ''
s=re.sub(r'\n?# volcengine-coding-plan begin.*?# volcengine-coding-plan end\n?', '\n', s, flags=re.S)
p.write_text(s.rstrip()+"\n")
PY
cat >> "$PROFILE" <<EOT
# volcengine-coding-plan begin
export ANTHROPIC_BASE_URL="https://ark.cn-beijing.volces.com/api/coding"
export ANTHROPIC_AUTH_TOKEN="$KEY"
export ANTHROPIC_MODEL="$MODEL"
# volcengine-coding-plan end
EOT
chmod 600 "$PROFILE"
echo "配置完成。执行 source ~/.zshrc 后启动 Claude Code。"
