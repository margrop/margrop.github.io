# Turn Manager cancellation and barge-in lab

This folder contains a deterministic experiment for the article **“You Said
Stop—So Why Is the AI Still Running?”** It uses only the Python standard
library. It performs no network request, calls no real model or tool, loads no
credential, and writes only to `lab-output/`.

## One-command manual run

- Windows 11: `powershell -ExecutionPolicy Bypass -File .\run-windows11.ps1`
- Ubuntu 26.04: `bash ./run-ubuntu-2604.sh`
- macOS 26: `bash ./run-macos-26.sh`

Python 3 is the only runtime prerequisite. The scripts do not install or
download anything.

## Agent-driven run

Give the local automation agent `agent-task.json`, allow it to execute only the
command matching the operating system, and require it to parse
`lab-output/report.json`. The machine-readable variants are:

- Windows 11: `powershell -ExecutionPolicy Bypass -File .\run-windows11.ps1 -Agent`
- Ubuntu 26.04: `bash ./run-ubuntu-2604.sh --agent`
- macOS 26: `bash ./run-macos-26.sh --agent`

Success requires exit code `0`, report status `PASS`, and `24/24` assertions.
An agent must not infer success from console appearance alone.

## Evidence

- `acceptance.log`: human-readable release gate
- `<scenario>.log`: one event timeline per scenario
- `events.jsonl`: structured canonical events
- `metrics.json`: intentionally small metric set
- `report.json`: machine-readable checks and environment facts

The virtual clock makes screenshots reproducible. The socket guard makes an
accidental DNS lookup or outbound connection fail closed. This is an
architecture experiment, not a model benchmark, WebRTC interoperability test,
or proof that a third-party tool can be forcibly cancelled.
