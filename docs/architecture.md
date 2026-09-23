# Packmon 專案架構

## 一句話

Packmon 是 SwiftUI + SwiftData 的原生 iOS App；畫面層只組合狀態與語意元件，打包、違禁品、天氣與小工具同步由既有 Service 負責。

## 結構 C 導航

```mermaid
flowchart TD
    Root[RootGateView] --> Tabs[固定四個主分頁]
    Tabs --> Trips[行程]
    Tabs --> Checker[查詢]
    Tabs --> Knowledge[知識]
    Tabs --> Profile[我的]
    Trips --> TripList[行程列表：有／無行程]
    TripList --> Create[新行程建立]
    TripList --> Workspace[行程工作區]
    Workspace --> Overview[總覽]
    Workspace --> Packing[打包]
    Workspace --> Restrictions[違禁品]
    Workspace --> TripKnowledge[知識入口]
    Overview --> Airport[機場模式入口]
    Overview --> Return[回程模式入口]
    Profile --> Staples[常備清單入口]
    Profile --> History[歷史回顧入口]
```

## 程式邊界

```mermaid
flowchart LR
    Views[SwiftUI Features] --> State[AppState / MascotState]
    Views --> Theme[PackmonTheme tokens + components]
    Views --> Data[SwiftData models]
    Views --> Services[Domain services]
    Services --> Rules[JSON seed rules]
    Services --> Data
    Services --> External[Open-Meteo / official source links]
    Data --> Widget[WidgetSync]
```

## 資料流

- `Trip` 是行程聚合根，關聯 `PackingItem` 與既有 `Expense`。
- `TripCreationFlowView` 建立並寫入 `Trip`，接著呼叫 `PackingListGenerator.sync`。
- `PackingListGenerator` 讀取使用者偏好、日期／天氣標籤與 JSON 規則，合併成 SwiftData 清單。
- `CanIBringService` 同時比對目的地海關、回程海關與航空安檢資料；獨立查詢與行程違禁品共用同一份資料來源。
- `WeatherService` 成功時補上天氣標籤，失敗時維持月份規則，不讓清單流程卡住。
- `WidgetSync` 在行程、清單狀態改變或 App 離開前景時同步摘要。

## 設計系統

- 唯一 token 入口：`SharedUI/PackmonDesignSystem.swift`。
- Feature 經由 `@Environment(\.packmonTheme)` 讀取顏色、間距、圓角。
- `PackmonThemeID` 讓現行版與「結構 C」並存；測試人員可在「我的 → 偏好與外觀」直接切換。
- 共用元件目前包含卡片、列卡、狀態膠囊、主按鈕與 Packmon 吉祥物。

## 第一階段範圍

已接通：行程列表、新行程、總覽、打包、違禁品、獨立查詢。

只保留入口：機場模式、回程模式、我的、常備清單、歷史回顧、行程知識。

