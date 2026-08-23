# AI Worker crash and idempotency lab

This deterministic lab reproduces the dangerous interval where a Worker has
already caused a side effect but has not saved `COMPLETED`. It then compares a
naive retry with an idempotency key and unique constraint, demonstrates lease
takeover plus fencing, recovers a transactional outbox, and reconciles a
receiver that cannot deduplicate.

## Safety boundary

- Python standard library only (`sqlite3`, `hashlib`, `json`, and filesystem APIs).
- No network access, provider API, real tool, credential, host address, or host inspection.
- Every restart, event, and reservation is synthetic and stored in `lab-output/state.sqlite3`.
- `--clean` deletes only a result directory named `lab-output` or `reference-run`.

## One-click execution

Windows 11 PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Run-Windows11.ps1
```

Ubuntu 26.04:

```bash
chmod +x run-ubuntu-26.04.sh
./run-ubuntu-26.04.sh
```

macOS 26:

```bash
chmod +x run-macos-26.sh
./run-macos-26.sh
```

All entry points require seven `[PASS]` lines and `result=PASS` in
`lab-output/results/06-acceptance-summary.txt`. The first scenario deliberately
reproduces a double effect and labels it `[EXPECTED RISK]`; reproducing that
risk is itself one acceptance check.

## Manual inspection

Inspect the six text files in `lab-output/results/`, `metrics.json`, and the
SQLite database. Do not treat this teaching lab as a production transaction
coordinator: a remote effect cannot generally share an ACID transaction with
your task database. In production, put deduplication at the effect receiver,
use a receiver-supported request key or conditional version, and reconcile
ambiguous outcomes.

See `AGENT-PROMPT.md` for a bounded Agent execution method.
