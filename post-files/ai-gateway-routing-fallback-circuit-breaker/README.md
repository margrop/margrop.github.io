# AI Gateway routing, fallback, and circuit-breaker lab

This deterministic lab accompanies the bilingual blog post with the same slug.
It calls no model and no external service, loads no API key, and blocks outbound
socket creation. Provider names, prices, latency, token counts, and responses
are synthetic teaching data rather than benchmark results.

## One-click execution

- Windows 11: right-click `run-windows11.ps1` and run with PowerShell, or use
  `powershell -ExecutionPolicy Bypass -File .\run-windows11.ps1`.
- Ubuntu 26.04: `bash run-ubuntu-2604.sh`.
- macOS 26: `bash run-macos-26.sh`.

All wrappers run seven acceptance checks and write `lab-output/events.jsonl`
plus `lab-output/summary.json`. A successful run ends with `PASS: 7/7 checks;
outbound network attempts: 0`.

## Manual execution

```text
python3 ai_gateway_fault_lab.py --scenario all --output-dir lab-output --clean
python3 ai_gateway_fault_lab.py --scenario bounded-429
python3 ai_gateway_fault_lab.py --scenario terminal-errors
python3 ai_gateway_fault_lab.py --scenario circuit
```

The Windows Python launcher can use `py -3` instead of `python3`.

## Scope

The lab validates routing-policy mechanics, not a provider SLA, model quality,
real billing behavior, or production throughput. In particular, the 3x hedging
case is a deliberately pessimistic synthetic example showing why accepted
parallel calls need a budget; it does not claim that every provider bills a
cancelled request in the same way.
