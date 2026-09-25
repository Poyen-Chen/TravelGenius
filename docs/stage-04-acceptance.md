# 第四階段人工驗收紀錄

- 日期：2026-09-25。
- 核准：使用者明確回覆「驗收通過，下一階段」。
- App 功能提交：`c8af110ba67cf0b6c82907a8a64e3b2bec871efd`。
- 範圍：建立前天氣、Open-Meteo／季節備援、快照保護、精簡天氣卡與每日詳情；PD-033～039 的目前有效方向。WeatherKit 未啟用。
- PWA 已獨立發布第 8 版，來源 `4d16a44569d16a0976d2bea868c6fb59fe8458e4`，標記 `packmon-site-2026-09-25-parity`；含天氣呈現與 PD-040 分國城市。PWA 不納入 App Git tag。
- 前次建置、回歸及 UI 證據與限制詳見 ios-integration-plan.md；本次人工核准不代表額外完成實機、VoiceOver 或 WeatherKit 成功測試。
- 依流程以獨立驗收提交保存，再推送 annotated tag `packmon-ios-stage-04-accepted`；tag 不還原 SwiftData、UserDefaults 或 PWA localStorage。
- 下一階段：`codex/ios-05-recommendation-update`；C4 只補缺少項目或完整差異预覽仍需選擇，不因本次驗收自動核准。活動／住宿／洗衣仍不在範圍內。
