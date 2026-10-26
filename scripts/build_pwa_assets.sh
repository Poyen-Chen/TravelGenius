#!/bin/bash
# 把 App 的 SeedData 與物品插圖複製成 PWA 用的檔案，讓網頁版與 iOS 共用同一份資料。
set -euo pipefail
cd "$(dirname "$0")/.."
out=pwa
mkdir -p "$out/data" "$out/art" "$out/icons"
cp TravelGenius/Resources/SeedData/*.json "$out/data/"
python3 - "$out" <<'PY'
import glob, json, subprocess, sys
out = sys.argv[1]
items = json.load(open("TravelGenius/Resources/SeedData/packing_items.json"))["items"]
for item in items:
    key = item.get("artworkKey", item["id"])
    src = glob.glob(f"TravelGenius/Assets.xcassets/packing-{key}.imageset/*.png")
    if not src:
        sys.exit(f"missing artwork for {item['id']}")
    subprocess.run(["sips", "-Z", "240", src[0], "--out", f"{out}/art/{key}.png"], check=True, capture_output=True)
PY
mascot=$(find TravelGenius/Assets.xcassets/PackmonSlime.imageset -type f ! -name Contents.json | head -1)
sips -s format png -Z 240 "$mascot" --out "$out/art/mascot.png" >/dev/null
sips -s format png -z 512 512 "$mascot" --out "$out/icons/icon-512.png" >/dev/null
sips -s format png -z 192 192 "$mascot" --out "$out/icons/icon-192.png" >/dev/null
echo "PWA assets: $(ls "$out/data" | wc -l | tr -d ' ') data files, $(ls "$out/art" | wc -l | tr -d ' ') images"
# 離線快取清單（service worker 安裝時讀取）
(cd "$out" && find . -type f ! -name '*.md' ! -name 'precache.json' ! -name 'sw.js' ! -path './tests/*' ! -name '.assetsignore' ! -name 'config.example.js' | sed 's#^\./##' | sort | python3 -c "import json,sys; print(json.dumps(['./'] + [l.strip() for l in sys.stdin]))" > precache.json)
echo "precache: $(python3 -c "import json; print(len(json.load(open('$out/precache.json'))))") files"
