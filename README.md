# TravelGenius 旅行天才

All-in-one 旅行助手 iOS App（SwiftUI + SwiftData，iOS 17+）。完全離線運作、資料留在裝置上、繁體中文原生介面。

## 四大模組

| 分頁 | 模組 | 核心功能 |
|---|---|---|
| 行程 | Trip | 行程管理、旅程回顧與下次預算建議 |
| 記帳 | Runway ＋ ExpenseSnap | 跑道倒數「還能撐幾天」、紅黃綠燈、兩步記帳、津貼儀表、收據照片、CSV/PDF 報帳匯出 |
| 行李 | PackSmart | 海關風險警示卡（禁止／需許可／需申報）＋航空安檢規則（液體限制、行動電源 Wh、韓國 2025 新規）、四層規則自動生成打包清單（因為是…分組）、城市限定文化提醒、前一晚模式、回程模式（反向打包防遺留） |
| 醫療卡 | MedCard | 藥名學名對照、六語離線翻譯卡、大字模式、緊急畫面（當地急救電話快撥） |

另含主畫面 Widget（旅費跑道，小＋中尺寸，App Group 資料共享）。

## 定位

> **PackSmart 讓你出國前一眼看懂海關風險，再拿到專屬打包清單。**

先查海關風險，再打包 — 與一般打包 App 的根本差異。

## 開發

- Xcode 26+，開啟 `TravelGenius.xcodeproj`，scheme `TravelGenius`，Cmd+R
- CLI 建置：`DEVELOPER_DIR=/Applications/Xcode.app xcodebuild -project TravelGenius.xcodeproj -scheme TravelGenius -destination 'platform=iOS Simulator,name=iPhone 17' build`
- 開發用啟動引數：`-seedDemo`（載入東京商務行程示範資料）、`-openMoneyTab` / `-openPackTab` / `-openMedTab`、`-showEmergency` / `-showLargePrint` / `-showEtiquette`、`-exportDemo`
- 靜態資料（國家、匯率、津貼標準、打包規則、違禁品、文化提醒、藥名對照、醫療翻譯）都在 `TravelGenius/Resources/SeedData/*.json`，直接編輯即可擴充
- 實機安裝需在兩個 target 設定你的 Development Team，並註冊 App Group（`group.com.example.TravelGenius`）

## 資料來源

違禁品每一條目均於 App 內附官方來源連結與最後查證日期（`prohibited_items.json` 的 `sourceName` / `sourceUrl` / `lastVerified` 欄位）：

| 資料 | 來源 |
|---|---|
| 海關違禁品（日本） | [厚生勞動省](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/iyakuhin/yunyu/)・[動物檢疫所](https://www.maff.go.jp/aqs/)・[日本稅關](https://www.customs.go.jp) |
| 海關違禁品（泰國） | [泰國海關](https://www.customs.go.th)・[泰國觀光局](https://www.tatnews.org)・[藝術廳](https://www.finearts.go.th) |
| 海關違禁品（新加坡） | [新加坡海關](https://www.customs.gov.sg)・[衛生科學局 HSA](https://www.hsa.gov.sg) |
| 海關違禁品（美國） | [美國海關暨邊境保護局 CBP](https://www.cbp.gov/travel/us-citizens/know-before-you-go/prohibited-and-restricted-items) |
| 海關違禁品（韓國） | [關稅廳](https://www.customs.go.kr)・[農林畜產檢疫本部](https://www.qia.go.kr) |
| 海關違禁品（英國） | [GOV.UK 食品](https://www.gov.uk/bringing-food-into-great-britain)・[GOV.UK 現金申報](https://www.gov.uk/bringing-cash-into-uk) |
| 海關違禁品（越南） | [越南海關](https://www.customs.gov.vn) |
| 海關違禁品（義大利／歐盟） | [義大利海關暨專賣總署](https://www.adm.gov.it)・[歐盟執委會](https://food.ec.europa.eu) |
| 海關違禁品（台灣） | [財政部關務署](https://web.customs.gov.tw)・[動植物防疫檢疫署](https://www.aphia.gov.tw) |
| 航空安檢規則 | [交通部民用航空局](https://www.caa.gov.tw)・[IATA 鋰電池指引](https://www.iata.org/en/programs/cargo/dgr/lithium-batteries/)・[韓國國土交通部](https://www.molit.go.kr)（2025 行動電源新規） |
| 匯率（離線快取） | [臺灣銀行牌告匯率](https://rate.bot.com.tw/xrt)，記帳當下凍結 |
| 文化提醒（罰則類） | 各地官方機構（京都市、威尼斯／羅馬市政府、NEA、NOAA、台北捷運等，App 內附連結） |
| 藥名學名對照 | WHO 國際非專利藥名（INN）、台灣食藥署藥品許可證資料庫 |
| 急救電話 | 各國政府官方公告 |
| 津貼標準 | App 內建預設值（UI 已標示），供使用者依公司政策調整 |

> ⚠️ 法規與匯率可能變動，App 內顯示「最後查證日期」，出發前請以官方最新公告為準。

## 架構

- SwiftData 模型：`Trip` ← `Expense`／`PackingItem`；`MedicalProfile`（獨立於行程）
- `Features/` 各模組互不引用，只共用 `Models/` 與 `Services/`
- Runway 與報帳共用同一筆 `Expense`（記一次帳、兩種視角）
- 匯率於記帳當下凍結（`rateToHome`），離線歷史不受日後匯率變動影響
