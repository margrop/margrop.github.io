#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""鹈鹕骑车测试 · 离线阅卷器（Pelican Exam Grader）

用法:
  python3 pelican_exam.py --demo          # 自带试卷演示：生成坏卷+好卷并评分
  python3 pelican_exam.py a.svg b.svg     # 给任意 SVG 试卷打分
  python3 pelican_exam.py dir/            # 批量阅卷

设计原则: 只用 Python 标准库, 零网络请求, 零第三方依赖。
评分是启发式的几何体检, 不是审美评判。
"""
import math
import os
import sys
import xml.etree.ElementTree as ET

W = "\033[0m"  # reset


def c(code, s):
    return f"\033[{code}m{s}{W}" if sys.stdout.isatty() else s


def local(tag):
    return tag.split("}")[-1] if "}" in tag else tag


def walk(elem):
    yield elem
    for child in elem:
        yield from walk(child)


def fnum(v, default=None):
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


ORANGE_WORDS = ("orange", "#f5a623", "#ffa500", "#ffd700", "#f39c12", "#e67e22", "#f8bd5a", "#ff8c00")


def is_beak_fill(fill):
    if not fill:
        return False
    return any(w in fill.lower() for w in ORANGE_WORDS)


def grade(path):
    """返回 (总分, 满分, 动画加分, 明细列表, 一句话点评)"""
    rows = []

    def add(ok, pts, label, detail=""):
        rows.append((ok, pts, label, detail))
        return pts if ok else 0

    try:
        with open(path, "rb") as f:
            raw = f.read()
        tree = ET.ElementTree(ET.fromstring(raw))
    except ET.ParseError as e:
        add(False, 100, "XML 语法可解析", f"直接 0 分: {e}")
        return 0, 100, 0, rows, "语法就错了, 相当于把名字写在了密封线外。"
    root = tree.getroot()

    total = 0
    full = 100

    # 1. 根元素与命名空间 (10)
    ns_ok = local(root.tag).lower() == "svg"
    xmlns_ok = root.tag.startswith("{http://www.w3.org/2000/svg}")
    total += add(ns_ok and xmlns_ok, 10, "根元素是 <svg> 且声明 xmlns",
                 "" if (ns_ok and xmlns_ok) else "缺 xmlns 时被当作普通 XML, 网页里直接不显示 (Gemini 1.5 Pro 001 的真实翻车)")

    # 2. viewBox (10)
    vb = root.get("viewBox")
    total += add(bool(vb), 10, "声明了 viewBox",
                 "" if vb else "没有 viewBox, 缩放行为不可控")

    vb_w = vb_h = None
    if vb:
        parts = vb.replace(",", " ").split()
        if len(parts) == 4:
            vb_w, vb_h = fnum(parts[2]), fnum(parts[3])
            if vb_w and vb_h and (vb_w <= 0 or vb_h <= 0):
                total += add(False, 0, "viewBox 尺寸合法", "")

    # 收集几何元素 (同心圆去重: 轮胎/轮圈/轴心算一个轮)
    circles, ellipses, lines, polys, paths, fills = [], [], [], [], [], []
    raw_circles = []
    anim_count = 0
    for el in walk(root):
        t = local(el.tag).lower()
        if t == "circle":
            r = fnum(el.get("r"))
            if r and r > 0:
                raw_circles.append((fnum(el.get("cx")), fnum(el.get("cy")), r, el.get("fill", "")))
        elif t == "ellipse":
            ellipses.append((fnum(el.get("cx")), fnum(el.get("cy")),
                             fnum(el.get("rx")), fnum(el.get("ry"))))
        elif t == "line":
            lines.append((fnum(el.get("x1")), fnum(el.get("y1")),
                          fnum(el.get("x2")), fnum(el.get("y2"))))
        elif t in ("polygon", "polyline"):
            pts = [fnum(p) for p in (el.get("points") or "").replace(",", " ").split()]
            if len(pts) >= 6:
                polys.append((pts, el.get("fill", "")))
        elif t == "path":
            d = el.get("d") or ""
            nums = [fnum(p) for p in __import__("re").findall(r"-?\d+\.?\d*", d)]
            if nums:
                xs = [n for n in nums[0::2] if n is not None]
                ys = [n for n in nums[1::2] if n is not None]
                if xs and ys:
                    paths.append((min(xs), max(xs), min(ys), max(ys), d, el.get("fill", "")))
        if t.startswith("animate"):
            anim_count += 1
        fill = el.get("fill") or el.get("stroke") or ""
        if fill:
            fills.append(fill.lower())

    for cx, cy, r, fill in raw_circles:
        dup = False
        for i, (cx2, cy2, r2, _) in enumerate(circles):
            if cx is not None and cy is not None and cx2 is not None and cy2 is not None:
                if math.hypot(cx - cx2, cy - cy2) <= 0.25 * max(r, r2):
                    if r > r2:
                        circles[i] = (cx, cy, r, fill)
                    dup = True
                    break
        if not dup:
            circles.append((cx, cy, r, fill))

    # 3. 车轮: 恰好两个大圆 (15)
    if vb_w and vb_h:
        big = [c4 for c4 in circles if c4[2] >= 0.10 * min(vb_w, vb_h)]
    else:
        big = sorted(circles, key=lambda c4: -c4[2])[:2]
    wheels_ok = len(big) == 2
    total += add(wheels_ok, 15, "恰好两个「车轮级」大圆",
                 f"实际找到 {len(big)} 个" if not wheels_ok else "")

    # 4. 双轮等大 (10)
    if wheels_ok:
        r1, r2 = big[0][2], big[1][2]
        rr = abs(r1 - r2) / max(r1, r2)
        total += add(rr <= 0.10, 10, "前后轮半径一致 (±10%)",
                     f"差了 {rr * 100:.0f}%" if rr > 0.10 else "")
        # 5. 双轮底部同一水平线 (10)
        b1, b2 = big[0][1] + r1, big[1][1] + r2
        br = abs(b1 - b2) / max(r1, r2)
        total += add(br <= 0.15, 10, "两轮底边同一水平线 (±15%R)",
                     f"一个轮子离地 {br * 100:.0f}%R" if br > 0.15 else "")
        # 6. 鸟在车上: 车身区域上方有椭圆/大圆 (10)
        cx_min = min(big[0][0], big[1][0]) - max(r1, r2)
        cx_max = max(big[0][0], big[1][0]) + max(r1, r2)
        body_top = min(b1, b2) - 3 * max(r1, r2)
        has_body = any(
            e[0] is not None and e[1] is not None and e[2] and e[3]
            and cx_min <= e[0] <= cx_max and e[1] < body_top + 2 * max(r1, r2)
            for e in ellipses
        ) or any(
            c4[0] is not None and c4[2] >= 0.12 * min(vb_w or 400, vb_h or 300)
            and cx_min <= c4[0] <= cx_max and c4[1] < body_top + 2 * max(r1, r2)
            for c4 in circles if c4 not in big
        )
        total += add(has_body, 10, "两轮之间上方有「鸟身」",
                     "只有车没有鸟, 或鸟飘在画面外" if not has_body else "")
    else:
        total += add(False, 0, "前后轮半径一致 (±10%)", "轮子数量都不对, 跳过")
        total += add(False, 0, "两轮底边同一水平线", "")
        total += add(False, 0, "两轮之间上方有「鸟身」", "")

    # 7. 橙色喙 (10)
    beak_ok = any(is_beak_fill(f) for f in fills) or any(
        is_beak_fill(p[1]) for p in polys)
    total += add(beak_ok, 10, "存在橙色系「喙」", "找不到橙/黄色喙, 鹈鹕变麻雀" if not beak_ok else "")

    # 8. 腿: 有线条元素 (10)
    legs_ok = len(lines) + len(paths) >= 1
    total += add(legs_ok, 10, "存在线/路径元素 (腿、车架)",
                 "全是色块拼贴, 没有线条骨架" if not legs_ok else "")

    # 9. 构图面积 (15)
    if vb_w and vb_h:
        xs, ys = [], []
        for c4 in circles:
            xs += [c4[0] - c4[2], c4[0] + c4[2]]
            ys += [c4[1] - c4[2], c4[1] + c4[2]]
        for e in ellipses:
            if e[0] is not None:
                xs += [e[0] - (e[2] or 0), e[0] + (e[2] or 0)]
                ys += [e[1] - (e[3] or 0), e[1] + (e[3] or 0)]
        for p in paths:
            xs += [p[0], p[1]]
            ys += [p[2], p[3]]
        xs = [x for x in xs if x is not None]
        ys = [y for y in ys if y is not None]
        if xs and ys:
            cover = ((max(xs) - min(xs)) * (max(ys) - min(ys))) / (vb_w * vb_h)
            total += add(cover >= 0.20, 15, "构图占画面 ≥20%",
                         f"只占了 {cover * 100:.0f}%, 画了个寂寞" if cover < 0.20 else "")
        else:
            total += add(False, 15, "构图占画面 ≥20%", "画面里几乎没有元素")
    else:
        total += add(bool(raw) and len(raw) > 300, 15, "构图占画面 ≥20%", "无法计算")

    # 动画加试题 (+20)
    css_anim = b"@keyframes" in raw or b"animation" in raw
    anim = anim_count > 0 or css_anim
    anim_pts = 20 if anim else 0

    verdicts = [
        (total >= 85, "车是车, 鸟是鸟, 骑在一起也合理, 高分!"),
        (total >= 60, "能看出在画什么, 但细节全是破绽。"),
        (total >= 30, "抽象派大作, 人类考官陷入沉思。"),
    ]
    verdict = next((v for ok, v in verdicts if ok), "这不是鹈鹕, 这是灾难现场。")
    return min(total, full), full, anim_pts, rows, verdict


BROKEN_DEMO = """<svg width="200" height="150">
  <circle cx="50" cy="100" r="15" fill="yellow"/>
  <path d="M40,100 L60,100 L80,80" stroke="black"/>
  <ellipse cx="60" cy="70" rx="20" ry="30" fill="white"/>
</svg>"""


def good_demo_file():
    """优先用同目录的自制满分卷, 没有就现场手搓一张合格卷"""
    mine = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "09-pelican-static.svg")
    if os.path.exists(mine):
        with open(mine, encoding="utf-8") as f:
            return f.read()
    return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 500" width="800" height="500">
  <rect x="0" y="430" width="800" height="70" fill="#d7ead9"/>
  <circle cx="240" cy="370" r="60" fill="none" stroke="#2c3e50" stroke-width="9"/>
  <circle cx="560" cy="370" r="60" fill="none" stroke="#2c3e50" stroke-width="9"/>
  <g stroke="#e74c3c" stroke-width="9" stroke-linecap="round" fill="none">
    <line x1="240" y1="370" x2="400" y2="370"/>
    <line x1="240" y1="370" x2="350" y2="258"/>
    <line x1="350" y1="258" x2="400" y2="370"/>
    <line x1="350" y1="258" x2="508" y2="290"/>
    <line x1="508" y1="290" x2="400" y2="370"/>
  </g>
  <ellipse cx="338" cy="192" rx="78" ry="54" fill="#fdf6e3" stroke="#d9cfae" stroke-width="3"/>
  <path d="M388,168 C412,152 420,120 442,100" fill="none" stroke="#fdf6e3" stroke-width="25" stroke-linecap="round"/>
  <circle cx="448" cy="92" r="26" fill="#fdf6e3" stroke="#d9cfae" stroke-width="3"/>
  <path d="M462,86 L596,138 L474,106 Z" fill="#f5a623" stroke="#d48806" stroke-width="2"/>
  <path d="M364,238 L400,300 L430,386" fill="none" stroke="#e67e22" stroke-width="8" stroke-linecap="round"/>
</svg>"""


def report(path):
    total, full, anim, rows, verdict = grade(path)
    print(c("1;36", f"\n🦩 鹈鹕骑车测试 · 阅卷报告: {os.path.basename(path)}"))
    for ok, pts, label, detail in rows:
        mark = c("1;32", "✅") if ok else c("1;31", "❌")
        print(f"  {mark} [{pts:>3}分] {label}" + (f"  -- {detail}" if detail else ""))
    star = " (含动画加分 +20)" if anim else ""
    print(c("1;33", f"  总分: {total}/{full}{star}"))
    print(f"  一句话点评: {verdict}\n")
    return total


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if "--demo" in sys.argv or not args:
        import tempfile
        print(c("1;35", "== 演示模式: 自动生成两张试卷并阅卷 ==\n"))
        with tempfile.TemporaryDirectory() as d:
            bad = os.path.join(d, "broken-answer.svg")
            good = os.path.join(d, "good-answer.svg")
            with open(bad, "w") as f:
                f.write(BROKEN_DEMO)
            with open(good, "w", encoding="utf-8") as f:
                f.write(good_demo_file())
            report(bad)
            report(good)
        return 0
    for a in args:
        if os.path.isdir(a):
            for fn in sorted(os.listdir(a)):
                if fn.endswith(".svg"):
                    report(os.path.join(a, fn))
        else:
            report(a)
    return 0


if __name__ == "__main__":
    sys.exit(main())
