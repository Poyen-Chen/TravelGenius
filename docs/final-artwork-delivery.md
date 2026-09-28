# Packmon 最終物品圖候選交付

日期：2026-09-27；整合修正：2026-09-28。方向：B — warm editorial cut-paper／gouache。狀態：PWA 已部署，App 的 V1 catalog＋最終圖片整合候選已完成模擬器建置；未建立 accepted tag、未發布 TestFlight／App Store。

## 結果

- 覆蓋：61/61 active stable IDs（文件 6、衣物 26、電子 13、盥洗 7、其他 9）。
- 規格：每張 1024×1024、PNG、sRGB、RGBA 真透明背景；左上柔光、暖紙感、低飽和深藍／暖灰、少量暖橘、至少 13% 安全留白。
- 一致性：App 與 PWA 每個 ID 的 PNG bytes 完全相同；61 個 SHA-256 彼此不重複。
- 身份：每個 canonical active item definition 明確擁有 `artworkKey`；行程項目按 stable ID 解析定義，無第二份 61-ID 圖片 registry、無 fuzzy name matching。自訂、未知、相容性-only 與載入失敗仍顯示帶名稱的分類 fallback。
- 重製：61 張全部重製。移除舊 `cable`、`charger`、`clothes`、`umbrella`；原有 `passport`、`sunscreen` 亦被取代。無正式圖沿用。

## 雙端狀態

- App：`codex/packmon-final-artwork`；整合 PD-052 的 V1 catalog candidate 與 61 個 asset catalog 圖。`packing_items.json` 的每個 active item 自帶 `artworkKey`，舊資料保留 read-only exact-name 相容；新清單中的 61 個 active stable IDs 全數有對應圖片。
- PWA：V1 item definitions 的 61 個 `artworkKey` 全數解析並 precache；正式 Site 13 目前使用 `packmon-v26-final-artwork-hotfix`，definition-owned refactor candidate 使用 `packmon-v27-item-owned-artwork`，尚未重新部署。
- 共同 fallback：舊行程若尚未保存 stable ID，App 會透過目前 catalog 的 exact-name／明列 legacy name 還原 ID；PWA 使用相同 catalog identity。未知、自訂與近義名稱不做 fuzzy matching，仍顯示分類 fallback。

## 證據與驗收

- 奶油背景 contact sheet：`docs/evidence/final-artwork/contact-sheet-cream.png`
- 深色背景 contact sheet：`docs/evidence/final-artwork/contact-sheet-dark.png`
- prompts：`docs/evidence/final-artwork/prompts.md`
- hash／雙端路徑：`docs/evidence/final-artwork/manifest.tsv`
- 自動檢查：61/61 檔案、1024×1024、alpha、無重複 hash、App/PWA byte parity、exact-ID／fallback／近義充電配件、PWA precache、App build 與既有 packing regression。

人工驗收請特別並排看：四種充電配件、五類鞋、三類袋、商務／正式服裝，以及奶油與深色背景的透明邊緣。圖片是輔助資訊；名稱、數量、完成狀態和操作仍必須可獨立使用。

## 權利與發版界線

素材以 Codex built-in ImageGen 生成，無外部品牌素材或第三方照片直接嵌入。這份來源紀錄不是法律意見或商用授權保證；商業發行前仍由產品擁有者確認生成服務條款與內部法務要求。未經使用者明確「通過」，不得建立 accepted tag、合併 main、TestFlight／App Store 發版或公開部署 PWA。
