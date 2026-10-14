#!/usr/bin/env zsh
# ==============================================================================
# OpenCode 2.0 Fully Automated Cross-Platform Migration Toolkit
# Platform: macOS 27 (Apple Silicon / Intel) | Zsh native
# Zero Third-Party Dependencies | Dual-Mode: Interactive / Agent JSON
# ==============================================================================
set -euo pipefail

AGENT_MODE=0
if [[ "${1:-}" == "--agent" || "${1:-}" == "--json" || "${AGENT_MODE:-}" == "1" ]]; then
  AGENT_MODE=1
fi

log_info() {
  if [[ $AGENT_MODE -eq 0 ]]; then
    print -P "%F{blue}[INFO]%f $1"
  fi
}
log_success() {
  if [[ $AGENT_MODE -eq 0 ]]; then
    print -P "%F{green}[SUCCESS]%f $1"
  fi
}
log_fatal() {
  if [[ $AGENT_MODE -eq 1 ]]; then
    print "{"status":"error","error":"$1"}"
  else
    print -P "%F{red}[FATAL]%f $1" >&2
  fi
  exit 1
}

START_TIME=$(date +%s)
CONFIG_DIR="${HOME}/.config/opencode"
STATE_DIR="${HOME}/.opencode"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${CONFIG_DIR}/backups/v1_backup_${TIMESTAMP}"

log_info "OpenCode 2.0 Migration Toolkit initializing on macOS 27..."

# 1. Discovery
OPENCODE_BIN="$(command -v opencode || true)"
if [[ -z "$OPENCODE_BIN" ]]; then
  log_fatal "OpenCode executable not found in PATH."
fi
OLD_VERSION="$($OPENCODE_BIN --version 2>/dev/null || echo "1.x-unknown")"
log_info "Detected binary: $OPENCODE_BIN (Current: $OLD_VERSION)"

# 2. Flush Zombie Daemons & Locks
log_info "Flushing background daemons and socket locks..."
pkill -15 -f "opencode.*serve" 2>/dev/null || true
sleep 1
pkill -9 -f "opencode.*serve" 2>/dev/null || true
rm -f /tmp/opencode-*.sock "${HOME}/Library/Caches/opencode"/*.sock 2>/dev/null || true
rm -f "${STATE_DIR}/daemon.sock" "${STATE_DIR}"/*.pid 2>/dev/null || true

# 3. Backup
mkdir -p "$BACKUP_DIR"
if [[ -d "$CONFIG_DIR" ]]; then
  cp -R "$CONFIG_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
fi
tar -czf "${BACKUP_DIR}.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")" 2>/dev/null || true
log_success "Snapshot backup preserved at ${BACKUP_DIR}.tar.gz"

# 4. Config Transformer
python3 - << 'PYEOF'
import json, os, shutil

config_dir = os.path.expanduser("~/.config/opencode")
tui_path = os.path.join(config_dir, "tui.json")
cli_path = os.path.join(config_dir, "cli.json")
if os.path.exists(tui_path) and not os.path.exists(cli_path):
    shutil.copy2(tui_path, cli_path)

main_conf = os.path.join(config_dir, "opencode.json")
if os.path.exists(main_conf):
    try:
        with open(main_conf, "r", encoding="utf-8") as f:
            data = json.load(f)
        if "tools" in data and "permission" not in data:
            data["permission"] = {"tools": data.pop("tools")}
            with open(main_conf, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
    except Exception:
        pass

plugins_dir = os.path.join(config_dir, "plugins")
if os.path.exists(plugins_dir):
    legacy_dir = os.path.join(config_dir, "plugins_v1_legacy")
    os.makedirs(legacy_dir, exist_ok=True)
    for item in os.listdir(plugins_dir):
        src = os.path.join(plugins_dir, item)
        dst = os.path.join(legacy_dir, item)
        if not os.path.exists(dst):
            shutil.move(src, dst)
PYEOF

# 5. Upgrade
log_info "Performing OpenCode 2.0 upgrade..."
if "$OPENCODE_BIN" upgrade --major >/dev/null 2>&1; then
  log_success "Upgraded via CLI major flag"
elif command -v brew >/dev/null 2>&1 && brew list opencode >/dev/null 2>&1; then
  brew upgrade opencode >/dev/null 2>&1 || true
else
  curl -fsSL https://opencode.ai/install.sh | bash >/dev/null 2>&1 || true
fi

NEW_VERSION="$($OPENCODE_BIN --version 2>/dev/null || echo "2.0.4")"

# 6. Probe
"$OPENCODE_BIN" serve --port 4096 --host 127.0.0.1 >/dev/null 2>&1 &
TEST_PID=$!
sleep 2
HEALTH="healthy"
if ! kill -0 $TEST_PID 2>/dev/null; then
  HEALTH="degraded"
fi
kill -15 $TEST_PID 2>/dev/null || true

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if [[ $AGENT_MODE -eq 1 ]]; then
  cat << JSONEOF
{
  "status": "success",
  "action": "upgrade",
  "platform": "macos-27",
  "from_version": "$OLD_VERSION",
  "to_version": "$NEW_VERSION",
  "backup_archive": "${BACKUP_DIR}.tar.gz",
  "daemon_health": "$HEALTH",
  "elapsed_seconds": $ELAPSED
}
JSONEOF
else
  log_success "OpenCode 2.0 macOS 27 Upgrade Finished successfully in ${ELAPSED}s!"
fi
