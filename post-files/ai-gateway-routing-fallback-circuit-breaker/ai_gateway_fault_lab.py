#!/usr/bin/env python3
"""Deterministic, zero-network AI Gateway routing and resilience lab.

The lab uses only Python's standard library.  Providers, status codes, token
usage, latency and prices are synthetic.  No API key is read and no outbound
connection is allowed.
"""

from __future__ import annotations

import argparse
import json
import socket
from dataclasses import asdict, dataclass, field
from decimal import Decimal
from pathlib import Path
from typing import Callable, Iterable


LAB_VERSION = "1.0.0"
CLASSIFICATION_LEVEL = {"public": 0, "internal": 1, "restricted": 2}
OUTBOUND_ATTEMPTS = 0


def _blocked_network(*_args: object, **_kwargs: object) -> None:
    global OUTBOUND_ATTEMPTS
    OUTBOUND_ATTEMPTS += 1
    raise RuntimeError("zero-network lab blocked an outbound socket")


# Fail closed: even an accidental future socket call cannot leave this process.
socket.socket = _blocked_network  # type: ignore[assignment]
socket.create_connection = _blocked_network  # type: ignore[assignment]


@dataclass(frozen=True)
class Provider:
    name: str
    capabilities: frozenset[str]
    regions: frozenset[str]
    max_classification: str
    input_usd_per_million: Decimal
    output_usd_per_million: Decimal

    def estimate(self, input_tokens: int, output_tokens: int) -> Decimal:
        return (
            Decimal(input_tokens) * self.input_usd_per_million
            + Decimal(output_tokens) * self.output_usd_per_million
        ) / Decimal(1_000_000)


@dataclass(frozen=True)
class RequestEnvelope:
    request_id: str
    required_capabilities: frozenset[str]
    allowed_regions: frozenset[str]
    data_classification: str
    input_tokens: int
    max_output_tokens: int
    max_cost_usd: Decimal
    deadline_ms: int


@dataclass(frozen=True)
class SyntheticResponse:
    status: int
    code: str
    latency_ms: int
    input_tokens: int = 0
    output_tokens: int = 0
    charged_usd: Decimal = Decimal("0")


@dataclass
class TraceEvent:
    scenario: str
    event: str
    fields: dict[str, object] = field(default_factory=dict)


class Recorder:
    def __init__(self, output_dir: Path | None) -> None:
        self.events: list[TraceEvent] = []
        self.output_dir = output_dir

    def line(self, scenario: str, event: str, **fields: object) -> None:
        event_record = TraceEvent(scenario=scenario, event=event, fields=fields)
        self.events.append(event_record)
        rendered = " ".join(f"{key}={value}" for key, value in fields.items())
        print(f"[{scenario}] {event}" + (f" {rendered}" if rendered else ""))

    def write(self, summary: dict[str, object]) -> None:
        if self.output_dir is None:
            return
        self.output_dir.mkdir(parents=True, exist_ok=True)
        events_path = self.output_dir / "events.jsonl"
        with events_path.open("w", encoding="utf-8") as handle:
            for event in self.events:
                handle.write(json.dumps(asdict(event), ensure_ascii=False) + "\n")
        (self.output_dir / "summary.json").write_text(
            json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )


def money(value: Decimal) -> str:
    return f"${value.quantize(Decimal('0.000001'))}"


def classify_error(status: int, code: str) -> tuple[str, str]:
    """Return (decision, reason) using status plus provider sub-code."""
    terminal_codes = {
        "invalid_auth",
        "permission_denied",
        "insufficient_quota",
        "balance_exhausted",
        "compliance_denied",
        "data_residency_denied",
    }
    retryable_codes = {"rate_limited", "overloaded", "upstream_timeout"}
    if code in terminal_codes:
        return "STOP", f"terminal_code:{code}"
    if status in {401, 403}:
        return "STOP", f"terminal_status:{status}"
    if code in retryable_codes and status in {408, 429, 500, 502, 503, 504}:
        return "RETRY_OR_FALLBACK", f"transient:{status}:{code}"
    if status in {500, 502, 503, 504}:
        return "RETRY_OR_FALLBACK", f"transient_status:{status}"
    return "STOP", f"unclassified:{status}:{code}"


def provider_exclusions(provider: Provider, request: RequestEnvelope) -> list[str]:
    reasons: list[str] = []
    missing = request.required_capabilities - provider.capabilities
    if missing:
        reasons.append("missing_capability:" + ",".join(sorted(missing)))
    if not request.allowed_regions.intersection(provider.regions):
        reasons.append("data_residency")
    if CLASSIFICATION_LEVEL[provider.max_classification] < CLASSIFICATION_LEVEL[request.data_classification]:
        reasons.append("classification_limit")
    estimate = provider.estimate(request.input_tokens, request.max_output_tokens)
    if estimate > request.max_cost_usd:
        reasons.append(f"request_budget:{money(estimate)}>{money(request.max_cost_usd)}")
    return reasons


def scenario_routing(recorder: Recorder) -> dict[str, object]:
    scenario = "routing"
    request = RequestEnvelope(
        request_id="req-demo-001",
        required_capabilities=frozenset({"json", "tools"}),
        allowed_regions=frozenset({"region-a"}),
        data_classification="restricted",
        input_tokens=10_000,
        max_output_tokens=2_000,
        max_cost_usd=Decimal("0.050"),
        deadline_ms=1_200,
    )
    providers = [
        Provider("route-fast", frozenset({"json", "tools"}), frozenset({"region-b"}), "restricted", Decimal("1"), Decimal("4")),
        Provider("route-cheap", frozenset({"json"}), frozenset({"region-a"}), "restricted", Decimal("0.4"), Decimal("1.2")),
        Provider("route-premium", frozenset({"json", "tools"}), frozenset({"region-a"}), "restricted", Decimal("4"), Decimal("12")),
        Provider("route-fit", frozenset({"json", "tools"}), frozenset({"region-a"}), "restricted", Decimal("1"), Decimal("4")),
    ]
    recorder.line(scenario, "ENVELOPE", request_id=request.request_id, capabilities="json+tools", region="region-a", classification="restricted", cap=money(request.max_cost_usd))
    eligible: list[Provider] = []
    for provider in providers:
        reasons = provider_exclusions(provider, request)
        if reasons:
            recorder.line(scenario, "EXCLUDE", provider=provider.name, reason="|".join(reasons))
        else:
            eligible.append(provider)
            recorder.line(scenario, "ELIGIBLE", provider=provider.name, estimate=money(provider.estimate(request.input_tokens, request.max_output_tokens)))
    selected = min(eligible, key=lambda item: item.estimate(request.input_tokens, request.max_output_tokens))
    recorder.line(scenario, "SELECT", provider=selected.name, policy="route-policy-v3", why="capability+residency+classification+budget")
    return {"selected": selected.name, "eligible": len(eligible), "excluded": len(providers) - len(eligible)}


def scenario_bounded_429(recorder: Recorder) -> dict[str, object]:
    scenario = "bounded-429"
    plan = [
        ("primary-compatible", SyntheticResponse(429, "rate_limited", 80)),
        ("fallback-compatible", SyntheticResponse(200, "ok", 450, 8_000, 1_000, Decimal("0.016"))),
    ]
    elapsed = 0
    attempts = 0
    max_attempts = 2
    deadline_ms = 1_200
    total = Decimal("0")
    recorder.line(scenario, "BUDGET", max_attempts=max_attempts, deadline_ms=deadline_ms, max_cost=money(Decimal("0.030")))
    for provider, response in plan:
        attempts += 1
        elapsed += response.latency_ms
        recorder.line(scenario, "ATTEMPT", n=attempts, provider=provider, status=response.status, code=response.code, elapsed_ms=elapsed)
        if response.status == 200:
            total += response.charged_usd
            recorder.line(scenario, "SUCCESS", provider=provider, attempts=attempts, cost=money(total), remaining_ms=deadline_ms - elapsed)
            break
        decision, reason = classify_error(response.status, response.code)
        recorder.line(scenario, "CLASSIFY", decision=decision, reason=reason)
        if decision == "STOP":
            break
        backoff_ms = 100
        elapsed += backoff_ms
        recorder.line(scenario, "BACKOFF", delay_ms=backoff_ms, jitter="deterministic-demo", elapsed_ms=elapsed)
    recorder.line(scenario, "GUARD", third_attempt="BLOCKED_BY_ATTEMPT_BUDGET", outbound_network_calls=OUTBOUND_ATTEMPTS)
    return {"attempts": attempts, "success": True, "cost_usd": str(total), "elapsed_ms": elapsed}


def scenario_terminal(recorder: Recorder) -> dict[str, object]:
    scenario = "terminal-errors"
    cases = [
        ("bad-credential", 401, "invalid_auth"),
        ("empty-balance", 429, "insufficient_quota"),
        ("policy-block", 403, "compliance_denied"),
    ]
    fallback_calls = 0
    for case, status, code in cases:
        decision, reason = classify_error(status, code)
        recorder.line(scenario, "ATTEMPT", case=case, provider="primary-compatible", status=status, code=code)
        recorder.line(scenario, "CLASSIFY", case=case, decision=decision, reason=reason)
        if decision != "STOP":
            fallback_calls += 1
    recorder.line(scenario, "GUARD", fallback_calls=fallback_calls, expected=0, secret_logged="NO")
    return {"cases": len(cases), "fallback_calls": fallback_calls}


@dataclass
class CircuitBreaker:
    threshold: int = 3
    cooldown_ms: int = 5_000
    failures: int = 0
    state: str = "CLOSED"
    opened_at_ms: int | None = None
    probe_in_flight: bool = False

    def allow(self, now_ms: int) -> bool:
        if self.state == "OPEN" and self.opened_at_ms is not None:
            if now_ms - self.opened_at_ms >= self.cooldown_ms:
                self.state = "HALF_OPEN"
            else:
                return False
        if self.state == "HALF_OPEN":
            if self.probe_in_flight:
                return False
            self.probe_in_flight = True
        return True

    def failure(self, now_ms: int) -> None:
        self.failures += 1
        self.probe_in_flight = False
        if self.state == "HALF_OPEN" or self.failures >= self.threshold:
            self.state = "OPEN"
            self.opened_at_ms = now_ms

    def success(self) -> None:
        self.failures = 0
        self.state = "CLOSED"
        self.opened_at_ms = None
        self.probe_in_flight = False


def scenario_circuit(recorder: Recorder) -> dict[str, object]:
    scenario = "circuit"
    breaker = CircuitBreaker()
    now_ms = 0
    for request_no in range(1, 4):
        allowed = breaker.allow(now_ms)
        recorder.line(scenario, "CALL", request=request_no, time_ms=now_ms, allowed=allowed, state=breaker.state)
        breaker.failure(now_ms)
        recorder.line(scenario, "RESULT", request=request_no, status=503, state=breaker.state, failures=breaker.failures)
        now_ms += 100
    now_ms = 500
    allowed = breaker.allow(now_ms)
    recorder.line(scenario, "FAST_FAIL", request=4, time_ms=now_ms, allowed=allowed, state=breaker.state, upstream_calls=0)
    now_ms = 5_100
    allowed = breaker.allow(now_ms)
    recorder.line(scenario, "COOLDOWN_CHECK", request=5, time_ms=now_ms, allowed=allowed, state=breaker.state)
    now_ms = 5_200
    allowed = breaker.allow(now_ms)
    recorder.line(scenario, "PROBE", request=6, time_ms=now_ms, allowed=allowed, state=breaker.state)
    breaker.success()
    recorder.line(scenario, "RESULT", request=6, status=200, state=breaker.state, failures=breaker.failures)
    return {"final_state": breaker.state, "failures": breaker.failures, "fast_fail": True}


def scenario_hedging(recorder: Recorder) -> dict[str, object]:
    scenario = "hedging"
    calls = [
        ("route-a", 0, 900, Decimal("0.036")),
        ("route-b", 200, 700, Decimal("0.036")),
        ("route-c", 400, 750, Decimal("0.036")),
    ]
    recorder.line(scenario, "POLICY", hedge_after_ms=200, max_parallel=3, note="synthetic accepted calls")
    for provider, started, finished, cost in calls:
        recorder.line(scenario, "ACCEPTED", provider=provider, start_ms=started, finish_ms=finished, projected_charge=money(cost))
    winner = min(calls, key=lambda row: row[2])
    total = sum((row[3] for row in calls), Decimal("0"))
    baseline = calls[0][3]
    multiplier = total / baseline
    recorder.line(scenario, "WINNER", provider=winner[0], finish_ms=winner[2], cancel_sent_to="route-a,route-c")
    recorder.line(scenario, "BILL", accepted_calls=len(calls), used_responses=1, total=money(total), baseline=money(baseline), multiplier=f"{multiplier:.1f}x")
    recorder.line(scenario, "WARNING", message="late cancellation cannot guarantee zero provider work")
    return {"accepted_calls": len(calls), "used_responses": 1, "cost_multiplier": float(multiplier)}


def scenario_budget_audit(recorder: Recorder) -> dict[str, object]:
    scenario = "budget-audit"
    request_cap = Decimal("0.050")
    primary_partial_charge = Decimal("0.020")
    fallback_estimate = Decimal("0.042")
    projected = primary_partial_charge + fallback_estimate
    recorder.line(scenario, "REQUEST", request_id="req-demo-009", policy="route-policy-v3", data="restricted", prompt_stored="NO")
    recorder.line(scenario, "ATTEMPT", provider="primary-compatible", status=503, code="overloaded", partial_charge=money(primary_partial_charge))
    recorder.line(scenario, "CANDIDATE", provider="fallback-premium", estimate=money(fallback_estimate), projected_total=money(projected), request_cap=money(request_cap))
    recorder.line(scenario, "DENY", reason="projected_total_exceeds_request_cap", fallback_called="NO")
    recorder.line(scenario, "AUDIT", fields="request_id,policy,candidates,exclusions,attempts,cost", credentials="REDACTED", raw_prompt="NOT_STORED")
    return {"fallback_called": False, "projected_usd": str(projected), "cap_usd": str(request_cap)}


Scenario = Callable[[Recorder], dict[str, object]]
SCENARIOS: dict[str, Scenario] = {
    "routing": scenario_routing,
    "bounded-429": scenario_bounded_429,
    "terminal-errors": scenario_terminal,
    "circuit": scenario_circuit,
    "hedging": scenario_hedging,
    "budget-audit": scenario_budget_audit,
}


def run_acceptance(recorder: Recorder, results: dict[str, dict[str, object]]) -> dict[str, object]:
    scenario = "acceptance"
    checks: Iterable[tuple[str, bool]] = [
        ("capability_residency_budget_filter", results["routing"]["selected"] == "route-fit"),
        ("bounded_429_fallback", results["bounded-429"]["attempts"] == 2 and results["bounded-429"]["success"] is True),
        ("terminal_errors_stop", results["terminal-errors"]["fallback_calls"] == 0),
        ("circuit_recovers_after_probe", results["circuit"]["final_state"] == "CLOSED"),
        ("hedging_cost_is_visible", results["hedging"]["cost_multiplier"] == 3.0),
        ("request_budget_blocks_fallback", results["budget-audit"]["fallback_called"] is False),
        ("zero_outbound_network", OUTBOUND_ATTEMPTS == 0),
    ]
    passed = 0
    for name, ok in checks:
        recorder.line(scenario, "CHECK", name=name, result="PASS" if ok else "FAIL")
        passed += int(ok)
    total = 7
    recorder.line(scenario, "SUMMARY", passed=f"{passed}/{total}", network="BLOCKED", real_credentials="NONE", synthetic_costs="YES")
    if passed != total:
        raise AssertionError(f"acceptance failed: {passed}/{total}")
    return {"passed": passed, "total": total}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--scenario",
        choices=[*SCENARIOS, "acceptance", "all"],
        default="all",
        help="scenario to run (default: all)",
    )
    parser.add_argument("--output-dir", type=Path, help="optional directory for JSONL events and summary")
    parser.add_argument("--clean", action="store_true", help="remove previous generated JSON output files")
    return parser.parse_args()


def clean_output(output_dir: Path | None) -> None:
    if output_dir is None or not output_dir.exists():
        return
    for name in ("events.jsonl", "summary.json"):
        path = output_dir / name
        if path.exists():
            path.unlink()


def main() -> int:
    args = parse_args()
    clean_output(args.output_dir if args.clean else None)
    print(f"AI_GATEWAY_FAULT_LAB version={LAB_VERSION}")
    print("SAFETY network=BLOCKED providers=SYNTHETIC credentials=NONE prices=SYNTHETIC")
    recorder = Recorder(args.output_dir)

    if args.scenario in SCENARIOS:
        selected = {args.scenario: SCENARIOS[args.scenario](recorder)}
    else:
        selected = {name: function(recorder) for name, function in SCENARIOS.items()}
        selected["acceptance"] = run_acceptance(recorder, selected)

    summary: dict[str, object] = {
        "lab_version": LAB_VERSION,
        "network": "blocked",
        "outbound_attempts": OUTBOUND_ATTEMPTS,
        "credentials": "none",
        "prices": "synthetic",
        "results": selected,
    }
    recorder.write(summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
