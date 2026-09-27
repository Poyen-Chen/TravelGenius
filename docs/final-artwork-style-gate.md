# Packmon 最終物品圖：盤點與 Style Gate

日期：2026-09-27。狀態：使用者已選 B（紙感／gouache）；61 項 App／PWA 候選已完成，等待最終人工驗收。

## 決策與程式基線

- 實作分支 `codex/packmon-final-artwork` 從 immutable tag `packmon-ios-stage-07-accepted`（`0a6e4fd`）建立，保留 Stage 6 已驗收的雙欄圖卡行為。
- 內容分母使用 PD-050／051 已人工驗證的 61 個 active stable IDs；不把 95 筆定義中的相容性 ID 算進「全目錄」覆蓋率，也不把分類 fallback 算成精確素材。
- 這個 Stage 7 基線仍是舊 catalog 程式。PD-052 的 catalog/recommendation 實作候選不在本分支，且尚待人工驗收；本階段不藉圖片工作夾帶推薦規則、catalog ID 或資料模型變更。
- PD-019／043 固定 reusable bundled assets 與雙欄 image-forward cards；PD-044 明確只接受功能並延後最終一致畫風；PD-045 也沒有批准發版。因此現有混合素材不足以唯一決定最後畫風，必須先選樣。

## 61 個 active IDs

分布：衣物 26、文件 6、電子 13、盥洗 7、其他 9；V1 active catalog 沒有 health 類別。健康小樣因此使用相容性舊 ID `regular-medicine` 測試歷史／自訂健康用品的表現，不把它加入 61 項分母。

### 文件（6）

`passport`, `payment-card`, `travel-document-backup`, `local-cash`, `driving-documents`, `business-cards`

### 衣物（26）

`tops`, `bottoms`, `underwear`, `socks`, `walking-shoes`, `sleepwear`, `light-jacket`, `sweater-fleece`, `warm-coat`, `scarf`, `warm-hat`, `waterproof-gloves`, `rain-jacket`, `sun-hat`, `swimsuit`, `outdoor-shoes`, `waterproof-nonslip-shoes`, `thermal-base-layer`, `ski-socks`, `ski-jacket`, `ski-pants`, `workout-clothes`, `business-clothes`, `formal-clothes`, `formal-shoes`, `slippers`

### 電子（13）

`phone`, `laptop`, `tablet`, `camera`, `smartwatch`, `headphones`, `charging-kit`, `laptop-charger`, `camera-charger`, `memory-card`, `watch-charger`, `power-bank`, `plug-adapter`

### 盥洗（7）

`toothbrush`, `toothpaste`, `skincare`, `sanitary-products`, `sunscreen`, `quick-dry-towel`, `laundry-supplies`

### 其他（9）

`folding-umbrella`, `water-bottle`, `sunglasses`, `hand-warmer`, `wet-item-bag`, `daypack`, `ski-goggles`, `locker-lock`, `laundry-bag`

## 目前素材與覆蓋率

- active 精確覆蓋：61/61（100%）；每個 stable ID 都有獨立 PNG 與 exact-ID mapping。
- 舊的 `cable`、`charger`、`clothes`、`umbrella` 混合畫風資產已移除；`passport`、`sunscreen` 也已用 B 方向重製，沒有沿用 Stage 6 正式圖。
- 相容性舊 ID（例如 `clothes-change`、`passport-copies`）不列入 61 分母，也不會錯配新的 active 圖片。
- 自訂、未知與相容性-only ID 繼續使用有文字標記的分類 fallback；fallback 不算精確圖片。
- 自訂、未知、空 ID 或圖片載入失敗：一律維持名稱、數量與控制，顯示分類 fallback，不以名稱子字串猜圖。

選樣前的 Stage 6 六張圖雖為透明 PNG，尺寸卻分成 1254×1254、256×238、217×256、230×256，寫實程度、材質、留白、視角與陰影不一致；本候選已全數取代。Stage 6 的來源紀錄只證明產生／沿用方式，不等於商用權利保證。

## 組合品與誤配風險

- 組合品：`charging-kit` 必須同時看見充電頭與線材；`camera-charger` 必須表達電池與充電器；`headphones` 含收納盒；`driving-documents` 與 `travel-document-backup` 是多件文件概念；`laundry-supplies` 可用一個主容器加一個小配件，但不可變成不透明大禮包。
- 單品／配件：`phone`、`laptop`、`camera`、`smartwatch` 不能順手附上充電器；`laptop-charger`、`watch-charger`、`power-bank`、`plug-adapter` 必須彼此可分辨。
- 近義防誤配：`passport` ≠ `passport-copies`／`travel-document-backup`；`charging-kit` ≠ cable-only／`laptop-charger`；`tops` ≠ `clothes-change`／商務／正式／運動／保暖內層；`walking-shoes` ≠ 健行／防滑／正式／拖鞋；`sunscreen` ≠ `skincare`；`wet-item-bag` ≠ `laundry-bag`／`daypack`；`regular-medicine`、`prescription-medicine` 與特定健康用品不得互相猜圖。
- 舊 bundle ID（例如 `toiletry-kit`, `laptop-kit`, `scarf-gloves`）保留解碼但不映射到新的單品圖片；這可避免歷史資料被誤解成已拆分的新 catalog item。

## 共同 Style Contract（選定方向後套到每張正式資產）

- 正式 master：1024×1024 px、PNG、sRGB、RGBA 真透明背景；不從低解析檔放大。App 使用 bundled asset catalog；PWA 使用同一份 PNG bytes 或由同一 master 做有紀錄的無損／等比例輸出。
- 視角：一致的輕微俯視三分之四角；平面薄物可在相同相機語言內微調，但不可在正側視、俯視、寫實攝影間混搭。
- 光源：左上方柔光；每張最多一個貼近主體、低不透明度的短陰影；透明邊緣不得有白／黑 halo。
- 細節：在 80×80 pt 仍先讀到輪廓，再讀到材質；不靠細小圖案才能辨認。品牌無關的必要功能結構可保留，接頭、容量與規格不可被畫成特定產品承諾。
- 色彩：中低飽和，深藍／暖灰為主，暖橘只作小面積呼應；避免整片奶油底，以免和 Packmon 奶油卡片融在一起。
- 佔比：單品包圍盒約佔畫布 68–74%，四邊至少 13% 安全留白；細長物可提高長邊佔比但保留同等視覺重量。
- 禁用：文字、字母、數字、商標、國徽、國旗、品牌造型、浮水印、人物、手、情境背景與裝飾道具。
- 組合品：一個主件加最多兩個必要相關件，彼此不重疊到失去輪廓，整組仍落在與單品相同的視覺包圍盒；單品不得附送不屬於其 ID 的配件。
- 小尺寸驗收：在 80×80 與 96×96 預覽中，盲看輪廓可辨認；組合品／單品、近義鞋款、袋類與充電配件需做並排測試。
- 無障礙：圖片永遠是輔助；卡片仍顯示完整名稱、數量、勾選與操作，VoiceOver／大字體不可只靠圖片傳達身份。

## 三個候選方向

三張 specimen 都使用相同六物件：`passport`, `tops`, `charging-kit`, `toothbrush`, 相容性 `regular-medicine`, `daypack`。它們是 style-gate 複合樣本，不是可直接切割後上線的正式逐項資產。

### A — 柔和 3D 產品插畫

- 圓潤、霧面、材質提示最清楚；接近現有圖卡的產品感，但降低攝影寫實與品牌感。
- 無描邊，靠形體與柔和光影分離；最容易和目前 Stage 6 卡片連續，但對全套一致的光線／材質控制要求最高。
- 檔案：`docs/evidence/final-artwork/style-gate/direction-a-soft-3d.png`

### B — 紙感／gouache 編輯插畫

- 柔和紙紋、低反光、較生活化；品牌溫度最高，和奶油／暖橘環境相容。
- 紋理在小尺寸須限制，避免糊成噪點；正式製作時會比 specimen 再簡化細節。
- 檔案：`docs/evidence/final-artwork/style-gate/direction-b-paper-gouache.png`

### C — 描邊 2.5D 圖示插畫

- 固定暖深色中等描邊、兩段式陰影、幾何化結構；小尺寸與近義項辨識最穩定。
- 相較現有 Stage 6 產品圖更像完整圖示系統，若選定將重製現有六張，避免混搭。
- 檔案：`docs/evidence/final-artwork/style-gate/direction-c-outlined-2-5d.png`

## 選樣結果、產生與權利紀錄

使用者選定 B，並再次明確要求 App 與 PWA 同步。正式 61 張均以 B specimen 作風格參考，逐項使用 Codex built-in ImageGen 產生，再等比例輸出為 1024×1024 RGBA PNG；App 與 PWA 使用完全相同 bytes。完整共同 prompt、逐項 subject、hash 與路徑見 `docs/evidence/final-artwork/prompts.md`、`docs/evidence/final-artwork/manifest.tsv`。

| 檔案 | 日期 | 方法 | SHA-256 | 商用狀態 |
| --- | --- | --- | --- | --- |
| `direction-a-soft-3d.png` | 2026-09-27 | Codex built-in ImageGen；上列共同約束 + soft premium 3D clay-like product illustration | `5f497e5c6d7fa408577390a38f40080441cfcc942c55afbcebfe5e75cc2f49b5` | 待產品擁有者於商用前確認生成服務條款與內部法務要求 |
| `direction-b-paper-gouache.png` | 2026-09-27 | Codex built-in ImageGen；上列共同約束 + warm editorial cut-paper/gouache | `1c57be1632a31dfe7fd95e6c0d2a59958c02b9e4231be2ae45adb3d365d3388d` | 同上 |
| `direction-c-outlined-2-5d.png` | 2026-09-27 | Codex built-in ImageGen；上列共同約束 + outlined soft-isometric 2.5D | `2aba973d4b1518893ad4fa3b353359d0b5ed64ea130b61e08376e738af1d6a76` | 同上 |

完整 prompt 保存在 `docs/evidence/final-artwork/style-gate/prompts.md`；全目錄階段會為每個 stable ID 另記 prompt／方法／日期／hash。現有 Stage 6 六張素材的 provenance caveat 繼續有效，最終選定任何方向後都會重製造成混搭的舊素材，不直接把舊來源紀錄視為商用授權。

## App／PWA 與階段門

- iOS：61 個 imageset、exact-ID map、fallback regression 與兩張 contact sheet 已完成；本 artwork 分支不夾帶仍待驗收的 PD-052 catalog/recommendation candidate。
- PWA：在獨立、受版本控制的 Site worktree `codex/final-artwork` 完成 61 張相同 bytes、exact-ID map 與 service-worker precache；尚未公開部署。
- 候選的完整交付／測試／人工驗收範圍見 `final-artwork-delivery.md`。
- 未經明確「通過」不得建立 accepted tag、合併 main、TestFlight／App Store 發版或公開部署 PWA。
