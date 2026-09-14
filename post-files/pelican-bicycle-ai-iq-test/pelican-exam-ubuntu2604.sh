#!/usr/bin/env bash
# pelican-exam-ubuntu2604.sh
# 鹈鹕骑车测试 · 离线阅卷器 (Ubuntu 26.04 一键版, 零依赖, 仅用系统 python3 标准库)
# 用法: ./pelican-exam-ubuntu2604.sh my-answer.svg   (无参数则生成答题模板)
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "未找到 python3, 请先: sudo apt install python3" >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  cat > my-answer.svg <<'TPL'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 500" width="800" height="500">
  <!-- 把任何聊天 AI 给你的 SVG 答案粘贴到这里替换本文件内容, 然后重新运行本脚本 -->
</svg>
TPL
  echo "已生成答题模板 my-answer.svg"
  echo "把 AI 给你的 SVG 代码粘贴进去保存, 再运行: ./pelican-exam-ubuntu2604.sh my-answer.svg"
  exit 0
fi

python3 - "$@" <<'PY'
import math, os, re, sys
import xml.etree.ElementTree as ET

ORANGE = ("orange", "#f5a623", "#ffa500", "#ffd700", "#f39c12", "#e67e22", "#f8bd5a", "#ff8c00")

def grade(path):
    rows = []
    def add(ok, pts, label, detail=""):
        rows.append((ok, pts, label, detail))
        return pts if ok else 0
    try:
        with open(path, "rb") as f:
            raw = f.read()
        root = ET.fromstring(raw)
    except Exception as e:
        print(f"❌ XML 无法解析, 直接 0 分: {e}")
        return
    total = 0
    ns_ok = root.tag.split("}")[-1].lower() == "svg" and root.tag.startswith("{http://www.w3.org/2000/svg}")
    total += add(ns_ok, 10, "根元素是 <svg> 且声明 xmlns",
                 "" if ns_ok else "缺 xmlns 时浏览器会拒绝渲染")
    vb = root.get("viewBox")
    total += add(bool(vb), 10, "声明了 viewBox", "" if vb else "缩放行为不可控")

    circles, ellipses, nlines, npaths, fills, anim = [], [], 0, 0, [], 0
    stack = [root]
    while stack:
        el = stack.pop()
        t = el.tag.split("}")[-1].lower()
        if t == "circle":
            try:
                r = float(el.get("r"))
                if r > 0:
                    circles.append((float(el.get("cx") or 0), float(el.get("cy") or 0), r))
            except (TypeError, ValueError):
                pass
        elif t == "ellipse":
            try:
                ellipses.append((float(el.get("cx") or 0), float(el.get("cy") or 0),
                                 float(el.get("rx") or 0), float(el.get("ry") or 0)))
            except (TypeError, ValueError):
                pass
        elif t == "line":
            nlines += 1
        elif t == "path":
            npaths += 1
        if t.startswith("animate"):
            anim += 1
        for k in ("fill", "stroke"):
            v = el.get(k)
            if v:
                fills.append(v.lower())
        stack.extend(list(el))

    min_dim = 400.0
    if vb:
        p = re.split(r"[ ,]+", vb.strip())
        if len(p) == 4:
            min_dim = min(float(p[2]), float(p[3]))
    kept = []
    for c in circles:
        for i, k in enumerate(kept):
            if math.hypot(c[0] - k[0], c[1] - k[1]) <= 0.25 * max(c[2], k[2]):
                if c[2] > k[2]:
                    kept[i] = c
                break
        else:
            kept.append(c)
    big = [c for c in kept if c[2] >= 0.10 * min_dim]
    wheels_ok = len(big) == 2
    total += add(wheels_ok, 15, "恰好两个「车轮级」大圆",
                 f"实际找到 {len(big)} 个" if not wheels_ok else "")
    if wheels_ok:
        r1, r2 = big[0][2], big[1][2]
        rr = abs(r1 - r2) / max(r1, r2)
        total += add(rr <= 0.10, 10, "前后轮半径一致 (±10%)",
                     f"差了 {rr * 100:.0f}%" if rr > 0.10 else "")
        b1, b2 = big[0][1] + r1, big[1][1] + r2
        br = abs(b1 - b2) / max(r1, r2)
        total += add(br <= 0.15, 10, "两轮底边同一水平线 (±15%R)",
                     f"一个轮子离地 {br * 100:.0f}%R" if br > 0.15 else "")
        cx_min = min(big[0][0], big[1][0]) - max(r1, r2)
        cx_max = max(big[0][0], big[1][0]) + max(r1, r2)
        body_top = min(b1, b2) - 3 * max(r1, r2)
        has_body = any(cx_min <= e[0] <= cx_max and e[1] < body_top + 2 * max(r1, r2)
                       for e in ellipses if e[2] and e[3])
        total += add(has_body, 10, "两轮之间上方有「鸟身」",
                     "只有车没有鸟, 或鸟飘在画面外" if not has_body else "")
    else:
        for lbl in ("前后轮半径一致 (±10%)", "两轮底边同一水平线", "两轮之间上方有「鸟身」"):
            total += add(False, 0, lbl, "轮子数量都不对, 跳过")

    beak = any(any(w in f for w in ORANGE) for f in fills)
    total += add(beak, 10, "存在橙色系「喙」", "找不到橙/黄色喙, 鹈鹕变麻雀" if not beak else "")
    total += add(nlines + npaths >= 1, 10, "存在线/路径元素 (腿、车架)",
                 "全是色块拼贴, 没有线条骨架" if nlines + npaths < 1 else "")

    cover_ok = len(raw) > 300
    if vb:
        xs, ys = [], []
        for c in circles:
            xs += [c[0] - c[2], c[0] + c[2]]
            ys += [c[1] - c[2], c[1] + c[2]]
        for e in ellipses:
            xs += [e[0] - e[2], e[0] + e[2]]
            ys += [e[1] - e[3], e[1] + e[3]]
        if xs:
            p = re.split(r"[ ,]+", vb.strip())
            cover = ((max(xs) - min(xs)) * (max(ys) - min(ys))) / (float(p[2]) * float(p[3]))
            cover_ok = cover >= 0.20
    total += add(cover_ok, 15, "构图占画面 ≥20%", "画了个寂寞" if not cover_ok else "")

    anim_pts = 20 if (anim > 0 or b"@keyframes" in raw) else 0
    print(f"\n🦩 鹈鹕骑车测试 · 阅卷报告: {os.path.basename(path)}")
    for ok, pts, label, detail in rows:
        print(f"  {'✅' if ok else '❌'} [{pts:>3}分] {label}" + (f"  -- {detail}" if detail else ""))
    note = " (含动画加分 +20)" if anim_pts else ""
    print(f"  总分: {min(total,100)}/100{note}")
    t = min(total, 100)
    print("  一句话点评: " + ("车是车, 鸟是鸟, 骑在一起也合理, 高分!" if t >= 85 else
          "能看出在画什么, 但细节全是破绽。" if t >= 60 else
          "抽象派大作, 人类考官陷入沉思。" if t >= 30 else "这不是鹈鹕, 这是灾难现场。"))

for p in sys.argv[1:]:
    grade(p)
PY
