# Agent execution prompt / Agent 自动配置与验收指令

## 中文

请在本机运行当前目录中的 AI Worker 崩溃与幂等实验。开始前先读取 `README.md`、`worker_crash_lab.py` 和当前平台入口脚本；确认脚本只使用 Python 标准库、只写当前目录下的 `lab-output`，且不访问网络、不读取环境变量或凭据、不调用真实工具。Windows 11 运行 `Run-Windows11.ps1`，Ubuntu 26.04 运行 `run-ubuntu-26.04.sh`，macOS 26 运行 `run-macos-26.sh`。完成后逐项检查 `lab-output/results/06-acceptance-summary.txt` 必须有 7 行 `[PASS]` 和 `result=PASS`；再核对 `metrics.json` 中 `network_calls` 与 `real_credentials_loaded` 都是 0、`naive_side_effects` 是 2、`safe_side_effects` 与 `downstream_effects` 都是 1。若失败，请保留证据、解释根因，不要修改结果文件制造成功。

## English

Run the AI Worker crash and idempotency lab in the current directory. First read `README.md`, `worker_crash_lab.py`, and the platform entry point. Confirm that it uses only Python's standard library, writes only to `lab-output`, never accesses the network, never reads environment variables or credentials, and never calls a real tool. Run `Run-Windows11.ps1` on Windows 11, `run-ubuntu-26.04.sh` on Ubuntu 26.04, or `run-macos-26.sh` on macOS 26. Require seven `[PASS]` lines and `result=PASS` in `lab-output/results/06-acceptance-summary.txt`. Also verify in `metrics.json` that `network_calls` and `real_credentials_loaded` are 0, `naive_side_effects` is 2, and both `safe_side_effects` and `downstream_effects` are 1. If anything fails, retain the evidence and explain the root cause; never edit the result files to manufacture a pass.
