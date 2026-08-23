# Agent task: enforce the AI Platform release gate

Operate only inside this directory. Do not install packages, use a network, read credentials, or change machine configuration.

1. Inspect `release_gate_lab.py`; list its six categories and thirty checks.
2. Run the matching platform launcher: `run_windows.ps1`, `run_ubuntu.sh`, or `run_macos.sh`.
3. Read `release-gate-output/verification.json` and require `total=30`, `passed_count=30`, and `release=PASS`.
4. If any check fails, stop and report the exact category, check, and evidence. Do not bypass, delete, or weaken a gate.
5. Report the process exit code and key output as supporting evidence, not as the sole proof.
