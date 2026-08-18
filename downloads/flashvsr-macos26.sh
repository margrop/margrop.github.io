#!/usr/bin/env bash
set -euo pipefail
INPUT=${1:?usage: $0 INPUT [OUTPUT_DIR]}; [[ -e "$INPUT" ]] || exit 2; echo "This CUDA/SageAttention FlashVSR path is not a supported macOS CUDA workflow." >&2; echo "The script stops intentionally; use a separately tested MPS backend if available." >&2; exit 3