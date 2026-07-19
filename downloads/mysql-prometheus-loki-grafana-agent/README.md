# Observability Agent Lab

Self-hosted MySQL, Prometheus, Loki, Grafana and a read-only MCP bridge used by the accompanying tutorial.

- Windows 11: run `powershell -ExecutionPolicy Bypass -File .\install-windows-11.ps1`
- Ubuntu 26.04: run `bash install-ubuntu-26.04.sh`
- macOS 26: run `bash install-macos-26.sh`

The installer writes random secrets to the local ignored `.env` file, starts the containers, pushes a synthetic incident to Loki, and generates `agent-mcp.json`.

Stop the lab with `docker compose down`. Remove all demo data with `docker compose down -v`.
