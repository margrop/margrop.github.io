# PostgreSQL production-readiness lab

This isolated Docker lab reproduces the evidence used in the bilingual blog
post: a direct-connection ceiling, PgBouncer transaction pooling, a query plan
before/after indexing, dead tuples before/after `VACUUM`, and point-in-time
recovery after a synthetic accidental delete.

## Safety boundary

- Synthetic data only; no real credentials.
- No host ports are published.
- Cleanup is scoped to Docker Compose project `blog_pg_readiness_lab`, restore
  container `blog-pg-readiness-restore`, and the lab's named volumes.
- The scripts never run a global Docker prune.
- Expect several hundred megabytes of temporary data and image layers.

## One-click commands

Ubuntu 26.04:

```bash
chmod +x run-lab.sh run-ubuntu-26.04.sh
./run-ubuntu-26.04.sh
```

macOS 26:

```zsh
chmod +x run-lab.sh run-macos-26.zsh
./run-macos-26.zsh
```

Windows 11 PowerShell (Docker Desktop with WSL 2 integration):

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Run-Windows11.ps1
```

The live run writes `results/*.txt`. Privacy-sanitized output from the reference
run is kept in `reference-results/`. See `AGENT-PROMPT.md` for a bounded Agent
execution method.
