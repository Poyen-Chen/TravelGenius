---
name: travelgenius-packing-engine
description: TravelGenius 的資料來源與打包清單產生邏輯。做前端 UI 串接、改打包規則、或要理解「清單為什麼長這樣」時使用。涵蓋六個 JSON 資料契約、context tag 代數、need 解析、以及重算時不可違反的不變條件。
---

# TravelGenius 打包引擎與資料契約

寫給要串接 UI 的人。重點：**這個 App 沒有自己的後端**，所以沒有 REST API 可以打。
「後端」對前端而言是兩樣東西——CDN 上的靜態 JSON，以及一個跑在裝置上的規則引擎。

Repo：`github.com/Poyen-Chen/TravelGenius`（分支 `main` 為聚焦版）
相關 PR：[#7](https://github.com/Poyen-Chen/TravelGenius/pull/7)（CloudKit 同步、跨裝置修復、個人行李庫）、[#8](https://github.com/Poyen-Chen/TravelGenius/pull/8)（tag 代數改造、測試）

---

## 1. 資料從哪裡來

| 來源 | 內容 | 前端要知道的事 |
|---|---|---|
| **裝置本機（SwiftData）** | 行程、打包項目、行李庫 | 唯一的真實來源。UI 讀寫這裡 |
| **CloudKit 私有資料庫** | 同上，鏡像 | 自動同步，不需要寫任何同步程式碼或登入流程 |
| **jsDelivr CDN** | 六個參考資料 JSON | 唯讀。啟動時以 ETag 比對，**下次啟動**才生效 |
| **WeatherKit** | 目的地預報 | 產生 `weather:*` tag，失敗時退回月份推估 |
| **OpenAI / Anthropic** | 打包圖、冷知識 | 選用，需明確同意。Release 版不含金鑰，實際是關閉的 |

CDN base：
```
https://cdn.jsdelivr.net/gh/Poyen-Chen/TravelGenius@main/TravelGenius/Resources/SeedData/
```

六個檔：`countries` `cities` `packing_items` `packing_rules` `prohibited_items`
`aviation_rules` `etiquette`（皆為 `<name>.json`）。

**推到 `main` 就等於發布給所有使用者**，不必送審。代價是 main 等同生產環境。
新增檔案時必須同步更新 `ReferenceDataUpdater.files` 與其 `isValid` 驗證分支，
否則新檔不會被下載，或壞資料會進快取。

---

## 2. 資料契約

權威定義在 `TravelGenius/Services/StaticDataStore.swift` 的 Codable struct。
下面是前端會用到的欄位，非完整複製。

### packing_items.json — 物品目錄

每件東西只定義一次，規則以 `id` 引用。

```json
{ "id": "umbrella-folding", "nameZh": "摺疊傘", "category": "other",
  "weightGrams": 350, "tags": ["bulky"],
  "satisfies": ["rain-cover"], "priority": 10 }
```

- `category`：`clothing` / `electronics` / `documents` / `toiletries` / `health` / `other`
- `weightGrams`：省略或 0 時交給 `PackingWeight` 依關鍵字估算
- `satisfies`：這件物品能滿足哪些需求，讓多件物品成為同一需求的候選
- `priority`：同一需求的候選排序，**數字小的優先**，未指定視為 10

### packing_rules.json — 情境與需求

```json
{ "id": "weather-rain",
  "when": { "all": ["weather:rain"], "none": ["style:light"] },
  "reasonZh": "因為預報有雨",
  "needs": [
    { "need": "rain-cover" },
    { "itemId": "dry-bag", "when": { "none": ["style:light"] } },
    { "itemId": "clothes-change", "perDay": true },
    { "itemId": "hand-warmer", "quantity": 5 }
  ] }
```

- `when`：`all`（全部須命中）/ `any`（至少一個）/ `none`（一個都不能有）。三者皆省略＝永遠成立
- `needs[].itemId` 直接取物品；`needs[].need` 透過 `satisfies` 索引解析
- `needs[].when` 用**同一套代數**，讓一條規則能依情境增減內容
- `perDay: true` 數量隨天數成長，受打包風格上限節制（輕便 4、完整 7）
- `reasonZh` 支援佔位符：`{originCountry}` `{destinationCountry}` `{plugTypes}` `{days}`

**`reasonZh` 就是 UI 上的分組標題**，不是註解。清單畫面依它分組顯示
（「因為是日本」「因為天氣炎熱」「我的必帶」）。

### prohibited_items.json — 違禁品

**一國一筆**，不是一個物品掛多國標籤。

```json
{ "countryCode": "JP", "itemZh": "感冒藥（含偽麻黃鹼）",
  "severity": "banned",
  "reasonZh": "含偽麻黃鹼成分違反日本覺醒劑取締法，攜帶恐涉刑責。",
  "lastVerified": "2026-06",
  "sourceName": "日本厚生勞動省", "sourceUrl": "https://...",
  "aliases": ["感冒藥", "伏冒", "斯斯"], "keywords": ["感冒"],
  "exclusions": [] }
```

- `severity`：`banned`（禁止）/ `permit`（需許可）/ `declare`（需申報）
- `aliases` 用來比對使用者輸入的口語（打「斯斯」要認得出是日本禁帶品）
- `keywords` 是較寬的模糊命中
- **`sourceUrl` 必須在 UI 上可點**。海關規定會變，每筆都記錄 `lastVerified` 與官方出處

同一件東西各國標法可能完全不同——電子煙在日本是 `permit`、新加坡與泰國是 `banned`。
現金九個國家全是 `declare`，但門檻與幣別各異。

### aviation_rules.json — 航空安檢

```json
{ "itemZh": "行動電源", "restriction": "carryOnOnly",
  "detailZh": "...", "lastVerified": "2026-06",
  "countries": ["JP","TW"], "aliases": [...] }
```

- `restriction`：`banned` / `carryOnOnly`（限隨身）/ `checkedOnly`（限托運）/ `limited`（限量）
- `countries` 省略＝適用所有航線；有值時以航線國家集合取交集判定

### countries.json / cities.json / etiquette.json

```json
// Country
{ "code": "JP", "nameZh": "日本", "nameEn": "Japan",
  "currencyCode": "JPY", "languageCode": "ja",
  "emergency": { "police": "110", "ambulance": "119", "fire": "119" },
  "plugTypes": ["A","B"], "voltage": "100V", "sourceUrl": "..." }

// City
{ "countryCode": "JP", "cityZh": "東京",
  "lat": 35.68, "lon": 139.69, "isDefault": true, "sourceUrl": "..." }

// EtiquetteCard
{ "countryCode": "JP", "cityZh": null,
  "titleZh": "...", "bodyZh": "...", "sourceName": "...", "sourceUrl": "..." }
```

`Country.plugTypes` 會被拿去推導插座相容性（見下節），不只是顯示用。

---

## 3. 清單怎麼產生

`TravelGenius/Services/PackingListGenerator.swift`

```
Trip + UserPreferences + 天氣
  → contextTags()        攤平成 tag 集合
  → 規則比對              when 的 all / any / none 集合運算
  → need 解析             satisfies 索引，取 priority 最小的候選
  → 依 catalogItemId 去重  不是比名稱
  → 算數量                perDay 受打包風格上限節制
```

### Context tags 實例

一趟九月的台北→東京五天獨旅，未取得預報：

```
age:adult          country:JP        days:5
duration:medium    experience:some   forecast:estimated
gender:undisclosed month:9           origin:TW
party:solo         plug:compatible   style:full
weather:hot
```

推導規則：

| Tag | 來源 |
|---|---|
| `country:` `origin:` | Trip 的目的地與出發地 |
| `month:` `days:` `duration:` | 日期。`duration` 分桶：≤3 short、≤7 medium、其餘 long |
| `weather:` | 有預報用預報並加 `forecast:live`；否則月份推估並加 `forecast:estimated` |
| `party:` `experience:` `age:` `gender:` `style:` | 偏好。`style` 為 `light` 或 `full` |
| `plug:` | 比對兩國 `plugTypes` 是否有交集，得 `compatible` 或 `incompatible` |

**月份推估是北半球假設**（6–9 熱、12–2 冷、其餘溫和）。目前只做東亞三國所以沒問題，
要擴到南半球必須先修這裡。

### 要新增一個判斷維度

- **只是「怎麼運用既有事實」** → 純改 JSON，推到 main 即生效
- **要引入「新的事實」**（活動類型、住宿有無洗衣機、廉航限重）→ 必須在
  `contextTags()` 裡產生新 tag，**這要改 Swift 並送審**。UI 也要提供讓使用者輸入該資訊的地方

這條界線是這個設計目前的邊界，不要假設 JSON 能做到全部。

---

## 4. UI 不可違反的不變條件

這幾條有測試鎖住（`TravelGeniusTests/PackingSyncTests.swift`），改壞了會紅。

1. **偏好快照跟著行程走，不是跟著裝置。**
   `Trip` 自己存了一份產生清單時所用的偏好。`sync()` 不傳 `preferences` 時一律讀這份快照，
   **絕不可改讀裝置當下偏好**——否則第二台裝置開啟同一行程時，會依它本機的偏好刪掉項目再同步回去。
   傳入 `preferences` 的語意是「使用者剛改了偏好」，會一併更新快照。

2. **已打包（`isPacked`）與自訂（`isCustom`）的項目永不被刪。**
   東西已經在行李箱裡了，規則變了也不能讓它從清單消失。

3. **重算只增補、移除、更新數量，不重建整份清單。** 同樣偏好跑兩次，項目數不變。

4. **比對用 `catalogItemId`，不是名稱。** 舊版建立的項目 id 為空字串，會退回比名稱，
   所以升級不會產生重複。新建項目務必填入 id。

5. **`context.delete()` 之後關聯陣列還留著已刪物件**，要存檔再重新查詢才看得到真實狀態。
   這個陷阱害我寫出過一條永遠不會失敗的測試。

---

## 5. 個人行李庫

`TravelGenius/Services/PackingLibrary.swift`、`Models/PackingLibraryItem.swift`

跨行程累積使用者實際會帶的東西。UI 相關行為：

- 每次新增自訂項目就收進行李庫，**同名（正規化後）只累加 `useCount`，不重複建立**
- 傳入 `weightGrams` 為 0 時**不會**把既有重量蓋掉
- 標記 `isEssential` 的項目，建立新行程時自動加入，歸在 `我的必帶` 這一組
- 跟著 CloudKit 同步

管理畫面：`Features/Trips/PackingLibraryView.swift`（偏好設定 → 個人化 → 我的行李庫）

已知缺口：**還沒有編輯重量的介面**，所以自動帶入的項目會沿用分類預設重量。

---

## 6. 環境與踩過的坑

- **模擬器**：Xcode 27 沒有 `Simulator.app`，改為 `Xcode.app/Contents/Applications/DeviceHub.app`
- **Orca emulator pane**：DeviceHub 開著會搶走觸控注入，且 `tap` 仍回報成功。
  裝置轉橫向時注入座標會錯亂。helper 也可能進入「讀得到但寫不進」的狀態——
  遇到點不動：先確認 DeviceHub 沒開 → 確認不是橫向 → `orca emulator kill` 再 `attach`
- **`xcodebuild test`** 剛建置完的第一次執行常全部 0.000 秒失敗（test host 啟動失敗），重跑即可。
  接 CI 要納入重試
- **`INFOPLIST_KEY_UIBackgroundModes` 不被 Xcode 支援**，設了會被靜默忽略，必須寫在真實 Info.plist

---

## 7. 上架前未完成事項

- `DEVELOPMENT_TEAM` 仍為空字串
- CloudKit container `iCloud.com.travelgenius.app` 尚未在開發者後台建立
- `aps-environment` 目前是 `development`，上架必須改 `production`
- 雲端 AI 的金鑰代理未實作（Release 版不含金鑰，AI 功能實際是關的）
- **CloudKit 真實同步從未驗證**，需要兩台登入同一 iCloud 帳號的實機
- `Expense` 與 `MedicalProfile` 仍註冊在 schema 但**完全沒有 UI**。
  這代表 CloudKit 會同步使用者看不到也刪不掉的資料，其中醫療卡屬特種個資。
  隱私政策目前是照「有醫療卡」寫的，比實際功能寬。**這個狀態要先決定怎麼收**

---

## Suggested skills

下一個 session 視任務呼叫：

- **`claude-api`** — 任何碰到 Anthropic／OpenAI 整合、模型字串、金鑰代理設計的工作。
  不要憑記憶回答模型 id 或價格
- **`mattpocock-skills:tdd`** — 要動 `PackingListGenerator` 或 `sync()` 時。
  測試 target 已建好（`TravelGeniusTests`，Swift Testing），先確認 seam 再寫
- **`mattpocock-skills:diagnosing-bugs`** — 清單內容不如預期時。
  先確認是規則資料問題還是引擎問題，別急著改 Swift
- **`run`** — 要在模擬器上實際驗證時，先看本文件第 6 節的坑
- **`artifact-design`** — 要產出給人看的文件或簡報時

不建議呼叫 `graphify`（專案沒有 `graphify-out/`）。
