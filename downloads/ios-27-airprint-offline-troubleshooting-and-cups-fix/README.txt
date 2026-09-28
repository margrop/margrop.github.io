iOS 27 AirPrint Compatibility & Diagnostic Toolkit
===================================================

This package contains automated cross-platform scripts to diagnose, configure, and restore AirPrint compatibility for printers connected to Ubuntu 26.04 LTS, macOS 26, and Windows 11 after the iOS 27 upgrade.

Files:
- airprint_toolkit_ubuntu2604.sh : Ubuntu 26.04 Bash toolkit
- airprint_toolkit_macos26.zsh    : macOS 26 Zsh toolkit
- airprint_toolkit_windows11.ps1 : Windows 11 PowerShell toolkit
- airprint_core_agent.py         : Python core engine (supports Human & Agent declarative modes)
- plan.template.json             : Sample declarative plan for Agent automation

Usage:
  Ubuntu:  sudo ./airprint_toolkit_ubuntu2604.sh --apply
  macOS:   ./airprint_toolkit_macos26.zsh --apply
  Windows: powershell -ExecutionPolicy Bypass -File .irprint_toolkit_windows11.ps1 -Apply

Agent Mode:
  python3 airprint_core_agent.py --plan plan.template.json --apply --json
