#!/usr/bin/env bash
# PhET offline classroom kit for Ubuntu 26.04
# Downloads official single-file HTML5 sims from phet.colorado.edu and builds a local index.html.
# Sims: PhET Interactive Simulations, University of Colorado Boulder, CC BY-NC 4.0.
set -euo pipefail

BASE="https://phet.colorado.edu"
LANG_CODE="zh_CN"
OUT=""
ALL=0
OPEN=0
QUERY="?yotta=false"
SIMS="projectile-motion,circuit-construction-kit-dc,forces-and-motion-basics,energy-skate-park-basics,gravity-and-orbits,wave-on-a-string,bending-light,color-vision,states-of-matter,build-an-atom,ph-scale,balancing-chemical-equations,fractions-intro,graphing-lines,natural-selection"

usage() {
  cat <<'USAGE'
Usage: bash phet-offline-ubuntu.sh [options]
  --lang CODE     Sim language, e.g. zh_CN, zh_TW, en (default: zh_CN)
  --sims LIST     Comma-separated sim names (default: 15 classroom sims)
  --all           Download every HTML5 sim listed by PhET metadata (about 0.5 GB)
  --out DIR       Output folder (default: ./phet-offline-<lang>)
  --open          Open index.html when finished
  --allow-stats   Let sims send PhET usage pings when online (default: off)
  -h, --help      Show this help
Exit codes: 0 = all done, 2 = finished with some sims missing, 1 = error
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --lang) LANG_CODE="${2:?}"; shift 2 ;;
    --sims) SIMS="${2:?}"; shift 2 ;;
    --all) ALL=1; shift ;;
    --out) OUT="${2:?}"; shift 2 ;;
    --open) OPEN=1; shift ;;
    --allow-stats) QUERY=""; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

case "$LANG_CODE" in
  *[!A-Za-z_]*|"") echo "Invalid --lang: $LANG_CODE" >&2; exit 1 ;;
esac
OUT="${OUT:-./phet-offline-$LANG_CODE}"

fetch() { # url dest
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 --connect-timeout 20 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --tries=3 --timeout=60 -O "$2" "$1"
  else
    echo "Need curl or wget: sudo apt install -y curl" >&2; exit 1
  fi
}

mkdir -p "$OUT/sims"
OUT="$(cd "$OUT" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ "$ALL" = 1 ]; then
  echo "[1/3] Reading the official sim list..."
  fetch "$BASE/services/metadata/1.3/simulations?format=json&type=html&summary" "$TMP/meta.json"
  SIMS="$(grep -o '"name": *"html/[a-z0-9-]*"' "$TMP/meta.json" | sed 's/.*html\///; s/"$//' | sort -u | paste -sd, -)"
fi

IFS=',' read -r -a LIST <<< "$SIMS"
echo "[2/3] Downloading ${#LIST[@]} sims ($LANG_CODE) to $OUT/sims"
ok=0; miss=0; rows=""
for sim in "${LIST[@]}"; do
  sim="$(echo "$sim" | tr -d '[:space:]')"
  case "$sim" in *[!a-z0-9-]*|"") echo "  skip invalid name: $sim"; continue ;; esac
  got=""
  for lc in "$LANG_CODE" en; do
    f="$OUT/sims/${sim}_${lc}.html"
    if [ -s "$f" ] && grep -q 'phet-sim-level' "$f"; then got="$lc"; break; fi
    if fetch "$BASE/sims/html/$sim/latest/${sim}_${lc}.html" "$TMP/part.html" 2>/dev/null \
       && grep -q 'phet-sim-level' "$TMP/part.html"; then
      mv "$TMP/part.html" "$f"; got="$lc"; break
    fi
  done
  if [ -z "$got" ]; then
    echo "  MISSING  $sim"; miss=$((miss+1)); continue
  fi
  title="$(grep -o '<title>[^<]*</title>' "$OUT/sims/${sim}_${got}.html" | head -1 | sed 's/<[^>]*>//g; s/&#8234;//g; s/&#8236;//g')"
  [ -n "$title" ] || title="$sim"
  note=""; [ "$got" != "$LANG_CODE" ] && note=" <small>(en)</small>"
  rows="$rows<li><a href=\"sims/${sim}_${got}.html$QUERY\">$title</a>$note<span>$sim</span></li>"
  echo "  OK       $sim ($got)"; ok=$((ok+1))
done

echo "[3/3] Writing index.html and SHA256SUMS.txt"
cat > "$OUT/index.html" <<HTML
<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>PhET 离线实验室 / Offline Lab</title>
<style>
body{font-family:system-ui,"PingFang SC","Microsoft YaHei","Noto Sans CJK SC",sans-serif;margin:0;background:#f6f3ec;color:#1d2a3a}
header{background:#1d3557;color:#fff;padding:28px 24px}h1{margin:0 0 6px;font-size:28px}
ul{list-style:none;margin:0;padding:20px;display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:14px}
li{background:#fff;border-radius:12px;padding:16px;box-shadow:0 1px 3px #0002}
a{font-size:19px;color:#1d3557;font-weight:600;text-decoration:none}a:hover{text-decoration:underline}
span{display:block;color:#6b7785;font-size:13px;margin-top:6px}footer{padding:0 24px 28px;color:#6b7785;font-size:13px}
</style></head><body>
<header><h1>PhET 离线实验室 / Offline Lab</h1><div>$ok sims · $LANG_CODE · 断网可用 / works offline</div></header>
<ul>$rows</ul>
<footer>Simulation by PhET Interactive Simulations, University of Colorado Boulder, licensed under CC BY-NC 4.0 (https://phet.colorado.edu). Non-commercial use only.</footer>
</body></html>
HTML
(cd "$OUT" && sha256sum index.html sims/*.html > SHA256SUMS.txt)

echo "Done: $ok OK, $miss missing. Open: $OUT/index.html"
if [ "$OPEN" = 1 ] && command -v xdg-open >/dev/null 2>&1; then xdg-open "$OUT/index.html" >/dev/null 2>&1 || true; fi
[ "$ok" -gt 0 ] || exit 1
[ "$miss" -eq 0 ] || exit 2
