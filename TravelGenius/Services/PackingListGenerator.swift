//
//  PackingListGenerator.swift
//  TravelGenius
//

import Foundation
import SwiftData

/// 四層規則（基本／國家規定／文化／天氣／型態）產生打包清單，
/// 重新產生時只增補與移除「未打包的自動項目」，永不動到自訂與已打包項目。
enum PackingListGenerator {
    struct GeneratedItem: Identifiable {
        let name: String
        let category: PackingCategory
        let quantity: Int
        let reason: String
        let sortIndex: Int

        var id: String { name }
    }

    /// 自訂項目的分組與排序（固定最後）
    static let customReason = "自訂"
    static let customSortIndex = 1_000_000

    static func generate(
        for trip: Trip,
        preferences: UserPreferences = .load(),
        weatherTags: Set<String>? = nil
    ) -> [GeneratedItem] {
        let month = Calendar.current.component(.month, from: trip.startDate)
        var results: [GeneratedItem] = []
        var seenNames = Set<String>()

        for (ruleIndex, rule) in StaticDataStore.shared.packingRules.enumerated() {
            guard rule.applies(
                countryCode: trip.countryCode,
                month: month,
                preferences: preferences,
                weatherTags: weatherTags
            ) else { continue }
            for (itemIndex, item) in rule.items.enumerated() {
                // 同名項目只取第一次出現（例如夏季與換季都有摺疊傘）
                guard !seenNames.contains(item.nameZh) else { continue }
                seenNames.insert(item.nameZh)
                let quantity = item.perDay == true ? min(trip.totalDays, 7) : (item.quantity ?? 1)
                results.append(GeneratedItem(
                    name: item.nameZh,
                    category: PackingCategory(rawValue: item.category) ?? .other,
                    quantity: quantity,
                    reason: rule.reasonZh,
                    sortIndex: ruleIndex * 100 + itemIndex
                ))
            }
        }
        return results
    }

    /// 將產生結果合併進行程的清單：新項目加入、已不適用且未打包的自動項目移除
    @MainActor
    static func sync(
        trip: Trip,
        context: ModelContext,
        preferences: UserPreferences = .load(),
        weatherTags: Set<String>? = nil
    ) {
        let generated = generate(for: trip, preferences: preferences, weatherTags: weatherTags)
            .filter { !trip.excludedPackingNames.contains($0.name) }
        let existing = trip.packingItems ?? []
        let generatedNames = Set(generated.map(\.name))
        let existingNames = Set(existing.map(\.name))

        for item in generated where !existingNames.contains(item.name) {
            let packingItem = PackingItem(
                name: item.name,
                category: item.category,
                reasonKey: item.reason,
                quantity: item.quantity,
                isCustom: false,
                sortIndex: item.sortIndex,
                trip: trip
            )
            context.insert(packingItem)
        }

        for item in existing where !item.isCustom && !item.isPacked && !generatedNames.contains(item.name) {
            context.delete(item)
        }
    }
}
