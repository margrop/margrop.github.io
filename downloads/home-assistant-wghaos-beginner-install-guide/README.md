# Wintermelon HAOS (wghaos) Beginner Installation Toolkit

Zero-dependency cross-platform helper for Windows 11, Ubuntu 26.04, and macOS 27.

## Commands
1. `plan` — Print official 18.3.1 firmware URL, disk space check, and recommended UEFI/CPU-host VM parameters.
2. `fetch` — Download official firmware image and compute SHA256 digest.
3. `probe` — Concurrently test ports `8124` (Companion), `7681` (TTYD), and `8123` (HA Core).
4. `wait` — Poll initialization status until `8123` is ready and write a redacted readiness report.
