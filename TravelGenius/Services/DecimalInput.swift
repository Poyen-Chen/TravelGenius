//
//  DecimalInput.swift
//  TravelGenius
//

import Foundation

extension Decimal {
    /// 依裝置地區解析使用者輸入的金額：
    /// 先移除千分位符號，再把地區小數符號正規化為「.」。
    /// 例：德語區「12,50」→ 12.5、「1.250」→ 1250；台灣「1,250」→ 1250。
    static func fromUserInput(_ text: String, locale: Locale = .current) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let decimalSeparator = locale.decimalSeparator ?? "."
        let groupingSeparator = locale.groupingSeparator ?? ","
        var cleaned = trimmed
        if groupingSeparator != decimalSeparator {
            cleaned = cleaned.replacingOccurrences(of: groupingSeparator, with: "")
        }
        if decimalSeparator != "." {
            cleaned = cleaned.replacingOccurrences(of: decimalSeparator, with: ".")
        }
        return Decimal(string: cleaned)
    }
}
