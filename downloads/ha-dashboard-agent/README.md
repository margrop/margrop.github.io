# Home Assistant dashboard review kit

Requires Python 3.11+, direct access to your existing HA, and an HA administrator
token. No pip packages, cloud services, HACS cards or external AI service are used.
Python is a prerequisite, including on macOS; it is not silently installed.

Unzip all files into one folder. Run one of these commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-windows11.ps1 --apply
```

```bash
bash ./run-ubuntu2604.sh --apply
```

```zsh
zsh ./run-macos27.zsh --apply
```

The execution policy override applies only to this Windows process. Omitting
`--apply` makes a read-only plan. Enter the HA base URL and then a long-lived token
at the hidden prompt. Do not put a token in a command argument, screenshot or Git.

An Agent can read the two inputs from `HA_URL` and `HOME_ASSISTANT_TOKEN` and run:

```bash
python3 ha_dashboard.py --non-interactive --apply --out ./ha-private-output
```

The tool creates a new administrator-only dashboard with native room views and
detail-opening tiles. It does not replace your current dashboard, set defaults,
delete/disable entities, call device actions, change the recorder, restart HA or
install integrations. Normal status and device-category entities are excluded
from room cards when they are hidden, diagnostic, unknown or unavailable at
generation time. This is a point-in-time plan; rerun to include later changes.
The complete registration inventory remains in the private local output.

Review the new dashboard visually on desktop and phone. Move selected cards to
your everyday dashboard manually. Each apply creates a separate dashboard; it
does not update an earlier generated dashboard.

To remove the unchanged generated dashboard using its receipt:

```bash
python3 ha_dashboard.py --rollback ./ha-dashboard-output/receipt.json
```

Rollback checks the generated path, dashboard ID and configuration hash. If you
edited the dashboard after creation, remove it through the HA UI after review.
If creation succeeds but saving or verification fails, the receipt is kept;
inspect/remove that newly created dashboard through the HA UI. Original
dashboards are never overwritten.

The output contains private room/entity names. POSIX permissions are restricted;
on Windows use a private user folder and its inherited user-only ACL. Do not
publish the output. The token is never written into the output.

Validation for the accompanying article: real HA read-only plan; local mock HA
exercise of WebSocket authentication, fragmented frames, ping/pong, creation,
read-back and guarded rollback; Bash/Zsh syntax and Python compilation. Windows
11 and Ubuntu 26.04 native execution was not performed. The macOS 27 launcher
and shared core were executed against the real HA in read-only plan mode.
Device actions were not tested by this kit.
