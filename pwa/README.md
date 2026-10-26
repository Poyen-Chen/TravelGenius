# PackSmart PWA

iOS App 的網頁版：同一份規則與資料（`TravelGenius/Resources/SeedData`）、同一個 Supabase 後端與 payload version 1，所以 iPhone 和網頁版可以共用同一趟行程（PD-064）。不需要建置工具，純 HTML／CSS／JavaScript 模組。

## 建置

```sh
scripts/build_pwa_assets.sh                          # 複製 SeedData、產生 61 張物品插圖與圖示、離線快取清單
scripts/build_pwa_config.sh <project-ref> 新加坡      # 寫入 pwa/js/config.js（gitignore；只放 publishable key）
```

沒有 `pwa/js/config.js` 時，網頁版只用瀏覽器本機資料。

## 測試

```sh
node pwa/tests/engine-parity.mjs <actual.json>       # 與 iOS 的 2,916 組情境比對（actual.json 由 scripts/PackingCompatibility.swift 產生）
node pwa/tests/suitcase.mjs                          # 行李箱格子規則（PD-065）
cd pwa && python3 -m http.server 8766                 # 本機預覽：http://127.0.0.1:8766
```

## 部署（Cloudflare Workers 靜態網站）

在 repo 外建立只含下列內容的 `wrangler.jsonc`，再執行 `wrangler deploy`：

```jsonc
{ "name": "packsmart-app", "compatibility_date": "2026-10-01", "assets": { "directory": "<repo>/pwa" } }
```

`pwa/.assetsignore` 排除測試與範本檔。每次更新請把 `sw.js` 的 `CACHE` 版本加一，並同步更新 `index.html` 裡 `styles.css`、`js/app.js` 的 `?v=`。service worker 只在網址完全相同時用快取（沒網路才退回同檔名），新版接手時頁面會自動重新載入一次。

## 與 iOS 的差異

- 網站版面：電腦上左側欄＋內容區，手機上底部分頁（PD-065）。

- 登入狀態存在瀏覽器 localStorage（iOS 存 Keychain）。
- 沒有建立後的「更新打包建議」review、行李估重、Widget 與通知。
- 「能不能帶？」以台灣往返單一目的地查詢。
