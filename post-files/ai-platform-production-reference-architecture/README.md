# AI Platform fault-injection lab

This lab uses only the Python standard library. It performs no network calls,
loads no secrets, and operates only on synthetic identities and tool results.

Run it on Windows 11, Ubuntu 26.04, or macOS 26:

```bash
python3 ai_platform_fault_lab.py --clean
```

On Windows, `py -3 ai_platform_fault_lab.py --clean` is also supported.

The generated `lab-output/` directory contains human-readable scenario results,
structured JSONL spans, a metrics document, and a disposable SQLite state file.
