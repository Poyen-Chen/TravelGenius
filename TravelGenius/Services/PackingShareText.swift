//
//  PackingShareText.swift
//  TravelGenius
//
//  把打包清單轉成可分享的純文字：同行者不用裝 App 也能對清單。
//

import Foundation

enum PackingShareText {
    static func make(for trip: Trip) -> String {
        let country = StaticDataStore.shared.country(code: trip.countryCode)
        var lines: [String] = []
        lines.append("【\(trip.name)】打包清單")
        lines.append("\(country?.flagEmoji ?? "") \(country?.nameZh ?? trip.countryCode)\(trip.city.isEmpty ? "" : "・\(trip.city)")　\(trip.startDate.formatted(date: .numeric, time: .omitted)) – \(trip.endDate.formatted(date: .numeric, time: .omitted))")
        lines.append("")

        let items = (trip.packingItems ?? []).sorted { $0.sortIndex < $1.sortIndex }
        var currentReason = ""
        for item in items {
            if item.reasonKey != currentReason {
                currentReason = item.reasonKey
                lines.append("■ \(currentReason)")
            }
            let box = item.isPacked ? "☑" : "☐"
            let quantity = item.quantity > 1 ? " ×\(item.quantity)" : ""
            lines.append("\(box) \(item.name)\(quantity)")
        }

        let banned = StaticDataStore.shared.prohibitedItems(countryCode: trip.countryCode)
            .filter { $0.severity == .banned }
        if !banned.isEmpty {
            lines.append("")
            lines.append("⚠️ 海關禁止攜帶：")
            for item in banned {
                lines.append("✗ \(item.itemZh)")
            }
        }

        lines.append("")
        lines.append("— 由 TravelGenius 產生")
        return lines.joined(separator: "\n")
    }
}
