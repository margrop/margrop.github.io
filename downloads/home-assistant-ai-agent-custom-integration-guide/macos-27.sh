#!/usr/bin/env zsh
# macOS 27 (Zsh) Automation Wrapper for Home Assistant Custom Integration Toolkit
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || command -v python || true)}"

if [[ -z "$PYTHON_BIN" ]]; then
    echo "[-] Python 3 not found. Please ensure Xcode Command Line Tools or Python 3 is installed." >&2
    exit 1
fi

KIT_PY="$SCRIPT_DIR/ha_custom_kit.py"

ACTION="${1:-all}"
shift || true

case "$ACTION" in
    probe)
        print -P "%F{cyan}>>> [macOS 27] Probing device endpoint...%f"
        "$PYTHON_BIN" "$KIT_PY" probe "$@"
        ;;
    scaffold)
        print -P "%F{cyan}>>> [macOS 27] Scaffolding modern custom component...%f"
        "$PYTHON_BIN" "$KIT_PY" scaffold "$@"
        ;;
    lint)
        print -P "%F{cyan}>>> [macOS 27] Running AST and non-blocking linting...%f"
        "$PYTHON_BIN" "$KIT_PY" lint "$@"
        ;;
    deploy)
        print -P "%F{cyan}>>> [macOS 27] Deploying to Home Assistant...%f"
        "$PYTHON_BIN" "$KIT_PY" deploy "$@"
        ;;
    all)
        print -P "%F{green}>>> [macOS 27] Running full automated build pipeline...%f"
        "$PYTHON_BIN" "$KIT_PY" probe --mock
        "$PYTHON_BIN" "$KIT_PY" scaffold --domain "my_custom_device" --name "My Custom Smart Device" --out-dir "$SCRIPT_DIR/custom_components"
        "$PYTHON_BIN" "$KIT_PY" lint --path "$SCRIPT_DIR/custom_components/my_custom_device"
        print -P "%F{green}>>> [macOS 27] Pipeline completed successfully!%f"
        ;;
    *)
        echo "Usage: $0 {probe|scaffold|lint|deploy|all} [options]" >&2
        exit 1
        ;;
esac
