# Google Account 20-Year Vintage & Keepalive Health Toolkit

Cross-platform, zero-dependency audit & keepalive suite for Google Accounts.
Protects against Google's 2-Year Inactive Account Deletion Policy.

## Supported Platforms
- **Windows 11**: `google_account_toolkit_windows11.ps1` (PowerShell 7.4+)
- **Ubuntu 26.04 LTS**: `google_account_toolkit_ubuntu2604.sh` (Bash 5.2+)
- **macOS 27**: `google_account_toolkit_macos27.zsh` (Zsh 5.9+)

## Quick Start (Interactive Mode)
```bash
# macOS
chmod +x google_account_toolkit_macos27.zsh
./google_account_toolkit_macos27.zsh

# Ubuntu
chmod +x google_account_toolkit_ubuntu2604.sh
./google_account_toolkit_ubuntu2604.sh

# Windows 11
.\google_account_toolkit_windows11.ps1
```

## AI Agent / Headless CI Mode
```bash
./google_account_toolkit_macos27.zsh --auto --audit --json
```

## Features
1. Extract birth date from `SubscriberInfo.html` or Google Takeout `.zip`.
2. Multi-account 730-day inactivity countdown calculation.
3. Safe masked output preventing email address leakage.
