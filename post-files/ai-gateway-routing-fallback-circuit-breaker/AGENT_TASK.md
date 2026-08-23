# Agent task: configure and verify the local AI Gateway fault lab

Work only inside this downloaded lab directory. Do not add real endpoints,
hostnames, API keys, or credentials. Do not enable network access.

1. Read `README.md` and `ai_gateway_fault_lab.py`.
2. Choose exactly one wrapper for the current OS:
   - Windows 11: `run-windows11.ps1`
   - Ubuntu 26.04: `run-ubuntu-2604.sh`
   - macOS 26: `run-macos-26.sh`
3. Run the wrapper without modifying the scenario data.
4. Parse `lab-output/summary.json`.
5. Accept only if `results.acceptance.passed` is `7` and
   `outbound_attempts` is `0`.
6. Report each check, the synthetic cost multiplier from the hedging scenario,
   and any stderr. Never claim that synthetic prices are real provider prices.

Stop on the first failed check. Do not “fix” a failure by weakening an
assertion, increasing a budget, removing the network guard, or skipping a
scenario.
