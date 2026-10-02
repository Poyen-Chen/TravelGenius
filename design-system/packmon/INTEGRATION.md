# Packmon Design System Integration

`TravelGenius/SharedUI/PackmonDesignSystem.swift` 是 App 內唯一的設計 token 入口。
Feature 畫面只應使用 `@Environment(\.packmonTheme)` 取得語意 token，避免直接依賴某一版設計稿的色碼與尺寸。

## 結構

- `PackmonThemeID`：測試人員可選擇的設計版本。
- `PackmonTheme`：顏色、間距與圓角 token。
- `PackmonCard`、`PackmonPrimaryButtonStyle`：跨 Feature 的共用元件。
- `RootGateView`：從 `AppStorage` 讀取版本，注入整個 SwiftUI view tree。
- `PreferenceSettingsView`：App 內的設計版本切換器。

## 目前可驗證版本

- `current`：改版前的系統色基準。
- `structureC`：目前產品基準，沿用 Claude Design「結構 C 完整版」。
- `warmCompanion`：品牌提案 A，以品牌暖橘承擔主要 CTA，信任藍作輔助。
- `trustBlueCTA`：品牌提案 B，以信任藍承擔主要 CTA，暖橘保留品牌識別。

兩個品牌提案只替換顏色 token，刻意沿用結構 C 的間距、圓角、導航、內容與資料，避免一次改動太多變因。它們是驗證選項，不代表品牌方向已定案。

## 從 Claude Design 導入新版 UI

1. 固定一份交付：流程圖、每個畫面的各狀態截圖、元件清單、token 表、圖示與圖片素材。
2. 先替 `PackmonThemeID` 增加新版 case，將色彩、間距、圓角映射進 `PackmonTheme`。
3. 將重複出現的視覺元素做成 `Packmon` 前綴元件，不要把整張產生的畫面直接覆蓋現有 Feature。
4. 保留既有 SwiftData、Service 與導航狀態；只替換 View composition 和元件。
5. 在偏好設定切換現行版與新版，逐頁比對 onboarding、建立行程、清單、Tips、空白、載入、錯誤和深色模式。
6. 新版穩定後才把它改成預設值；至少保留前一版到測試完成。

## Token 命名原則

- 用用途命名：`accent`、`canvas`、`surface`、`danger`。
- 不用外觀命名：避免 `green500`、`lightGrayBackground` 出現在 Feature。
- 與內容意義有關的顏色，例如海關禁止、警告、成功，必須由 theme 提供。
- 暫時只出現一次的尺寸可以留在 View；跨兩個以上畫面重複才提升為 token 或元件。

## 建議交付格式

Claude Design 的每次變更最好包含：

- flow 名稱與版本日期
- 畫面／狀態清單
- old → new 導航差異
- token JSON 或表格
- 每個元件的 states、尺寸與 accessibility 行為
- 390pt iPhone、較大 Dynamic Type、Dark Mode 截圖

這些資料可以讓 agent 先做 token／元件層，再分批改 Feature，降低一次重寫整個 App 的風險。
