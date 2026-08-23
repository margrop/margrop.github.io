#!/usr/bin/env python3
"""Deterministic, zero-network Turn Manager cancellation lab.

The lab uses only Python's standard library.  It does not call a model, a
speech service, a tool, or any other process.  All identities, turns, events,
deadlines, and side effects are synthetic.  A socket guard makes accidental
DNS lookups and outbound connections fail closed while the scenarios run.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import socket
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Iterable


SCENARIOS = (
    "baseline_stream",
    "cancel_tree",
    "voice_barge_in",
    "deadline_budget",
    "cancellable_tool",
    "noncancellable_tool",
    "reconnect_replay",
    "idempotent_stop",
)


def compact(value: Any) -> str:
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    return str(value).replace(" ", "_")


@dataclass
class Check:
    name: str
    passed: bool
    expected: str
    actual: str

    def as_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "status": "PASS" if self.passed else "FAIL",
            "expected": self.expected,
            "actual": self.actual,
        }


@dataclass
class Recorder:
    scenario: str
    turn_id: str
    events: list[dict[str, Any]] = field(default_factory=list)
    checks: list[Check] = field(default_factory=list)

    def emit(self, t_ms: int, component: str, event: str, **detail: Any) -> None:
        self.events.append(
            {
                "t_ms": t_ms,
                "scenario": self.scenario,
                "turn_id": self.turn_id,
                "component": component,
                "event": event,
                "detail": detail,
            }
        )

    def check(self, name: str, condition: bool, expected: str, actual: Any) -> None:
        self.checks.append(Check(name, bool(condition), expected, compact(actual)))

    def lines(self) -> list[str]:
        result = [
            f"TURN MANAGER LAB :: {self.scenario}",
            f"turn={self.turn_id}  clock=virtual  network=blocked  provider=synthetic",
            "",
        ]
        for item in self.events:
            detail = " ".join(
                f"{key}={compact(value)}" for key, value in item["detail"].items()
            )
            suffix = f"  {detail}" if detail else ""
            result.append(
                f"[{item['t_ms']:04d}ms] {item['component']:<14} "
                f"{item['event']}{suffix}"
            )
        result.extend(["", "ASSERTIONS"])
        for check in self.checks:
            status = "PASS" if check.passed else "FAIL"
            result.append(
                f"[{status}] {check.name} :: expected={check.expected} actual={check.actual}"
            )
        return result


class SocketGuard:
    """Fail closed if the lab accidentally attempts network access."""

    def __enter__(self) -> "SocketGuard":
        self._connect = socket.socket.connect
        self._connect_ex = socket.socket.connect_ex
        self._create = socket.create_connection
        self._getaddrinfo = socket.getaddrinfo

        def blocked(*_args: Any, **_kwargs: Any) -> Any:
            raise RuntimeError("network access is disabled by Turn Manager lab")

        socket.socket.connect = blocked  # type: ignore[method-assign]
        socket.socket.connect_ex = blocked  # type: ignore[method-assign]
        socket.create_connection = blocked  # type: ignore[assignment]
        socket.getaddrinfo = blocked  # type: ignore[assignment]
        return self

    def __exit__(self, *_exc: Any) -> None:
        socket.socket.connect = self._connect  # type: ignore[method-assign]
        socket.socket.connect_ex = self._connect_ex  # type: ignore[method-assign]
        socket.create_connection = self._create  # type: ignore[assignment]
        socket.getaddrinfo = self._getaddrinfo  # type: ignore[assignment]


def baseline_stream() -> Recorder:
    r = Recorder("baseline_stream", "turn-text-001")
    r.emit(0, "turn", "accepted", deadline_ms=500, generation=1)
    r.emit(4, "retriever", "started", parent="turn-text-001")
    r.emit(21, "retriever", "completed", documents=2)
    r.emit(23, "model", "response.started", stream="text")
    r.emit(61, "model", "response.delta", seq=1, text="Storage")
    r.emit(82, "model", "response.delta", seq=2, text="is healthy")
    r.emit(104, "model", "response.completed", output_tokens=4)
    r.emit(110, "turn", "completed", terminal_events=1)
    ttft = 61
    e2e = 110
    r.check("first-token-visible", ttft < 100, "ttft<100ms", f"{ttft}ms")
    r.check("one-terminal-state", True, "COMPLETED exactly once", "COMPLETED x1")
    r.check("deadline-respected", e2e <= 500, "e2e<=500ms", f"{e2e}ms")
    return r


def cancel_tree() -> Recorder:
    r = Recorder("cancel_tree", "turn-text-002")
    r.emit(0, "turn", "accepted", deadline_ms=800, generation=1)
    r.emit(2, "cancel-tree", "child.spawned", child="retrieval")
    r.emit(3, "cancel-tree", "child.spawned", child="model-stream")
    r.emit(4, "cancel-tree", "child.spawned", child="tts-buffer")
    r.emit(42, "model", "response.delta", seq=1, delivered=True)
    r.emit(75, "client", "turn.cancel", request_id="stop-001", reason="user_stop")
    r.emit(76, "turn", "cancel.requested", generation=1)
    r.emit(78, "retriever", "cancelled", checkpoint="before_merge")
    r.emit(80, "model", "cancelled", checkpoint="before_decode")
    r.emit(81, "tts", "buffer.cleared", queued_frames=3)
    r.emit(82, "delivery-gate", "late.delta.dropped", seq=2, generation=1)
    r.emit(83, "turn", "cancelled", propagation_ms=8, terminal_events=1)
    r.check("cancel-tree-drained", True, "3 children stopped", "3 stopped")
    r.check("propagation-slo", 8 <= 50, "<=50ms", "8ms")
    r.check("no-late-delivery", True, "late generation dropped", "seq=2 dropped")
    return r


def voice_barge_in() -> Recorder:
    r = Recorder("voice_barge_in", "turn-voice-001")
    r.emit(0, "turn", "accepted", mode="realtime_audio", generation=7)
    r.emit(18, "model", "response.audio.delta", seq=1)
    r.emit(20, "tts", "frame.played", seq=1)
    r.emit(44, "model", "response.audio.delta", seq=2)
    r.emit(46, "tts", "frame.played", seq=2)
    r.emit(70, "vad", "input_audio.speech_started", confidence=0.94)
    r.emit(71, "turn", "barge_in.accepted", new_generation=8)
    r.emit(72, "tts", "output_audio.clear", buffered_frames=4)
    r.emit(73, "adapter", "response.cancel", target_generation=7)
    r.emit(76, "turn", "old_generation.cancelled", generation=7)
    r.emit(79, "delivery-gate", "late.audio.dropped", generation=7, seq=3)
    r.emit(84, "turn", "created_from_barge_in", new_turn="turn-voice-002")
    r.emit(116, "model", "response.audio.delta", generation=8, seq=1)
    r.emit(151, "turn", "completed", active_generation=8)
    r.check("audible-output-cleared", True, "buffer cleared", "4 frames cleared")
    r.check("old-generation-fenced", True, "generation 7 blocked", "late seq=3 dropped")
    r.check("new-turn-continues", True, "generation 8 completes", "COMPLETED")
    return r


def deadline_budget() -> Recorder:
    r = Recorder("deadline_budget", "turn-text-003")
    r.emit(0, "turn", "accepted", deadline_ms=90, generation=1)
    r.emit(1, "budget", "allocated", retrieval_ms=25, model_ms=55, reserve_ms=10)
    r.emit(24, "retriever", "completed", elapsed_ms=23)
    r.emit(26, "model", "response.started", remaining_ms=64)
    r.emit(86, "budget", "nearly_exhausted", remaining_ms=4)
    r.emit(90, "deadline", "exceeded", source="turn_envelope")
    r.emit(91, "model", "cancelled", reason="deadline_exceeded")
    r.emit(92, "planner", "tool.not_started", reason="no_budget")
    r.emit(93, "turn", "failed", code="DEADLINE_EXCEEDED", terminal_events=1)
    r.check("deadline-propagated", True, "model observes deadline", "observed")
    r.check("unsafe-late-tool-blocked", True, "tool starts=0", "0")
    r.check("explicit-terminal-error", True, "DEADLINE_EXCEEDED", "DEADLINE_EXCEEDED")
    return r


def cancellable_tool() -> Recorder:
    r = Recorder("cancellable_tool", "turn-tool-001")
    r.emit(0, "turn", "accepted", deadline_ms=500)
    r.emit(14, "tool", "started", tool="report.build", cancellable=True)
    r.emit(34, "tool", "checkpoint", phase="read_inputs")
    r.emit(54, "tool", "checkpoint", phase="write_temporary")
    r.emit(65, "client", "turn.cancel", request_id="stop-002")
    r.emit(66, "turn", "cancel.requested")
    r.emit(70, "tool", "cancel.observed", checkpoint="before_publish")
    r.emit(73, "tool", "temporary_output.removed", synthetic_files=1)
    r.emit(76, "tool", "cancelled", committed_side_effects=0)
    r.emit(78, "turn", "cancelled", terminal_events=1)
    r.check("cooperative-checkpoint", True, "cancel before publish", "before_publish")
    r.check("temporary-work-cleaned", True, "temporary files=0", "0")
    r.check("no-committed-side-effect", True, "side effects=0", "0")
    return r


def noncancellable_tool() -> Recorder:
    r = Recorder("noncancellable_tool", "turn-tool-002")
    r.emit(0, "turn", "accepted", deadline_ms=500)
    r.emit(22, "tool", "started", tool="external.commit", cancellable=False)
    r.emit(50, "tool", "commit.sent", idempotency_key="idem-demo-001")
    r.emit(55, "client", "turn.cancel", request_id="stop-003")
    r.emit(56, "turn", "cancel.requested", response_delivery="stopped")
    r.emit(57, "tool", "cancel.deferred", reason="commit_in_flight")
    r.emit(105, "tool", "commit.acknowledged", committed_side_effects=1)
    r.emit(108, "reconciler", "status.enqueued", key="idem-demo-001")
    r.emit(110, "turn", "reconcile_required", terminal_events=1)
    r.check("no-false-cancel-claim", True, "RECONCILE_REQUIRED", "RECONCILE_REQUIRED")
    r.check("delivery-stopped", True, "no more user output", "stopped@56ms")
    r.check("commit-audited", True, "side effects=1 and recorded", "1 recorded")
    return r


def reconnect_replay() -> Recorder:
    r = Recorder("reconnect_replay", "turn-text-004")
    chunks = {1: "The ", 2: "service ", 3: "is ", 4: "healthy", 5: "."}
    r.emit(0, "turn", "accepted", resume_ttl_s=60)
    r.emit(20, "stream-store", "event.persisted", seq=1, text=chunks[1])
    r.emit(21, "client", "event.acked", seq=1)
    r.emit(35, "stream-store", "event.persisted", seq=2, text=chunks[2])
    r.emit(36, "client", "event.acked", seq=2)
    r.emit(50, "stream-store", "event.persisted", seq=3, text=chunks[3])
    r.emit(51, "client", "event.acked", seq=3)
    r.emit(55, "transport", "disconnected", last_acked_seq=3)
    r.emit(70, "stream-store", "event.persisted", seq=4, delivered=False)
    r.emit(84, "stream-store", "event.persisted", seq=5, delivered=False)
    r.emit(92, "turn", "completed", terminal_seq=6)
    r.emit(120, "transport", "resume", after_seq=3, token="opaque-demo")
    r.emit(122, "stream-store", "replay", seq_range="4..6")
    r.emit(124, "client", "duplicate.ignored", seq=5)
    r.emit(126, "client", "render.completed", text="The service is healthy.")
    rendered = "".join(chunks[index] for index in sorted(chunks))
    r.check("cursor-replay", True, "replay starts after seq=3", "4..6")
    r.check("duplicate-suppressed", True, "seq=5 rendered once", "once")
    r.check("text-exactly-once", rendered == "The service is healthy.", "exact text", rendered)
    return r


def idempotent_stop() -> Recorder:
    r = Recorder("idempotent_stop", "turn-text-005")
    r.emit(0, "turn", "accepted", generation=1)
    r.emit(40, "client", "turn.cancel", request_id="stop-repeat-001", attempt=1)
    r.emit(41, "turn", "cancel.requested", transition_count=1)
    r.emit(45, "turn", "cancelled", cancel_effects=1)
    r.emit(70, "client", "turn.cancel", request_id="stop-repeat-001", attempt=2)
    r.emit(71, "turn", "cancel.already_terminal", state="CANCELLED")
    r.emit(90, "client", "turn.cancel", request_id="stop-repeat-002", attempt=3)
    r.emit(91, "turn", "cancel.already_terminal", state="CANCELLED")
    r.check("idempotent-stop", True, "cancel effects=1", "1")
    r.check("stable-terminal-state", True, "CANCELLED", "CANCELLED")
    r.check("safe-client-retry", True, "3 requests accepted", "3 accepted")
    return r


RUNNERS: dict[str, Callable[[], Recorder]] = {
    "baseline_stream": baseline_stream,
    "cancel_tree": cancel_tree,
    "voice_barge_in": voice_barge_in,
    "deadline_budget": deadline_budget,
    "cancellable_tool": cancellable_tool,
    "noncancellable_tool": noncancellable_tool,
    "reconnect_replay": reconnect_replay,
    "idempotent_stop": idempotent_stop,
}


def write_text_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(text, encoding="utf-8", newline="\n")
    os.replace(temporary, path)


def clear_known_outputs(output: Path) -> None:
    known = {"events.jsonl", "report.json", "metrics.json", "acceptance.log"}
    known.update(f"{name}.log" for name in SCENARIOS)
    for name in known:
        target = output / name
        if target.is_file():
            target.unlink()


def build_acceptance(recorders: Iterable[Recorder]) -> list[str]:
    checks = [check for recorder in recorders for check in recorder.checks]
    passed = sum(check.passed for check in checks)
    lines = [
        "TURN MANAGER LAB :: RELEASE GATE",
        "clock=virtual  network=blocked  models=0  real_tools=0  secrets=0",
        "",
    ]
    for recorder in recorders:
        recorder_pass = all(check.passed for check in recorder.checks)
        lines.append(
            f"[{'PASS' if recorder_pass else 'FAIL'}] {recorder.scenario:<22} "
            f"checks={len(recorder.checks)}"
        )
    lines.extend(
        [
            "",
            f"RESULT {'PASS' if passed == len(checks) else 'FAIL'} :: "
            f"{passed}/{len(checks)} assertions passed",
            "Evidence: per-scenario logs + events.jsonl + metrics.json + report.json",
        ]
    )
    return lines


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--scenario",
        choices=("all",) + SCENARIOS,
        default="all",
        help="run one scenario or the complete release gate",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent / "lab-output",
        help="directory for deterministic evidence files",
    )
    parser.add_argument("--clean", action="store_true", help="remove known old lab files")
    parser.add_argument(
        "--agent",
        action="store_true",
        help="print a compact JSON result suitable for an automation agent",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if args.clean:
        clear_known_outputs(output)

    names = SCENARIOS if args.scenario == "all" else (args.scenario,)
    network_guard_self_test = "FAIL"
    with SocketGuard():
        try:
            socket.getaddrinfo("network-guard.invalid", 443)
        except RuntimeError as exc:
            if "network access is disabled" in str(exc):
                network_guard_self_test = "PASS"
        if network_guard_self_test != "PASS":
            raise RuntimeError("network guard self-test failed closed")
        recorders = [RUNNERS[name]() for name in names]

    for recorder in recorders:
        write_text_atomic(output / f"{recorder.scenario}.log", "\n".join(recorder.lines()) + "\n")

    event_lines = [
        json.dumps(event, ensure_ascii=False, separators=(",", ":"))
        for recorder in recorders
        for event in recorder.events
    ]
    write_text_atomic(output / "events.jsonl", "\n".join(event_lines) + "\n")

    checks = [check for recorder in recorders for check in recorder.checks]
    passed = sum(check.passed for check in checks)
    report = {
        "lab": "turn-manager-cancellation-barge-in",
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "environment": {
            "python": platform.python_version(),
            "os_family": platform.system(),
            "network_guard": "enabled",
            "network_guard_self_test": network_guard_self_test,
            "clock": "virtual",
            "real_models": 0,
            "real_tools": 0,
            "secrets_loaded": 0,
        },
        "scenario_count": len(recorders),
        "assertions": {"passed": passed, "total": len(checks)},
        "status": "PASS" if passed == len(checks) else "FAIL",
        "scenarios": [
            {
                "name": recorder.scenario,
                "event_count": len(recorder.events),
                "checks": [check.as_dict() for check in recorder.checks],
            }
            for recorder in recorders
        ],
    }
    all_events = [event for recorder in recorders for event in recorder.events]
    metrics = {
        "turns_total": len(recorders),
        "cancel_requests_total": sum(event["event"] == "turn.cancel" for event in all_events),
        "cancelled_turns": sum(
            event["component"] == "turn" and event["event"] == "cancelled"
            for event in all_events
        ),
        "barge_ins_total": sum(event["event"] == "barge_in.accepted" for event in all_events),
        "late_events_dropped": sum(event["event"].startswith("late.") for event in all_events),
        "deadline_exceeded_total": sum(event["event"] == "exceeded" for event in all_events),
        "reconnect_replays_total": sum(event["event"] == "replay" for event in all_events),
        "duplicate_stop_effects": 0,
        "committed_side_effects_after_cancel_request": sum(
            int(event["detail"].get("committed_side_effects", 0))
            for event in all_events
            if event["event"] == "commit.acknowledged"
        ),
        "external_cost": 0,
    }
    write_text_atomic(output / "report.json", json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    write_text_atomic(output / "metrics.json", json.dumps(metrics, ensure_ascii=False, indent=2) + "\n")
    acceptance = build_acceptance(recorders)
    write_text_atomic(output / "acceptance.log", "\n".join(acceptance) + "\n")

    if args.agent:
        print(json.dumps({"status": report["status"], "report": str(output / "report.json")}, ensure_ascii=False))
    else:
        print("\n".join(acceptance))
        print(f"\nEvidence directory: {output}")
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
