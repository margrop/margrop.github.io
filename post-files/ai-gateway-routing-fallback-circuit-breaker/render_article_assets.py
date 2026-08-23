#!/usr/bin/env python3
"""Render original diagrams and real lab stdout into mobile-readable PNGs.

This helper is not required to run the standard-library fault lab. It uses
Pillow only for article artwork and invokes the lab locally with no network.
"""

from __future__ import annotations

import subprocess
import sys
import textwrap
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
IMAGE_DIR = REPO / "static" / "post-images" / "ai-gateway-routing-fallback-circuit-breaker"
CAPTURE_DIR = HERE / "lab-output" / "captures"
LAB = HERE / "ai_gateway_fault_lab.py"

BG = "#07111f"
PANEL = "#101e32"
PANEL_2 = "#152943"
INK = "#edf7ff"
MUTED = "#9bb4ca"
CYAN = "#38d9ff"
GREEN = "#4ade80"
AMBER = "#fbbf24"
RED = "#fb7185"
PURPLE = "#a78bfa"

SANS_PATH = "/System/Library/Fonts/Hiragino Sans GB.ttc"
MONO_PATH = "/System/Library/Fonts/Menlo.ttc"


def font(size: int, mono: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(MONO_PATH if mono else SANS_PATH, size=size)


def rounded(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill: str, outline: str | None = None, width: int = 3, radius: int = 28) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def arrow(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], color: str = CYAN, width: int = 8) -> None:
    draw.line([start, end], fill=color, width=width)
    x2, y2 = end
    x1, y1 = start
    if abs(x2 - x1) >= abs(y2 - y1):
        sign = 1 if x2 > x1 else -1
        points = [(x2, y2), (x2 - sign * 24, y2 - 16), (x2 - sign * 24, y2 + 16)]
    else:
        sign = 1 if y2 > y1 else -1
        points = [(x2, y2), (x2 - 16, y2 - sign * 24), (x2 + 16, y2 - sign * 24)]
    draw.polygon(points, fill=color)


def title(draw: ImageDraw.ImageDraw, heading: str, subheading: str) -> None:
    draw.text((70, 52), heading, font=font(60), fill=INK)
    draw.text((72, 126), subheading, font=font(28), fill=MUTED)


def save(image: Image.Image, name: str) -> None:
    IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    image.save(IMAGE_DIR / name, format="PNG", optimize=True)


def cover() -> None:
    image = Image.new("RGB", (1400, 900), BG)
    draw = ImageDraw.Draw(image)
    for x, color in [(70, CYAN), (94, PURPLE), (118, GREEN)]:
        draw.rounded_rectangle((x, 68, x + 12, 280), radius=6, fill=color)
    draw.text((180, 88), "429  ≠  RETRY EVERYTHING", font=font(62), fill=INK)
    draw.text((180, 176), "AI GATEWAY", font=font(88), fill=CYAN)
    draw.text((180, 276), "ROUTING · FALLBACK · CIRCUIT", font=font(37), fill=MUTED)
    rounded(draw, (110, 430, 410, 650), PANEL, CYAN, 4)
    rounded(draw, (550, 430, 850, 650), PANEL, AMBER, 4)
    rounded(draw, (990, 430, 1290, 650), PANEL, GREEN, 4)
    for x, big, small, color in [
        (260, "ROUTE", "hard policy first", CYAN),
        (700, "BOUND", "retry + cost budget", AMBER),
        (1140, "PROVE", "fault injection", GREEN),
    ]:
        bbox = draw.textbbox((0, 0), big, font=font(44))
        draw.text((x - (bbox[2] - bbox[0]) / 2, 488), big, font=font(44), fill=color)
        bbox = draw.textbbox((0, 0), small, font=font(25))
        draw.text((x - (bbox[2] - bbox[0]) / 2, 558), small, font=font(25), fill=INK)
    arrow(draw, (410, 540), (545, 540), CYAN)
    arrow(draw, (850, 540), (985, 540), CYAN)
    draw.text((110, 760), "One answer should have one explainable route — not three surprise bills.", font=font(30), fill=INK)
    draw.text((110, 812), "Original deterministic artwork · synthetic lab · zero external calls", font=font(24), fill=MUTED)
    save(image, "00-cover.png")


def api_vs_ai() -> None:
    image = Image.new("RGB", (1400, 900), BG)
    draw = ImageDraw.Draw(image)
    title(draw, "API Gateway is not the whole AI Gateway", "Adjacent layers, different decisions")
    rounded(draw, (70, 220, 650, 790), PANEL, PURPLE, 4)
    rounded(draw, (750, 220, 1330, 790), PANEL, CYAN, 4)
    draw.text((120, 270), "API GATEWAY", font=font(48), fill=PURPLE)
    draw.text((800, 270), "AI GATEWAY", font=font(48), fill=CYAN)
    left = ["identity / auth", "URL + protocol", "tenant quota", "edge rate limit", "WAF + ingress logs"]
    right = ["model capability", "data region + class", "context + token budget", "error semantics", "fallback + model cost"]
    for index, item in enumerate(left):
        y = 385 + index * 72
        draw.ellipse((120, y + 8, 140, y + 28), fill=PURPLE)
        draw.text((165, y), item, font=font(31), fill=INK)
    for index, item in enumerate(right):
        y = 385 + index * 72
        draw.ellipse((800, y + 8, 820, y + 28), fill=CYAN)
        draw.text((845, y), item, font=font(31), fill=INK)
    draw.text((530, 820), "Keep both. Do not confuse their ownership.", font=font(28), fill=AMBER)
    save(image, "01-api-vs-ai-gateway.png")


def routing_funnel() -> None:
    image = Image.new("RGB", (1400, 900), BG)
    draw = ImageDraw.Draw(image)
    title(draw, "Routing is hospital triage, not roulette", "Hard constraints remove unsafe candidates before scoring")
    boxes = [
        ((70, 235, 330, 665), "REQUEST", ["capability", "region", "data class", "deadline", "cost cap"], PURPLE),
        ((420, 280, 720, 620), "HARD FILTER", ["tools / JSON", "residency", "compliance"], RED),
        ((810, 325, 1060, 575), "SCORE", ["health", "latency", "price"], AMBER),
        ((1130, 335, 1330, 590), "SELECT", ["route-fit", "+ audit"], GREEN),
    ]
    for box, heading, rows, color in boxes:
        rounded(draw, box, PANEL, color, 4)
        x1, y1, x2, _ = box
        bbox = draw.textbbox((0, 0), heading, font=font(35))
        draw.text(((x1 + x2 - (bbox[2] - bbox[0])) / 2, y1 + 34), heading, font=font(35), fill=color)
        for index, row in enumerate(rows):
            bbox = draw.textbbox((0, 0), row, font=font(26))
            draw.text(((x1 + x2 - (bbox[2] - bbox[0])) / 2, y1 + 105 + index * 54), row, font=font(26), fill=INK)
    arrow(draw, (335, 450), (415, 450))
    arrow(draw, (725, 450), (805, 450))
    arrow(draw, (1065, 450), (1125, 450))
    draw.text((160, 745), "A cheaper ambulance in the wrong city is not an eligible ambulance.", font=font(31), fill=INK)
    draw.text((300, 800), "Safety constraints first · weighted preference second", font=font(28), fill=MUTED)
    save(image, "02-routing-funnel.png")


def error_decision() -> None:
    image = Image.new("RGB", (1400, 900), BG)
    draw = ImageDraw.Draw(image)
    title(draw, "Status alone is not enough", "Classify status + provider code + request policy")
    rounded(draw, (510, 205, 890, 335), PANEL, CYAN, 4)
    draw.text((573, 245), "RESPONSE ERROR", font=font(40), fill=CYAN)
    arrow(draw, (700, 340), (700, 420))
    rounded(draw, (460, 425, 940, 545), PANEL_2, AMBER, 4)
    decision_text = "status + code + retry budget"
    decision_font = font(30)
    decision_box = draw.textbbox((0, 0), decision_text, font=decision_font)
    decision_width = decision_box[2] - decision_box[0]
    draw.text(((image.width - decision_width) / 2, 466), decision_text, font=decision_font, fill=INK)
    arrow(draw, (570, 550), (350, 630), GREEN)
    arrow(draw, (830, 550), (1050, 630), RED)
    rounded(draw, (90, 635, 610, 820), PANEL, GREEN, 4)
    rounded(draw, (790, 635, 1310, 820), PANEL, RED, 4)
    draw.text((145, 674), "BOUNDED FALLBACK", font=font(39), fill=GREEN)
    draw.text((840, 674), "STOP + EXPOSE", font=font(39), fill=RED)
    draw.text((150, 742), "429 rate_limited · transient 5xx", font=font(27), fill=INK)
    draw.text((835, 735), "401 / 403 · insufficient_quota", font=font(26), fill=INK)
    draw.text((908, 775), "compliance_denied", font=font(26), fill=INK)
    save(image, "03-error-decision.png")


def circuit_states() -> None:
    image = Image.new("RGB", (1400, 900), BG)
    draw = ImageDraw.Draw(image)
    # This heading is longer than the other diagram titles. Keep it on one
    # mobile-readable line while preserving a generous right-side safe area.
    draw.text((70, 52), "Circuit breaker: stop knocking on a broken door", font=font(52), fill=INK)
    draw.text((72, 126), "Failures are counted in a rolling policy window", font=font(28), fill=MUTED)
    states = [
        ((90, 335, 390, 570), "CLOSED", "calls flow\ncount failures", GREEN),
        ((550, 335, 850, 570), "OPEN", "fast fail\nzero upstream calls", RED),
        ((1010, 335, 1310, 570), "HALF OPEN", "one probe\nthen decide", AMBER),
    ]
    for box, heading, copy, color in states:
        rounded(draw, box, PANEL, color, 5)
        x1, y1, x2, _ = box
        bbox = draw.textbbox((0, 0), heading, font=font(43))
        draw.text(((x1 + x2 - (bbox[2] - bbox[0])) / 2, y1 + 45), heading, font=font(43), fill=color)
        for index, line in enumerate(copy.splitlines()):
            bbox = draw.textbbox((0, 0), line, font=font(28))
            draw.text(((x1 + x2 - (bbox[2] - bbox[0])) / 2, y1 + 126 + index * 44), line, font=font(28), fill=INK)
    arrow(draw, (395, 450), (545, 450), RED)
    arrow(draw, (855, 450), (1005, 450), AMBER)
    # Keep the recovery loop above the annotation row so the arrow does not
    # cross the "probe succeeds" label on a narrow/mobile rendering.
    draw.arc((960, 210, 1330, 650), 230, 120, fill=GREEN, width=7)
    draw.polygon([(946, 410), (974, 387), (978, 424)], fill=GREEN)
    draw.text((235, 675), "threshold reached", font=font(27), fill=RED)
    draw.text((610, 675), "cooldown elapsed", font=font(27), fill=AMBER)
    draw.text((1018, 675), "probe succeeds", font=font(27), fill=GREEN)
    footer_lines = [
        "Retry budget protects one request.",
        "Circuit breaker protects the whole upstream.",
    ]
    for y, line in zip((748, 792), footer_lines):
        bbox = draw.textbbox((0, 0), line, font=font(28))
        line_width = bbox[2] - bbox[0]
        draw.text(((image.width - line_width) / 2, y), line, font=font(28), fill=MUTED)
    save(image, "04-circuit-breaker.png")


def audit_receipt() -> None:
    image = Image.new("RGB", (1400, 900), BG)
    draw = ImageDraw.Draw(image)
    title(draw, "A route decision needs a receipt", "Explain the choice without logging secrets or raw prompts")
    rounded(draw, (120, 210, 1280, 790), PANEL, CYAN, 4)
    draw.text((180, 260), "ROUTE DECISION  /  req-demo-009", font=font(40, mono=True), fill=CYAN)
    rows = [
        ("policy", "route-policy-v3", INK),
        ("requirements", "tools · region-a · restricted", INK),
        ("excluded", "route-fast:data_residency", AMBER),
        ("attempts", "primary:503 → fallback:budget_denied", INK),
        ("projected cost", "$0.062000 > $0.050000 cap", RED),
        ("credentials", "REDACTED", GREEN),
        ("raw prompt", "NOT STORED", GREEN),
    ]
    for index, (key, value, color) in enumerate(rows):
        y = 350 + index * 56
        draw.text((190, y), f"{key:<16}", font=font(28, mono=True), fill=MUTED)
        draw.text((530, y), value, font=font(28, mono=True), fill=color)
    draw.text((180, 730), "Audit the decision, not the user's secret.", font=font(30), fill=PURPLE)
    save(image, "05-audit-receipt.png")


def run_lab(scenario: str) -> list[str]:
    result = subprocess.run(
        [sys.executable, str(LAB), "--scenario", scenario],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if result.stderr.strip():
        raise RuntimeError(f"lab wrote stderr for {scenario}: {result.stderr}")
    lines = result.stdout.rstrip().splitlines()
    if scenario == "acceptance":
        lines = lines[:2] + [line for line in lines if "[acceptance]" in line]
    CAPTURE_DIR.mkdir(parents=True, exist_ok=True)
    (CAPTURE_DIR / f"{scenario}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return lines


def wrap_terminal_line(line: str, width: int = 68) -> list[str]:
    if len(line) <= width:
        return [line]
    return textwrap.wrap(line, width=width, subsequent_indent="    ", break_long_words=False, break_on_hyphens=False)


def terminal_capture(scenario: str, filename: str, label: str) -> None:
    raw_lines = run_lab(scenario)
    lines: list[str] = []
    for line in raw_lines:
        lines.extend(wrap_terminal_line(line))
    width = 1200
    line_height = 42
    height = max(720, 160 + len(lines) * line_height + 70)
    image = Image.new("RGB", (width, height), "#060a10")
    draw = ImageDraw.Draw(image)
    rounded(draw, (24, 24, width - 24, height - 24), "#0b1220", "#314158", 3, 22)
    draw.rectangle((25, 25, width - 25, 98), fill="#151f2e")
    for index, color in enumerate((RED, AMBER, GREEN)):
        draw.ellipse((55 + index * 38, 52, 75 + index * 38, 72), fill=color)
    draw.text((200, 44), f"local zero-network lab / {label}", font=font(27, mono=True), fill=INK)
    y = 125
    for line in lines:
        color = INK
        if "PASS" in line or "SUCCESS" in line or "SELECT" in line:
            color = GREEN
        elif "STOP" in line or "DENY" in line or "EXCLUDE" in line or "status=503" in line:
            color = RED
        elif "429" in line or "BACKOFF" in line or "BILL" in line or "OPEN" in line:
            color = AMBER
        elif line.startswith("AI_GATEWAY") or line.startswith("SAFETY"):
            color = CYAN
        line_font = font(25, mono=True)
        line_box = draw.textbbox((58, y), line, font=line_font)
        if line_box[2] > width - 48 or line_box[3] > height - 48:
            raise ValueError(f"terminal text exceeds safe area in {filename}: {line!r} -> {line_box}")
        draw.text((58, y), line, font=line_font, fill=color)
        y += line_height
    save(image, filename)


def validate_canvas_margins(expected_count: int = 13, minimum_margin: int = 20) -> None:
    """Fail generation if any visible pixel reaches a canvas safety edge."""
    paths = sorted(IMAGE_DIR.glob("*.png"))
    if len(paths) != expected_count:
        raise ValueError(f"expected {expected_count} PNG assets, found {len(paths)}")
    for path in paths:
        image = Image.open(path).convert("RGB")
        background = Image.new("RGB", image.size, image.getpixel((0, 0)))
        content_box = ImageChops.difference(image, background).getbbox()
        if content_box is None:
            raise ValueError(f"empty image: {path.name}")
        left, top, right, bottom = content_box
        margins = (left, top, image.width - right, image.height - bottom)
        if min(margins) < minimum_margin:
            raise ValueError(f"canvas overflow risk in {path.name}: box={content_box}, margins={margins}")
        print(f"canvas-safe {path.name} size={image.width}x{image.height} margins={margins}")


def main() -> int:
    cover()
    api_vs_ai()
    routing_funnel()
    error_decision()
    circuit_states()
    audit_receipt()
    captures = [
        ("routing", "10-real-routing-filter.png", "routing"),
        ("bounded-429", "11-real-bounded-429.png", "bounded 429"),
        ("terminal-errors", "12-real-terminal-errors.png", "terminal errors"),
        ("circuit", "13-real-circuit-breaker.png", "circuit breaker"),
        ("hedging", "14-real-hedging-cost.png", "hedging cost"),
        ("budget-audit", "15-real-budget-audit.png", "budget + audit"),
        ("acceptance", "16-real-acceptance.png", "acceptance"),
    ]
    for scenario, filename, label in captures:
        terminal_capture(scenario, filename, label)
    validate_canvas_margins()
    print(f"rendered {6 + len(captures)} PNG assets in {IMAGE_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
