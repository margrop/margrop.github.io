# Home Assistant Midea AC LAN Offline Dependency Toolkit

This toolkit automates the offline sourcing, SHA256 integrity verification, and user-site injection of companion Python libraries for Home Assistant custom integrations (specifically `midea-lan` for `midea_ac_lan`).

## Files Included

- `midea_deps_toolkit.py`: Pure Python 3 standard library implementation (zero pip dependencies required).
- `run-windows11.ps1`: Windows 11 PowerShell 7 / Windows PowerShell automation launcher.
- `run-ubuntu2604.sh`: Ubuntu 26.04 LTS Bash automation launcher.
- `run-macos27.zsh`: macOS 27 Zsh automation launcher.

## Execution Modes

### 1. Manual Execution (CLI)

```bash
# Ubuntu 26.04
bash ./run-ubuntu2604.sh --apply

# macOS 27
zsh ./run-macos27.zsh --apply

# Windows 11
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-windows11.ps1 -Apply
```

### 2. Agent Automated Execution

Pass `HA_URL` and `HA_TOKEN` through environment variables:

```bash
export HA_URL="http://ha.local:8123"
export HA_TOKEN="YOUR_LONG_LIVED_ACCESS_TOKEN"

python3 midea_deps_toolkit.py --non-interactive --apply
```
