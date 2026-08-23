# Agent execution prompt / Agent 自动执行指令

## 中文

请在我的本机执行当前目录中的 PostgreSQL 生产就绪实验，但不要连接或修改任何现有数据库。开始前先读取 `README.md`、`compose.yaml` 和平台入口脚本；确认 Docker 与 Compose v2 可用。Windows 11 执行 `Run-Windows11.ps1`，Ubuntu 26.04 执行 `run-ubuntu-26.04.sh`，macOS 26 执行 `run-macos-26.zsh`。只允许操作项目名 `blog_pg_readiness_lab`、恢复容器 `blog-pg-readiness-restore` 及该项目的卷；禁止运行 `docker system prune`、禁止发布宿主端口、禁止加载真实凭据。实验完成后检查 `results/11-acceptance-summary.txt` 六项均为 `[PASS]`，再确认相关容器、网络和卷已经按脚本清理。若失败，保留结果与日志并解释根因，不要为了显示成功而改写验收文件。

## English

Run the PostgreSQL production-readiness lab in the current directory without connecting to or changing any existing database. First read `README.md`, `compose.yaml`, and the platform entry point, then verify Docker and Compose v2. Use `Run-Windows11.ps1` on Windows 11, `run-ubuntu-26.04.sh` on Ubuntu 26.04, or `run-macos-26.zsh` on macOS 26. You may operate only on project `blog_pg_readiness_lab`, restore container `blog-pg-readiness-restore`, and that project's volumes. Never run `docker system prune`, publish a host port, or load a real credential. After the run, require all six `[PASS]` lines in `results/11-acceptance-summary.txt` and confirm the scoped containers, network, and volumes were removed. If anything fails, retain the results and logs and explain the cause; do not edit acceptance output to manufacture a pass.
