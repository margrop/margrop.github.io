#!/usr/bin/env bash
# Ubuntu 26.04 LTS (Bash) Automation Wrapper for Home Assistant Custom Integration Toolkit
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || command -v python || true)}"

if [[ -z "$PYTHON_BIN" ]]; then
    echo "[-] Python 3 not found. Installing python3-minimal..." >&2
    sudo apt-get update -qq && sudo apt-get install -y -qq python3
    PYTHON_BIN="python3"
fi

KIT_PY="$SCRIPT_DIR/ha_custom_kit.py"

ACTION="${1:-all}"
shift || true

case "$ACTION" in
    probe)
        echo ">>> [Ubuntu 26.04] Probing device endpoint..."
        "$PYTHON_BIN" "$KIT_PY" probe "$@"
        ;;
    scaffold)
        echo ">>> [Ubuntu 26.04] Scaffolding modern custom component..."
        "$PYTHON_BIN" "$KIT_PY" scaffold "$@"
        ;;
    lint)
        echo ">>> [Ubuntu 26.04] Running AST and non-blocking linting..."
        "$PYTHON_BIN" "$KIT_PY" lint "$@"
        ;;
    deploy)
        echo ">>> [Ubuntu 26.04] Deploying to Home Assistant..."
        "$PYTHON_BIN" "$KIT_PY" deploy "$@"
        ;;
    all)
        echo ">>> [Ubuntu 26.04] Running full automated build pipeline..."
        "$PYTHON_BIN" "$KIT_PY" probe --mock
        "$PYTHON_BIN" "$KIT_PY" scaffold --domain "my_custom_device" --name "My Custom Smart Device" --out-dir "$SCRIPT_DIR/custom_components"
        "$PYTHON_BIN" "$KIT_PY" lint --path "$SCRIPT_DIR/custom_components/my_custom_device"
        echo ">>> [Ubuntu 26.04] Pipeline completed successfully!"
        ;;
    *)
        echo "Usage: $0 {probe|scaffold|lint|deploy|all} [options]" >&2
        exit 1
        ;;
esac
