# PackSmart 後端調整說明（`feature/visual-packing`）

日期：2026-10-20。

## 1. 新增：Cloudflare Worker（`backend/worker/`，尚未部署）

只用一個 Worker，負責兩件事：

| 路徑 | 用途 |
|---|---|
| `GET /reference/v1/*.json` | 給 App 的參考資料（國家、城市、打包規則、物品目錄…），App 可以不更新版本就換到新資料 |
| `POST /v1/trivia` | 小史萊姆的 AI 冷知識，由 Worker 轉發給 Claude（`claude-haiku-5-5`） |
| `GET /health` | 健康檢查 |

**選這個方案的原因**：預計前期使用者在 50 人以內，Workers 免費方案就夠用。靜態檔案的請求免費、不限量，也內建 ETag／304 快取驗證，不需要另外維護伺服器。

### 參考資料的發布方式

- `scripts/sync-reference.mjs` 把 App 內的 `SeedData` 原封不動複製到 `public/reference/v1/`。
- 複製前會先比對 `manifest.json` 裡記錄的 SHA-256，對不上就中止，避免發布 App 會拒收的資料。
- 每次部署是整包一起替換，不會出現新舊檔案混在一起的狀況。App 端的原子快取、下載不完整時退回內建資料，已有回歸測試涵蓋。

### AI 冷知識的防濫用設計

- API key 只存在 Worker secret，App 和 repo 裡都沒有。
- Prompt 由 Worker 自己組，只接受 SeedData 裡有的國家和城市，所以不能被拿來當通用的 Claude 入口。
- 每個地點的結果在 KV 快取 7 天。
- `DAILY_GENERATION_LIMIT` 預設每天最多實際生成 50 次，快取命中不計入。
- 用 structured output（JSON schema）固定輸出格式；回應被拒絕或解析失敗都當成失敗。
- 任何失敗都回 503，App 會改用內建的冷知識。

## 2. 修改：App 內推薦引擎（`PackingRuleEngine.swift`）

- 新增 `PackingReasonKind`：依每條規則檢查的標籤種類，推出物品被加入的原因，分為天氣、這趟安排、你的設定、目的地、常備。打包頁的原因徽章就是用這個資料畫的。
- 這只是顯示用的資料，推薦結果本身不變：原本 2,916 組 oracle 和 540 組矩陣的測試都照樣通過。
- `BackendRegression` 新增 `reasonKinds()` 測試，記錄在 PD-061。

## 希望檢視的地方

1. **每日上限計數不精準**：KV 只保證最終一致，同時湧入的請求可能讓實際生成次數略超過上限。真正的費用保險是在 Anthropic Console 設定月費上限。對 50 人的規模來說，這樣夠嗎？
2. **Worker 依賴 repo 結構**：Worker 直接 import `../../../TravelGenius/Resources/SeedData`，讓 App 和後端共用同一份資料。缺點是搬動資料夾就會壞掉。
3. **App 端還沒串接**：還要在 Info.plist 填入 `PackSmartReferenceDataBaseURL`，並讓 `TriviaService` 改呼叫 `/v1/trivia`。上線前也要先完成隱私揭露：城市名稱會傳給 Anthropic，使用者的 IP 也會經過 Cloudflare。
4. **還沒部署**：`wrangler.jsonc` 的 KV id 還是佔位字串 `REPLACE_WITH_KV_NAMESPACE_ID`。部署步驟寫在 `backend/worker/README.md`。
