# PackSmart Supabase 後端

帳號、雲端同步與管理後台的伺服器端（PD-062、`docs/supabase-plan.md`）。**目前只在本機測試過，還沒有建立或連線任何 Supabase 專案，App 也還沒串接。**

## 內容

```text
supabase/
├── config.toml
├── migrations/
│   ├── 202610260001_user_documents.sql   # 使用者資料、RLS、sync_document、健康類同意
│   └── 202610260002_admin.sql            # 管理員名單、稽核紀錄、管理員函式
├── functions/
│   ├── delete-account/                   # 使用者刪除自己的帳號
│   └── admin-delete-user/                # 管理員刪除使用者帳號
└── tests/                                # PGlite＋模擬環境，不連網路上的服務
```

## 本機測試

```sh
cd supabase/tests
npm install
npm test
```

不需要 Docker 或 Supabase 帳號。資料庫測試用 PGlite 在記憶體裡跑真正的 PostgreSQL 並載入兩個 migration；Edge Function 測試用模擬的 Supabase 執行真正的函式程式碼。

## 在本機跑完整的 Supabase（看得到後台畫面）

需要 Docker（或 OrbStack）與 Supabase CLI：

```sh
brew install supabase/tap/supabase
brew install --cask docker        # 或 brew install --cask orbstack
```

打開 Docker 後，在 repo 根目錄：

```sh
supabase start                    # 第一次要下載映像檔，約需幾分鐘；會自動套用 migrations
cd supabase/tests && npm install && npm run smoke
```

`supabase start` 會一併啟動 Edge Functions。`npm run smoke` 會建立 alice、bob、support 三個 `@smoke.packsmart.test` 測試帳號，用各自的 token 走一遍同步、使用者隔離、健康類同意、管理員 MFA 與稽核、刪除帳號，逐項顯示 ✔／✘。腳本只允許連到本機，每次執行會先刪除上一次的測試帳號。

跑完打開 Studio（`supabase start` 會顯示網址，通常是 http://127.0.0.1:54323）：

- **Table Editor → `user_documents`**：Alice 的行程與常備用品。
- **Table Editor → `admin_audit_log`**：support 每次查詢、查看、修改的紀錄。
- **Authentication**：測試帳號；support 有一個 TOTP 因子。

**對雲端測試專案跑同一套測試**（先 `supabase login`）：

```sh
SMOKE_PROJECT_REF=<測試專案的 ref> npm run smoke
```

key 由 CLI 取得、只留在記憶體，不會印出或寫進檔案。只對**測試**專案使用：腳本會建立、刪除 `@smoke.packsmart.test` 的帳號。

Studio 的 SQL Editor 以最高權限執行，會繞過 RLS 與管理員檢查；權限要用 `npm run smoke` 這種「以使用者 token 呼叫 API」的方式驗證。

結束：`supabase stop`（資料保留）或 `supabase stop --no-backup`（清空）。

## 權限一覽

| 誰 | 可以做 | 不能做 |
|---|---|---|
| 未登入 | 無 | 讀寫任何資料 |
| 一般使用者 | 讀自己的 `user_documents`；透過 `sync_document` 寫入；刪除自己的帳號 | 讀別人的資料、直接寫資料表、讀管理員名單或稽核紀錄 |
| 管理員（`admin_users`＋MFA） | 透過管理員函式查詢、查看、修改、刪除使用者資料；每次都寫入稽核紀錄 | 不填原因、沒有 MFA、刪除其他管理員帳號 |
| Dashboard 擁有者 | 全部（資料庫無法阻擋） | 依規定只做結構變更與緊急處理，限 1～2 人並開啟 MFA |

健康類物品（`categoryRaw = "health"`）只有在 payload 帶 `healthSyncConsent: true` 時才能寫入，用戶端忘了剔除也會被資料庫擋下。

## 第一次部署（之後再做）

1. 在 [Supabase](https://supabase.com/dashboard) 建立**測試**專案，選定資料地區。
2. 安裝 [Supabase CLI](https://supabase.com/docs/guides/cli)，在 repo 根目錄執行：

   ```sh
   supabase login
   supabase link --project-ref <測試專案的 ref>
   supabase db push
   supabase functions deploy delete-account
   supabase functions deploy admin-delete-user
   ```

   執行前先確認 CLI 顯示的目標專案是測試專案。
3. Auth 開啟 Email 登入與 MFA（TOTP）。內建寄信每小時只能寄 2 封，給一般使用者測試前要設定自訂 SMTP。
4. App 只放 Project URL 和 **publishable key**。**service_role／secret key 不能放進 App、PWA 或 repo**；Edge Function 由平台自動提供。

## 讓 App 連上 Supabase

1. 複製 `Config/Supabase.example.plist` 到 `TravelGenius/Resources/Supabase.plist`（已 gitignore），填入：
   - `URL`：專案網址，例如 `https://<ref>.supabase.co`；本機測試用 `http://127.0.0.1:54321`。
   - `PublishableKey`：**publishable key**（`sb_publishable_…`）。App 會拒絕 secret／service_role key。
   - `Region`：顯示在同意說明的資料地區，例如「新加坡」。
2. **登入信要有 6 位數驗證碼**：App 用驗證碼登入，不處理登入連結。
   - 本機：`config.toml` 已指定 `supabase/templates/login-code.html`。
   - 雲端：Dashboard → Authentication → Emails → Templates，把 **Magic link** 和 **Confirm signup** 的內容換成 `supabase/templates/login-code.html`（主旨「PackSmart 登入驗證碼」）。
3. 雲端內建寄信只能寄給專案成員、每小時 2 封；給其他人測試前要設定自訂 SMTP。

沒有 `Supabase.plist` 時，「我的 → 帳號與同步」會顯示「這個版本尚未設定雲端服務」，App 照舊只用本機資料。

## 新增管理員

管理員本人先在 App 註冊並設定 MFA，再由 Dashboard 擁有者在 SQL Editor 執行：

```sql
insert into public.admin_users (user_id)
select id from auth.users where email = 'support@example.com';
```

移除管理員：`delete from public.admin_users where user_id = '<user id>';`

## 管理員怎麼用

管理員用自己的帳號登入（需通過 MFA），以自己的 token 呼叫下列函式。每一個都要填 `p_reason`（至少 5 個字），會寫入 `admin_audit_log`。

| 用途 | 呼叫 |
|---|---|
| 用 Email 找使用者 | `rpc('admin_find_user', { p_email, p_reason })` |
| 查看使用者的全部資料 | `rpc('admin_list_documents', { p_user, p_reason })` |
| 修改一份資料 | `rpc('admin_update_document', { p_user, p_kind, p_id, p_expected_revision, p_payload, p_deleted: false, p_reason })` |
| 刪除一份資料 | 同上，`p_deleted: true`、`p_payload: null` |
| 刪除使用者帳號 | `POST /functions/v1/admin-delete-user`，body：`{ "user_id": "...", "reason": "..." }` |

修改時要帶目前的 `revision`；使用者剛好同步了新版本時會回傳 `conflict`，不會蓋掉。

## 查看稽核紀錄

由 Dashboard 擁有者在 SQL Editor 查看：

```sql
select created_at, actor_id, target_user_id, action, document_kind, document_id, reason
from public.admin_audit_log order by created_at desc limit 100;
```

## 已知限制

- Dashboard 擁有者可以直接讀寫所有資料表，不會留下這裡的稽核紀錄。
- 管理員函式目前沒有網頁介面，要用 Supabase 用戶端程式或 API 工具呼叫。
- 免費方案一週沒有使用會暫停，也沒有自動備份。
