# Home Assistant Security Audit & AI Agent Guardrails Toolkit

Zero third-party dependencies. Built exclusively with Python 3 standard library (`urllib`, `ssl`, `json`, `argparse`).

## Quick Start by OS

### 1. Windows 11 (PowerShell)
```powershell
.\windows-11.ps1 probe --url "http://homeassistant.local:8123"
.\windows-11.ps1 token-audit -c config.example.json
.\windows-11.ps1 entity-guard -c config.example.json
.\windows-11.ps1 generate-mcp -c config.example.json
```

### 2. Ubuntu 26.04 (Bash)
```bash
chmod +x ubuntu-26.04.sh
./ubuntu-26.04.sh probe --url "http://homeassistant.local:8123"
./ubuntu-26.04.sh token-audit -c config.example.json
./ubuntu-26.04.sh entity-guard -c config.example.json
./ubuntu-26.04.sh generate-mcp -c config.example.json
```

### 3. macOS 27 (Zsh)
```zsh
chmod +x macos-27.sh
./macos-27.sh probe --url "http://homeassistant.local:8123"
./macos-27.sh token-audit -c config.example.json
./macos-27.sh entity-guard -c config.example.json
./macos-27.sh generate-mcp -c config.example.json
```

## AI Agent Integration Mode
AI Agents can run audits and get clean JSON without terminal color codes:
```bash
python3 ha_security_toolkit.py agent-audit -c config.example.json
```
