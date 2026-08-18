#!/usr/bin/env python3
from __future__ import annotations

import datetime
import json
import os
import re
import shutil
import sqlite3
import uuid
from pathlib import Path


QL_DATA = Path(os.environ.get("QL_DATA", "/tmp/ql2bh-migration-lab/qinglong-data"))
BH_DATA = Path(os.environ.get("BH_DATA", "/tmp/ql2bh-migration-lab/baihu-data"))


def newid() -> str:
    return uuid.uuid4().hex[:20]


def now_text() -> str:
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f+08:00")


def labels_to_names(raw: str | None) -> list[str]:
    if not raw:
        return []
    try:
        data = json.loads(raw)
    except Exception:
        return []
    names: list[str] = []
    if isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                name = item.get("name") or item.get("label") or item.get("value")
            else:
                name = str(item)
            if name and str(name).strip():
                names.append(str(name).strip())
    return names


def convert_command(cmd: str | None) -> str:
    cmd = (cmd or "").strip()
    if not cmd.startswith("task "):
        return cmd
    target = cmd[5:].strip().strip("\"'")
    rel = re.sub(r"^scripts/", "", target).lstrip("./")
    path = f"/app/data/scripts/qinglong-migrated/{rel}"
    if rel.endswith(".py"):
        return f"python {path}"
    if rel.endswith(".js"):
        return f"node {path}"
    if rel.endswith(".sh"):
        return f"bash {path}"
    return f"bash {path}"


def ensure_tag(db: sqlite3.Connection, tag_type: str, name: str, now: str) -> str:
    row = db.execute(
        "select id from baihu_data_storages where type=? and name=?",
        (tag_type, name),
    ).fetchone()
    if row:
        return row["id"]
    tag_id = newid()
    db.execute(
        "insert into baihu_data_storages(id,type,name,data,created_at,updated_at) values (?,?,?,?,?,?)",
        (tag_id, tag_type, name, "", now, now),
    )
    return tag_id


def main() -> None:
    preflight = {
        "ql_data": str(QL_DATA),
        "bh_data": str(BH_DATA),
        "ql_db": (QL_DATA / "db/database.sqlite").exists(),
        "bh_db": (BH_DATA / "baihu.db").exists(),
    }
    print("preflight", preflight)
    if not preflight["ql_db"] or not preflight["bh_db"]:
        raise SystemExit("missing QingLong or BaiHu SQLite database; check mounted data directories")

    backup = BH_DATA / f"baihu.db.before-ql2bh-{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}.bak"
    shutil.copy2(BH_DATA / "baihu.db", backup)
    print("backup", backup.name)

    src = QL_DATA / "scripts"
    dst = BH_DATA / "scripts/qinglong-migrated"
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns("*.log", "__pycache__", ".git"))
    print("scripts_copied", sum(1 for p in dst.rglob("*") if p.is_file()))

    now = now_text()
    ql = sqlite3.connect(QL_DATA / "db/database.sqlite")
    ql.row_factory = sqlite3.Row
    bh = sqlite3.connect(BH_DATA / "baihu.db")
    bh.row_factory = sqlite3.Row

    user = bh.execute("select id from baihu_users where role='admin' order by created_at limit 1").fetchone()
    if not user:
        raise SystemExit("no admin user in Baihu database")
    user_id = user["id"]

    bh.execute("delete from baihu_data_relations where data_id in (select id from baihu_tasks where source_id like 'ql2bh:%')")
    bh.execute("delete from baihu_data_relations where data_id in (select id from baihu_envs where remark like '%[ql2bh:%]')")
    bh.execute("delete from baihu_tasks where source_id like 'ql2bh:%'")
    bh.execute("delete from baihu_envs where remark like '%[ql2bh:%]'")
    bh.execute("delete from baihu_scripts where name like 'qinglong-migrated/%'")

    env_id_map: dict[str, str] = {}
    for row in ql.execute("select * from Envs order by position,id"):
        env_id = newid()
        env_id_map[str(row["id"])] = env_id
        remark = (row["remarks"] or "") + f" [ql2bh:env:{row['id']}]"
        enabled = 1 if (row["status"] or 0) == 0 else 0
        bh.execute(
            "insert into baihu_envs(id,name,value,remark,type,hidden,enabled,user_id,created_at,updated_at) values (?,?,?,?,?,?,?,?,?,?)",
            (env_id, row["name"], row["value"], remark, "normal", 1, enabled, user_id, now, now),
        )
        for tag in labels_to_names(row["labels"]):
            tag_id = ensure_tag(bh, "env_tag", tag, now)
            bh.execute(
                "insert into baihu_data_relations(id,data_id,relate_id,type,created_at,updated_at) values (?,?,?,?,?,?)",
                (newid(), env_id, tag_id, "env_tag", now, now),
            )

    for row in ql.execute("select * from Crontabs where ifnull(isSystem,0)=0 order by id"):
        task_id = newid()
        enabled = 0 if (row["isDisabled"] or 0) == 1 else 1
        config = json.dumps({"$task_all_envs": True, "$task_concurrency": 0}, ensure_ascii=False)
        bh.execute(
            "insert into baihu_tasks(id,name,remark,pin_type,command,pre_command,post_command,type,trigger_type,config,schedule,timeout,work_dir,clean_config,languages,agent_id,retry_count,retry_interval,random_range,enabled,running_go,last_run,next_run,source_id,repo_task_id,created_at,updated_at) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                task_id,
                row["name"] or f"ql-cron-{row['id']}",
                f"Migrated from QingLong cron {row['id']}",
                "none",
                convert_command(row["command"]),
                row["task_before"] or "",
                row["task_after"] or "",
                "task",
                "cron",
                config,
                row["schedule"] or "",
                30,
                "",
                "",
                "[]",
                None,
                0,
                0,
                0,
                enabled,
                "[]",
                None,
                None,
                f"ql2bh:cron:{row['id']}",
                "",
                now,
                now,
            ),
        )
        for env_id in env_id_map.values():
            bh.execute(
                "insert into baihu_data_relations(id,data_id,relate_id,type,created_at,updated_at) values (?,?,?,?,?,?)",
                (newid(), task_id, env_id, "task_env", now, now),
            )
        for tag in labels_to_names(row["labels"]):
            tag_id = ensure_tag(bh, "task_tag", tag, now)
            bh.execute(
                "insert into baihu_data_relations(id,data_id,relate_id,type,created_at,updated_at) values (?,?,?,?,?,?)",
                (newid(), task_id, tag_id, "task_tag", now, now),
            )

    for path in sorted(dst.rglob("*")):
        if not path.is_file():
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        rel = "qinglong-migrated/" + str(path.relative_to(dst))
        bh.execute(
            "insert into baihu_scripts(id,name,content,user_id,created_at,updated_at) values (?,?,?,?,?,?)",
            (newid(), rel, content, user_id, now, now),
        )

    bh.commit()
    summary = {
        "envs": bh.execute("select count(*) from baihu_envs where remark like '%[ql2bh:%]'").fetchone()[0],
        "tasks": bh.execute("select count(*) from baihu_tasks where source_id like 'ql2bh:%'").fetchone()[0],
        "script_records": bh.execute("select count(*) from baihu_scripts where name like 'qinglong-migrated/%'").fetchone()[0],
        "task_env_relations": bh.execute(
            "select count(*) from baihu_data_relations where type='task_env' and data_id in (select id from baihu_tasks where source_id like 'ql2bh:%')"
        ).fetchone()[0],
    }
    print("migration_summary", summary)
    bh.close()
    ql.close()


if __name__ == "__main__":
    main()
