#!/usr/bin/env zsh
# ==============================================================================
# OpenAI Dots Open-Source Implementations Toolkit for macOS 26 (Apple Silicon / Intel)
# ==============================================================================
# Native Zsh script for automated deployment, preflight check, and management
# of open-source dots runtimes (feder-cr/dots, Anil-matcha/open-dots).
#
# Supported Execution Modes:
#   1. Interactive Mode: zsh openai_dots_oss_toolkit_macos26.zsh
#   2. Agent / Non-Interactive Mode:
#      zsh openai_dots_oss_toolkit_macos26.zsh --agent-mode --port 8765 --seed 894129 --headless
#
# Zero external proprietary dependencies. Pure native macOS shell.
# ==============================================================================

set -eo pipefail

AGENT_MODE=false
BIND_HOST="127.0.0.1"
BIND_PORT="8765"
SEED="894129"
HEADLESS=true
MODEL_ENDPOINT="local-ollama"
OPENROUTER_KEY="${OPENROUTER_KEY:-}"
PROFILE_DIR="${HOME}/.local/share/dots/profiles/default"
LOG_DIR="${HOME}/.local/share/dots/logs"

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-mode) AGENT_MODE=true; shift ;;
    --host) BIND_HOST="$2"; shift 2 ;;
    --port) BIND_PORT="$2"; shift 2 ;;
    --seed) SEED="$2"; shift 2 ;;
    --headed) HEADLESS=false; shift ;;
    --model-endpoint) MODEL_ENDPOINT="$2"; shift 2 ;;
    --openrouter-key) OPENROUTER_KEY="$2"; shift 2 ;;
    --profile-dir) PROFILE_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: zsh openai_dots_oss_toolkit_macos26.zsh [OPTIONS]"
      echo "  --agent-mode           Run in non-interactive agent automation mode"
      echo "  --host <HOST>          Bind host (default: 127.0.0.1)"
      echo "  --port <PORT>          Bind port (default: 8765)"
      echo "  --seed <INT>           Deterministic browser fingerprint seed (default: 894129)"
      echo "  --headed               Run browser in visible/headed mode"
      echo "  --model-endpoint <STR> Model endpoint: local-ollama | openrouter | vllm"
      echo "  --openrouter-key <KEY> OpenRouter API key"
      echo "  --profile-dir <PATH>   Persistent browser profile directory"
      exit 0
      ;;
    *) shift ;;
  esac
done

log_info() {
  if [[ "$AGENT_MODE" == "false" ]]; then
    echo -e "${CYAN}[INFO]${NC} $1"
  fi
}

log_ok() {
  if [[ "$AGENT_MODE" == "false" ]]; then
    echo -e "${GREEN}[OK]${NC} $1"
  fi
}

log_warn() {
  if [[ "$AGENT_MODE" == "false" ]]; then
    echo -e "${YELLOW}[WARN]${NC} $1"
  fi
}

log_err() {
  if [[ "$AGENT_MODE" == "false" ]]; then
    echo -e "${RED}[ERROR]${NC} $1" >&2
  fi
}

# Preflight check
check_preflight() {
  log_info "Running system preflight check for macOS $(sw_vers -productVersion 2>/dev/null || echo '26')..."

  # Check Architecture
  ARCH=$(uname -m)
  log_ok "Architecture detected: $ARCH"

  # Check Python
  if command -v python3 >/dev/null 2>&1; then
    PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')")
    log_ok "Python3 found: $PY_VER"
  else
    log_err "Python3 not found. Please install Xcode Command Line Tools: xcode-select --install"
    return 1
  fi

  # Check or Install uv
  if ! command -v uv >/dev/null 2>&1; then
    log_info "uv not found in PATH. Checking ~/.local/bin/uv or Homebrew..."
    if [[ -f "$HOME/.local/bin/uv" ]]; then
      export PATH="$HOME/.local/bin:$PATH"
      log_ok "Loaded uv from $HOME/.local/bin"
    elif command -v brew >/dev/null 2>&1 && brew list uv >/dev/null 2>&1; then
      export PATH="$(brew --prefix)/bin:$PATH"
    else
      log_info "Installing Astral uv (native fast python runner)..."
      curl -LsSf https://astral.sh/uv/install.sh | sh
      export PATH="$HOME/.local/bin:$PATH"
    fi
  fi

  if command -v uv >/dev/null 2>&1; then
    log_ok "Astral uv ready: $(uv --version)"
  else
    log_err "Failed to prepare uv. Manual install required."
    return 1
  fi

  # Check Local Inference Engine
  if curl -s "http://127.0.0.1:11434/api/version" >/dev/null 2>&1; then
    OLLAMA_VER=$(curl -s "http://127.0.0.1:11434/api/version" | grep -o '"version":"[^"]*"' | cut -d':' -f2 | tr -d '"')
    log_ok "Local Ollama service detected at 127.0.0.1:11434 (Version: $OLLAMA_VER)"
  else
    log_warn "Local Ollama service not detected on port 11434. Fallback to API keys."
  fi

  return 0
}

# Setup directories
prepare_storage() {
  mkdir -p "$PROFILE_DIR"
  mkdir -p "$LOG_DIR"
  log_ok "Storage initialized at $PROFILE_DIR"
}

# Start Agent Runtime
start_runtime() {
  prepare_storage
  log_info "Configuring Dots runtime on $BIND_HOST:$BIND_PORT (Seed: $SEED)..."

  RUN_ARGS=(
    "ui"
    "--host" "$BIND_HOST"
    "--port" "$BIND_PORT"
    "--seed" "$SEED"
    "--profile-dir" "$PROFILE_DIR"
  )

  if [[ "$HEADLESS" == "false" ]]; then
    RUN_ARGS+=("--headed")
  fi

  if [[ -n "$OPENROUTER_KEY" ]]; then
    RUN_ARGS+=("--openrouter-key" "$OPENROUTER_KEY")
  fi

  # Agent mode JSON output
  if [[ "$AGENT_MODE" == "true" ]]; then
    echo "{\"status\": \"starting\", \"host\": \"$BIND_HOST\", \"port\": $BIND_PORT, \"profile_dir\": \"$PROFILE_DIR\"}"
    exec uvx --from "git+https://github.com/feder-cr/dots" dots "${RUN_ARGS[@]}"
  fi

  echo -e "\n${PURPLE}================================================================${NC}"
  echo -e "${GREEN}  ✨ Launching Open-Source Dots Agent Runtime on macOS!${NC}"
  echo -e "${CYAN}  🌐 Web UI & Conversation : http://${BIND_HOST}:${BIND_PORT}${NC}"
  echo -e "${CYAN}  🛡️ Stealth Browser       : Patched Firefox (Seed: ${SEED})${NC}"
  echo -e "${CYAN}  📁 Session Storage       : ${PROFILE_DIR}${NC}"
  echo -e "${PURPLE}================================================================${NC}\n"

  uvx --from "git+https://github.com/feder-cr/dots" dots "${RUN_ARGS[@]}"
}

# Interactive Menu
show_menu() {
  clear
  echo -e "${CYAN}====================================================================${NC}"
  echo -e "${PURPLE}   OpenAI Dots 开源平替部署工具包 (macOS 26 原生 Zsh)${NC}"
  echo -e "${CYAN}====================================================================${NC}"
  echo " 1. 运行系统前置环境探测 (Preflight Diagnostic)"
  echo " 2. 一键启动 Stealth 隐形 Web 智能体 (feder-cr/dots)"
  echo " 3. 检测本地 Ollama / vLLM 私有大模型推理端点"
  echo " 4. 创建 Launchd 后台 24 小日常驻服务 (Always-on Daemon)"
  echo " 5. 退出 (Exit)"
  echo -e "${CYAN}--------------------------------------------------------------------${NC}"
  read -r "CHOICE?请选择操作 [1-5]: "

  case "$CHOICE" in
    1)
      check_preflight
      read -r "?按回车键返回主菜单..."
      show_menu
      ;;
    2)
      check_preflight
      read -r "INPUT_KEY?请输入 OpenRouter API Key (留空使用已配置环境变量): "
      if [[ -n "$INPUT_KEY" ]]; then
        OPENROUTER_KEY="$INPUT_KEY"
      fi
      start_runtime
      ;;
    3)
      log_info "Probing local inference endpoints..."
      if curl -s "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] Local Ollama is running! Available models:${NC}"
        curl -s "http://127.0.0.1:11434/api/tags" | grep -o '"name":"[^"]*"' | cut -d':' -f2 | tr -d '"' | sed 's/^/  - /'
      else
        echo -e "${YELLOW}[WARN] Ollama not found on 127.0.0.1:11434.${NC}"
      fi
      read -r "?按回车键返回主菜单..."
      show_menu
      ;;
    4)
      log_info "Creating ~/Library/LaunchAgents/net.margrop.dots.plist..."
      PLIST_PATH="$HOME/Library/LaunchAgents/net.margrop.dots.plist"
      mkdir -p "$HOME/Library/LaunchAgents"
      cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>net.margrop.dots</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which zsh)</string>
        <string>$(pwd)/openai_dots_oss_toolkit_macos26.zsh</string>
        <string>--agent-mode</string>
        <string>--port</string>
        <string>${BIND_PORT}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/dots.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/dots.stderr.log</string>
</dict>
</plist>
EOF
      log_ok "Launchd plist generated at $PLIST_PATH"
      echo "To enable: launchctl load $PLIST_PATH"
      echo "To disable: launchctl unload $PLIST_PATH"
      read -r "?按回车键返回主菜单..."
      show_menu
      ;;
    5)
      exit 0
      ;;
    *)
      show_menu
      ;;
  esac
}

# Main Entry
if [[ "$AGENT_MODE" == "true" ]]; then
  check_preflight
  start_runtime
else
  show_menu
fi
