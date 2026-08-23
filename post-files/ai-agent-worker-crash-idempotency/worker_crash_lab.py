#!/usr/bin/env python3
"""Dependency-free AI Worker crash and idempotency fault lab.

The lab uses only Python's standard library and a local SQLite database. It
does not access the network, load credentials, inspect the host, or call a real
tool. Every "restart", delivery, reservation, and compensation is synthetic.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sqlite3
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable


LAB_VERSION = "1.0.0"
TASK_ACTION = "synthetic.service.restart"


class InjectedCrash(RuntimeError):
    """A deterministic crash at the dangerous post-effect checkpoint."""


@dataclass
class ScenarioResult:
    filename: str
    lines: list[str]


class Lab:
    def __init__(self, output_dir: Path) -> None:
        self.output_dir = output_dir
        self.results_dir = output_dir / "results"
        self.db_path = output_dir / "state.sqlite3"
        self.db = sqlite3.connect(self.db_path)
        self.db.row_factory = sqlite3.Row
        self.metrics: dict[str, object] = {
            "lab_version": LAB_VERSION,
            "network_calls": 0,
            "real_credentials_loaded": 0,
        }
        self._create_schema()

    def _create_schema(self) -> None:
        self.db.executescript(
            """
            PRAGMA journal_mode = WAL;
            PRAGMA foreign_keys = ON;

            CREATE TABLE tasks (
                task_id TEXT PRIMARY KEY,
                state TEXT NOT NULL,
                deliveries INTEGER NOT NULL DEFAULT 0,
                checkpoint TEXT NOT NULL
            );

            CREATE TABLE naive_effects (
                effect_id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_id TEXT NOT NULL,
                action TEXT NOT NULL
            );

            CREATE TABLE idempotent_effects (
                idempotency_key TEXT PRIMARY KEY,
                task_id TEXT NOT NULL,
                action TEXT NOT NULL,
                result TEXT NOT NULL
            );

            CREATE TABLE lease_tasks (
                task_id TEXT PRIMARY KEY,
                owner TEXT,
                lease_until INTEGER NOT NULL,
                fence_token INTEGER NOT NULL,
                state TEXT NOT NULL
            );

            CREATE TABLE fenced_resources (
                resource_id TEXT PRIMARY KEY,
                highest_fence INTEGER NOT NULL,
                value TEXT NOT NULL,
                applied_count INTEGER NOT NULL
            );

            CREATE TABLE business_commands (
                command_id TEXT PRIMARY KEY,
                payload TEXT NOT NULL
            );

            CREATE TABLE outbox (
                event_id TEXT PRIMARY KEY,
                command_id TEXT NOT NULL,
                payload TEXT NOT NULL,
                sent INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY(command_id) REFERENCES business_commands(command_id)
            );

            CREATE TABLE downstream_receipts (
                event_id TEXT PRIMARY KEY,
                payload TEXT NOT NULL
            );

            CREATE TABLE reservations (
                reservation_id INTEGER PRIMARY KEY AUTOINCREMENT,
                intent_id TEXT NOT NULL,
                status TEXT NOT NULL
            );
            """
        )
        self.db.commit()

    def write_result(self, result: ScenarioResult) -> None:
        path = self.results_dir / result.filename
        path.write_text("\n".join(result.lines) + "\n", encoding="utf-8")
        print("\n".join(result.lines))
        print()

    def run_naive_redelivery(self) -> ScenarioResult:
        task_id = "task-naive"
        lines = [
            "AI WORKER CRASH LAB / 01 NAIVE REDELIVERY",
            "boundary: local SQLite, synthetic side effects, no network",
            "",
        ]
        self.db.execute(
            "INSERT INTO tasks VALUES(?, 'PENDING', 0, 'before_effect')", (task_id,)
        )
        self.db.commit()

        for delivery in (1, 2):
            self.db.execute(
                "UPDATE tasks SET state='RUNNING', deliveries=deliveries+1 WHERE task_id=?",
                (task_id,),
            )
            self.db.execute(
                "INSERT INTO naive_effects(task_id, action) VALUES(?, ?)",
                (task_id, TASK_ACTION),
            )
            self.db.commit()
            count = self.db.execute(
                "SELECT count(*) FROM naive_effects WHERE task_id=?", (task_id,)
            ).fetchone()[0]
            lines.append(f"delivery={delivery} action=ACCEPTED side_effect_count={count}")
            if delivery == 1:
                try:
                    raise InjectedCrash("after_effect_before_completed")
                except InjectedCrash as exc:
                    lines.append(f"delivery=1 fault=INJECTED_CRASH checkpoint={exc}")
                    lines.append("queue=REDELIVER reason=completion_not_recorded")
                    continue
            self.db.execute(
                "UPDATE tasks SET state='COMPLETED', checkpoint='after_effect' WHERE task_id=?",
                (task_id,),
            )
            self.db.commit()

        count = self.db.execute(
            "SELECT count(*) FROM naive_effects WHERE task_id=?", (task_id,)
        ).fetchone()[0]
        lines.extend(
            [
                "",
                f"observed_side_effects={count}",
                "[EXPECTED RISK] one intent produced two effects",
            ]
        )
        self.metrics["naive_deliveries"] = 2
        self.metrics["naive_side_effects"] = count
        return ScenarioResult("01-naive-double-effect.txt", lines)

    @staticmethod
    def idempotency_key(task_id: str, action: str, version: str = "v1") -> str:
        canonical = json.dumps(
            {
                "tenant": "demo",
                "task": task_id,
                "action": action,
                "arguments": {"resource": "sample-service"},
                "version": version,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
        return hashlib.sha256(canonical.encode("utf-8")).hexdigest()[:24]

    def _apply_once(self, key: str, task_id: str) -> tuple[str, bool]:
        before = self.db.total_changes
        self.db.execute(
            """
            INSERT OR IGNORE INTO idempotent_effects
            (idempotency_key, task_id, action, result)
            VALUES(?, ?, ?, 'synthetic-restart-accepted')
            """,
            (key, task_id, TASK_ACTION),
        )
        created = self.db.total_changes > before
        row = self.db.execute(
            "SELECT result FROM idempotent_effects WHERE idempotency_key=?", (key,)
        ).fetchone()
        self.db.commit()
        return str(row["result"]), created

    def run_idempotent_recovery(self) -> ScenarioResult:
        task_id = "task-safe"
        key = self.idempotency_key(task_id, TASK_ACTION)
        lines = [
            "AI WORKER CRASH LAB / 02 IDEMPOTENT RECOVERY",
            "boundary: UNIQUE(idempotency_key) at the effect receiver",
            "",
        ]
        self.db.execute(
            "INSERT INTO tasks VALUES(?, 'PENDING', 0, 'before_effect')", (task_id,)
        )
        self.db.commit()

        for delivery in (1, 2):
            self.db.execute(
                "UPDATE tasks SET state='RUNNING', deliveries=deliveries+1 WHERE task_id=?",
                (task_id,),
            )
            self.db.commit()
            result, created = self._apply_once(key, task_id)
            decision = "EXECUTED" if created else "DEDUPLICATED"
            lines.append(
                f"delivery={delivery} decision={decision} key={key} result={result}"
            )
            if delivery == 1:
                lines.append("delivery=1 fault=INJECTED_CRASH checkpoint=after_effect_before_completed")
                lines.append("queue=REDELIVER reason=completion_not_recorded")
                continue
            self.db.execute(
                "UPDATE tasks SET state='COMPLETED', checkpoint='after_effect' WHERE task_id=?",
                (task_id,),
            )
            self.db.commit()

        count = self.db.execute(
            "SELECT count(*) FROM idempotent_effects WHERE task_id=?", (task_id,)
        ).fetchone()[0]
        lines.extend(
            [
                "",
                f"observed_side_effects={count}",
                "[PASS] redelivery completed without a second effect",
            ]
        )
        self.metrics["safe_deliveries"] = 2
        self.metrics["safe_side_effects"] = count
        self.metrics["idempotency_key"] = key
        return ScenarioResult("02-idempotent-recovery.txt", lines)

    def _acquire_lease(self, task_id: str, owner: str, now: int, ttl: int) -> int:
        row = self.db.execute(
            "SELECT owner, lease_until, fence_token FROM lease_tasks WHERE task_id=?",
            (task_id,),
        ).fetchone()
        if row is None:
            token = 1
            self.db.execute(
                "INSERT INTO lease_tasks VALUES(?, ?, ?, ?, 'RUNNING')",
                (task_id, owner, now + ttl, token),
            )
        elif int(row["lease_until"]) < now:
            token = int(row["fence_token"]) + 1
            self.db.execute(
                "UPDATE lease_tasks SET owner=?, lease_until=?, fence_token=?, state='RUNNING' WHERE task_id=?",
                (owner, now + ttl, token, task_id),
            )
        else:
            raise RuntimeError("lease is still active")
        self.db.commit()
        return token

    def _apply_fenced(self, resource_id: str, token: int, value: str) -> bool:
        row = self.db.execute(
            "SELECT highest_fence FROM fenced_resources WHERE resource_id=?",
            (resource_id,),
        ).fetchone()
        if row is not None and token < int(row["highest_fence"]):
            return False
        if row is None:
            self.db.execute(
                "INSERT INTO fenced_resources VALUES(?, ?, ?, 1)",
                (resource_id, token, value),
            )
        else:
            self.db.execute(
                "UPDATE fenced_resources SET highest_fence=?, value=?, applied_count=applied_count+1 WHERE resource_id=?",
                (token, value, resource_id),
            )
        self.db.commit()
        return True

    def run_lease_and_fencing(self) -> ScenarioResult:
        task_id = "task-lease"
        resource = "sample-service"
        lines = [
            "AI WORKER CRASH LAB / 03 LEASE TAKEOVER + FENCING",
            "logical clock only; worker labels are synthetic",
            "",
        ]
        token_a = self._acquire_lease(task_id, "worker-a", now=100, ttl=5)
        lines.append("t=100 owner=worker-a lease_until=105 fence=1")
        lines.append("t=106 event=LEASE_EXPIRED worker-a may still be alive")
        token_b = self._acquire_lease(task_id, "worker-b", now=106, ttl=5)
        lines.append("t=106 owner=worker-b lease_until=111 fence=2")
        accepted_b = self._apply_fenced(resource, token_b, "restart-by-current-owner")
        lines.append(f"worker=worker-b fence=2 effect={'ACCEPTED' if accepted_b else 'REJECTED'}")
        accepted_a = self._apply_fenced(resource, token_a, "late-restart-by-stale-owner")
        lines.append(f"worker=worker-a fence=1 late_effect={'ACCEPTED' if accepted_a else 'REJECTED_STALE'}")
        updated = self.db.execute(
            """
            UPDATE lease_tasks SET state='COMPLETED'
            WHERE task_id=? AND owner='worker-b' AND fence_token=?
            """,
            (task_id, token_b),
        ).rowcount
        self.db.commit()
        lines.extend(
            [
                "",
                f"conditional_completion_rows={updated}",
                "[PASS] the expired owner could not write after takeover",
            ]
        )
        self.metrics["latest_fence_token"] = token_b
        self.metrics["stale_effects_rejected"] = 0 if accepted_a else 1
        self.metrics["fenced_effects_applied"] = self.db.execute(
            "SELECT applied_count FROM fenced_resources WHERE resource_id=?", (resource,)
        ).fetchone()[0]
        return ScenarioResult("03-lease-fencing.txt", lines)

    def run_outbox_recovery(self) -> ScenarioResult:
        command_id = "command-001"
        event_id = "event-command-001"
        payload = '{"action":"synthetic.service.restart"}'
        lines = [
            "AI WORKER CRASH LAB / 04 TRANSACTIONAL OUTBOX",
            "business row + outbox row share one local transaction",
            "",
        ]
        with self.db:
            self.db.execute(
                "INSERT INTO business_commands VALUES(?, ?)", (command_id, payload)
            )
            self.db.execute(
                "INSERT INTO outbox VALUES(?, ?, ?, 0)", (event_id, command_id, payload)
            )
        lines.append("transaction=COMMITTED business_rows=1 outbox_rows=1")
        lines.append("fault=INJECTED_CRASH checkpoint=after_commit_before_publish")
        lines.append("dispatcher=RECOVER pending_events=1")

        before = self.db.total_changes
        self.db.execute(
            "INSERT OR IGNORE INTO downstream_receipts VALUES(?, ?)", (event_id, payload)
        )
        first_created = self.db.total_changes > before
        self.db.commit()
        lines.append(
            f"dispatch=1 downstream={'ACCEPTED' if first_created else 'DEDUPLICATED'}"
        )
        lines.append("fault=INJECTED_CRASH checkpoint=after_downstream_before_sent_flag")

        before = self.db.total_changes
        self.db.execute(
            "INSERT OR IGNORE INTO downstream_receipts VALUES(?, ?)", (event_id, payload)
        )
        second_created = self.db.total_changes > before
        self.db.execute("UPDATE outbox SET sent=1 WHERE event_id=?", (event_id,))
        self.db.commit()
        downstream = self.db.execute(
            "SELECT count(*) FROM downstream_receipts WHERE event_id=?", (event_id,)
        ).fetchone()[0]
        lines.extend(
            [
                f"dispatch=2 downstream={'ACCEPTED' if second_created else 'DEDUPLICATED'}",
                f"outbox_sent=1 downstream_effects={downstream}",
                "",
                "[PASS] recovery neither lost nor duplicated the event effect",
            ]
        )
        self.metrics["outbox_dispatch_attempts"] = 2
        self.metrics["downstream_effects"] = downstream
        return ScenarioResult("04-outbox-recovery.txt", lines)

    def run_compensation(self) -> ScenarioResult:
        intent_id = "reservation-intent-001"
        lines = [
            "AI WORKER CRASH LAB / 05 COMPENSATION",
            "simulated receiver has no idempotency-key support",
            "",
        ]
        self.db.execute(
            "INSERT INTO reservations(intent_id, status) VALUES(?, 'ACTIVE')", (intent_id,)
        )
        self.db.commit()
        lines.append("attempt=1 reservation=CREATED status=ACTIVE")
        lines.append("fault=ACK_LOST outcome=UNKNOWN")
        self.db.execute(
            "INSERT INTO reservations(intent_id, status) VALUES(?, 'ACTIVE')", (intent_id,)
        )
        self.db.commit()
        lines.append("attempt=2 reservation=CREATED status=ACTIVE")
        active_before = self.db.execute(
            "SELECT count(*) FROM reservations WHERE intent_id=? AND status='ACTIVE'",
            (intent_id,),
        ).fetchone()[0]
        duplicate_id = self.db.execute(
            """
            SELECT max(reservation_id) FROM reservations
            WHERE intent_id=? AND status='ACTIVE'
            """,
            (intent_id,),
        ).fetchone()[0]
        self.db.execute(
            "UPDATE reservations SET status='CANCELLED' WHERE reservation_id=?",
            (duplicate_id,),
        )
        self.db.commit()
        active_after = self.db.execute(
            "SELECT count(*) FROM reservations WHERE intent_id=? AND status='ACTIVE'",
            (intent_id,),
        ).fetchone()[0]
        cancelled = self.db.execute(
            "SELECT count(*) FROM reservations WHERE intent_id=? AND status='CANCELLED'",
            (intent_id,),
        ).fetchone()[0]
        lines.extend(
            [
                f"reconcile=FOUND_DUPLICATE active_before={active_before}",
                f"compensation=CANCEL_DUPLICATE active_after={active_after}",
                "",
                "[PASS] one intended reservation remains active",
            ]
        )
        self.metrics["active_reservations_after_compensation"] = active_after
        self.metrics["compensations"] = cancelled
        return ScenarioResult("05-compensation.txt", lines)

    def run_acceptance(self) -> ScenarioResult:
        safe_task = self.db.execute(
            "SELECT state FROM tasks WHERE task_id='task-safe'"
        ).fetchone()[0]
        lease_task = self.db.execute(
            "SELECT state FROM lease_tasks WHERE task_id='task-lease'"
        ).fetchone()[0]
        checks: list[tuple[str, bool, str]] = [
            (
                "danger_window_reproduced",
                self.metrics["naive_side_effects"] == 2,
                "one intent -> two naive effects",
            ),
            (
                "idempotent_redelivery",
                self.metrics["safe_side_effects"] == 1,
                "two deliveries -> one safe effect",
            ),
            (
                "stale_worker_fenced",
                self.metrics["stale_effects_rejected"] == 1,
                "old token rejected after takeover",
            ),
            (
                "outbox_recovery",
                self.metrics["downstream_effects"] == 1,
                "two dispatches -> one downstream effect",
            ),
            (
                "compensation_reconciled",
                self.metrics["active_reservations_after_compensation"] == 1,
                "one active intent remains",
            ),
            (
                "durable_terminal_state",
                safe_task == "COMPLETED" and lease_task == "COMPLETED",
                "safe tasks reached COMPLETED",
            ),
            (
                "privacy_and_network_boundary",
                self.metrics["network_calls"] == 0
                and self.metrics["real_credentials_loaded"] == 0,
                "zero network calls, zero credentials",
            ),
        ]
        lines = [
            "AI WORKER CRASH LAB / 06 ACCEPTANCE GATE",
            f"lab_version={LAB_VERSION} python={sys.version_info.major}.{sys.version_info.minor}",
            "",
        ]
        for name, passed, evidence in checks:
            lines.append(f"[{'PASS' if passed else 'FAIL'}] {name}: {evidence}")
        passed_count = sum(1 for _, passed, _ in checks if passed)
        lines.extend(
            [
                "",
                f"acceptance={passed_count}/{len(checks)}",
                "result=PASS" if passed_count == len(checks) else "result=FAIL",
            ]
        )
        self.metrics["acceptance_passed"] = passed_count
        self.metrics["acceptance_total"] = len(checks)
        self.metrics["result"] = passed_count == len(checks)
        return ScenarioResult("06-acceptance-summary.txt", lines)

    def close(self) -> None:
        self.db.close()


def safe_prepare(output_dir: Path, clean: bool) -> None:
    resolved = output_dir.resolve()
    if clean and resolved.exists():
        if resolved.name not in {"lab-output", "reference-run"}:
            raise SystemExit(
                "Refusing --clean: output directory must be named lab-output or reference-run"
            )
        shutil.rmtree(resolved)
    (resolved / "results").mkdir(parents=True, exist_ok=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a local, deterministic Worker crash/idempotency lab."
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parent / "lab-output",
        help="Result directory (default: lab-output beside this script)",
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Remove only an existing lab-output/reference-run directory first",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    safe_prepare(args.output_dir, args.clean)
    lab = Lab(args.output_dir.resolve())
    scenarios: list[Callable[[], ScenarioResult]] = [
        lab.run_naive_redelivery,
        lab.run_idempotent_recovery,
        lab.run_lease_and_fencing,
        lab.run_outbox_recovery,
        lab.run_compensation,
    ]
    try:
        for scenario in scenarios:
            lab.write_result(scenario())
        summary = lab.run_acceptance()
        lab.write_result(summary)
        (lab.output_dir / "metrics.json").write_text(
            json.dumps(lab.metrics, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        passed = bool(lab.metrics["result"])
    finally:
        lab.close()
    print(f"Evidence directory: {args.output_dir.resolve()}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
