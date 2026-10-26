SGCC Local Persistence Kit / 网上国网本地持久化套件
=================================================

Purpose
Create six restorable Home Assistant template sensors and a separate YAML dashboard
for an ALREADY WORKING SGCC collector. This kit does not log in to SGCC, solve a
CAPTCHA, install the collector, or require an AI/cloud automation service.
It only calls your own HA API. Python 3.11+ and a writable mount/copy of the live
HA configuration directory are prerequisites. Do not point it at a source checkout
that HA does not actually read. HA Container users mount its /config directory;
HA OS users can use their existing authenticated file share. Backups remain private.

中文速读
先安装并登录采集器，再运行本套件。套件自动生成可恢复的模板、按业务日期去重的
近期日明细、独立电量面板；不会处理账号密码或验证码，不调用云端 AI。
本机需要 Python 3.11+，并已挂载可写的 HA 配置目录。普通台式机运行脚本不会自动变成 HA OS。
旧面板及原始统计 ID 不迁移、不删除；独立镜像可与它们并存。

Setup
1. Copy mapping.example.json to mapping.local.json. Replace all six source entity
   IDs with your actual values (keep the file private). daily_date_attribute must
   be a real YYYY-MM-DD business date; inspect your collector. A collection date
   is not automatically the date when electricity was used.
2. Keep yearly_counter_verified=false unless you verified that year_usage is a
   nonnegative, year-to-date, increasing counter with a genuine annual reset.
   Enabling it creates NEW statistics under a NEW ID; it does not migrate old data.
3. Set private process environment variables HOME_ASSISTANT_URL,
   HOME_ASSISTANT_TOKEN, and HA_CONFIG_DIR. Use a dedicated revocable HA token.
   Never paste credentials into the public example, issue tracker, or AI chat.
4. From this directory, run one platform entry below. plan is offline and does
   not touch HA. check prints statuses and units, not account IDs or readings.

Windows 11 (PowerShell, existing Python installation)
  Copy-Item mapping.example.json mapping.local.json
  .\windows-11.ps1 plan
  .\windows-11.ps1 check
  .\windows-11.ps1 apply --restart
  .\windows-11.ps1 check --require-mirrors
If local policy blocks a reviewed script, use a process-only invocation:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\windows-11.ps1 plan

Ubuntu 26.04
  cp mapping.example.json mapping.local.json
  bash ubuntu-26.04.sh plan
  bash ubuntu-26.04.sh check
  bash ubuntu-26.04.sh apply --restart
  bash ubuntu-26.04.sh check --require-mirrors

macOS 27
  cp mapping.example.json mapping.local.json
  bash macos-27.sh plan
  bash macos-27.sh check
  bash macos-27.sh apply --restart
  bash macos-27.sh check --require-mirrors

apply first authenticates, saves checksummed backups, writes only owned files,
and calls HA configuration validation. Failed validation automatically restores
the files. --restart explicitly permits a Core restart after validation. Omit it
to restart later. First readings arrive on a source change or within five minutes
of a valid source becoming visible. Cache values survive a normal restart after
HA has saved restore state. Power loss/storage loss still requires proper backups.

The sidebar dashboard key is sgcc-kit. Common inline packages and
!include_dir_named packages are supported. External homeassistant includes,
ambiguous packages layouts, existing conflicting files and unsafe paths are
refused; an Agent or human can review generated/package.yaml and include it
manually. Do not replace a complex production configuration with the example.

Rollback (use the snapshot path printed by apply)
  python3 sgcc_kit.py rollback --config-dir YOUR_HA_CONFIG_DIR --snapshot YOUR_SNAPSHOT
On Windows use py -3 in place of python3. Rollback refuses to overwrite files
changed since apply. Restart/reload HA separately after reviewing a rollback.

Data semantics
- Missing/unavailable/nonnumeric readings never become a synthetic zero.
- A known zero is valid. Balances may be negative; daily energy may not.
- Daily history deduplicates by real date, supports late corrections, keeps
  120 dated rows by default, and does not fill gaps. It is not a permanent ledger.
- Balance and completed-month snapshots have no cumulative state_class.
- Annual energy gets total_increasing ONLY with explicit business confirmation.
- The kit does not backdate HA statistics or import historical utility bills.
- Restored values are cached readings, not proof of a fresh login or collection.
- check verifies source presence, number/unit validity and a nonfuture date.
  --require-mirrors also requires all generated sensors to have valid readings.
  Separately inspect collector logs for login, account completion, failures and
  next schedule. Restart acceptance requires actual before/after observation.

Agent task
Inspect the source IDs, units, actual business dates, collector version and current
configuration. Run plan and read generated YAML. Preserve unrelated YAML, dashboards,
accounts and existing statistic IDs. Set private environment variables without
logging values. Run check, apply in a maintenance window, and require configuration
validation plus healthy recovery. Check again after a real push and a planned
restart. Do not invent zero values, backfill fake data, or label cached data fresh.
If unsupported YAML is detected, stop automatic edits and propose an exact include.

Validation scope (2026-10-26)
See the article for executed checks. The supplied unittest suite checks dated data,
deduplication, invalid values, configuration preservation, failure rollback,
idempotency and protection of later edits. Local staged apply uses a simulated HA
validation response; it is not a claim of production restart testing on all OSes.
Python is portable; wrappers are platform entry points, not three HA distributions.
