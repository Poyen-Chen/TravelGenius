# PackSmart Worker

一個 Cloudflare Worker 同時負責：

| 路徑 | 用途 | 費用 |
|---|---|---|
| `GET /reference/v1/{manifest,countries,...}.json` | 參考資料熱更新（App 的 `PackSmartReferenceDataBaseURL`） | 靜態檔案請求免費、不限量 |
| `POST /v1/trivia` `{"countryCode":"JP","city":"京都"}` → `{"facts":[...]}` | 小史萊姆 AI 冷知識的 Claude 轉發 | Workers 免費方案每天 10 萬次；Claude 依用量計費 |
| `GET /health` | 健康檢查 | |

參考資料直接取自 `TravelGenius/Resources/SeedData`，部署前會驗證 manifest 的 SHA-256，並原封不動地複製，所以 App 端的雜湊檢查一定會通過。每次部署都是整包原子切換。

## 防濫用設計

- Worker 自己組 prompt，只接受 SeedData 裡有城市的國家，以及那些城市（`city` 為空字串代表整個國家），不能被當成通用的 Claude 入口。
- 每個地點的結果在 KV 快取 7 天，所以實際呼叫 Claude 的次數最多約「地點數 ÷ 7 天」。
- `DAILY_GENERATION_LIMIT`（預設 50）限制每天實際生成的次數，快取命中不計入。
- 超過額度或 Claude 失敗時回 503，App 會退回內建冷知識。
- **最後一道保險**：在 Anthropic Console 為這把 key 設定月費上限。

## 第一次部署

```sh
cd backend/worker
npm install
npx wrangler login                                  # 開瀏覽器登入 Cloudflare
npx wrangler kv namespace create TRIVIA              # 把輸出的 id 貼進 wrangler.jsonc
npx wrangler secret put ANTHROPIC_API_KEY            # 貼上專用的 Anthropic key
npm run deploy                                       # 網址會是 https://packsmart.<你的子網域>.workers.dev
```

## 日常更新

- **修改參考資料**：編輯 SeedData，執行 `python3 scripts/build_reference_manifest.py`，跑完 repo 根目錄的回歸測試後，再執行 `npm run deploy`。
- **本機開發**：把 `.dev.vars.example` 複製成 `.dev.vars` 並填入 key，然後執行 `npm run dev`。
- **型別檢查**：`npm run typecheck`。

## App 端串接（尚未完成）

- **參考資料**：在 Info.plist 加入 `PackSmartReferenceDataBaseURL` = `https://<worker>/reference/v1`。
- **AI 冷知識**：讓 `TriviaService` 在 Release 版改呼叫 `/v1/trivia`。上線前必須先完成隱私揭露與同意設計，因為城市名稱會傳給 Anthropic，使用者 IP 也會經過 Cloudflare。
