# TravelGenius 旅行天才

All-in-one 旅行助手 iOS App（SwiftUI + SwiftData，iOS 17+）。完全離線運作、資料留在裝置上、繁體中文原生介面。

## 四大模組

| 分頁 | 模組 | 核心功能 |
|---|---|---|
| 行程 | Trip | 行程管理、旅程回顧與下次預算建議 |
| 記帳 | Runway ＋ ExpenseSnap | 跑道倒數「還能撐幾天」、紅黃綠燈、兩步記帳、津貼儀表、收據照片、CSV/PDF 報帳匯出 |
| 行李 | PackSmart | 海關風險警示卡（禁止／需許可／需申報）、四層規則自動生成打包清單（因為是…分組）、城市限定文化提醒、前一晚模式 |
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

## 架構

- SwiftData 模型：`Trip` ← `Expense`／`PackingItem`；`MedicalProfile`（獨立於行程）
- `Features/` 各模組互不引用，只共用 `Models/` 與 `Services/`
- Runway 與報帳共用同一筆 `Expense`（記一次帳、兩種視角）
- 匯率於記帳當下凍結（`rateToHome`），離線歷史不受日後匯率變動影響
