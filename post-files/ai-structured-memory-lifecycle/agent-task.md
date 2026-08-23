# Agent task: verify structured memory safely

Run only the local files in this directory. Do not install packages, make network calls, read credentials, or change system configuration.

1. Inspect `memory_lifecycle_lab.py` and explain its SQLite schema and six acceptance checks.
2. On Windows 11 run `powershell -ExecutionPolicy Bypass -File .\run_windows.ps1`; on Ubuntu 26.04 run `bash ./run_ubuntu.sh`; on macOS 26 run `bash ./run_macos.sh`.
3. Read `memory-lab-output/verification.json` and require `passed=true`.
4. Report each PASS/FAIL, the output directory, and any exception. Never claim success from the process exit code alone.
5. Do not replace synthetic identifiers with real tenant, user, host, address, or credential data.
