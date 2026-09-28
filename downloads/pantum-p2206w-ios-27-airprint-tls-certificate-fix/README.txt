========================================================================
  Pantum P2206W × iOS 27 AirPrint 825-Day Certificate Auto-Fix Toolkit
========================================================================

Files in this archive:
1. pantum_toolkit_windows11.ps1  - Native PowerShell 7 script for Windows 11
2. pantum_toolkit_ubuntu2604.sh  - Native Bash script for Ubuntu 26.04 / Debian
3. pantum_toolkit_macos26.zsh    - Native Zsh script for macOS 26 (Tahoe)
4. pantum_core_agent.py          - Cross-platform declarative Python agent
5. plan.template.json            - JSON plan template for AI Agent orchestration

Usage Instructions:
- Run directly on your platform (Windows/Ubuntu/macOS) with:
  ./pantum_toolkit_macos26.zsh <printer-ip>
  ./pantum_toolkit_ubuntu2604.sh <printer-ip>
  .\pantum_toolkit_windows11.ps1 -PrinterHost "<printer-ip>"
- Or use the Agent declarative execution:
  python3 pantum_core_agent.py --plan plan.template.json

For detailed walkthrough and technical principles, visit:
https://blog.margrop.net/post/pantum-p2206w-ios-27-airprint-tls-certificate-fix/
