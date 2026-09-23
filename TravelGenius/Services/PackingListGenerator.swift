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
        let catalogItemID: String
        let name: String
        let category: PackingCategory
        let quantity: Int
        let reason: String
        let sortIndex: Int

        var id: String { catalogItemID }
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
        var seenIDs = Set<String>()
        let catalog = StaticDataStore.shared.packingCatalog

        for (ruleIndex, rule) in StaticDataStore.shared.packingRules.enumerated() {
            guard rule.applies(
                countryCode: trip.countryCode,
                month: month,
                preferences: preferences,
                weatherTags: weatherTags
            ) else { continue }
            for (itemIndex, item) in rule.items.enumerated() {
                // 輕便打包：略過「完整才帶」的加分項目
                if preferences.packingStyle == .light && item.fullOnly == true { continue }
                // Stable identity, first matching rule wins (same precedence as before).
                guard seenIDs.insert(item.itemId).inserted,
                      let definition = catalog.item(id: item.itemId) else { continue }
                let perDayCap = preferences.packingStyle == .light ? 4 : 7
                let quantity = item.perDay == true ? min(trip.totalDays, perDayCap) : (item.quantity ?? 1)
                results.append(GeneratedItem(
                    catalogItemID: definition.id,
                    name: definition.nameZh,
                    category: definition.category,
                    quantity: quantity,
                    reason: rule.reasonZh,
                    sortIndex: ruleIndex * 100 + itemIndex
                ))
            }
        }

        // 插座轉接頭：比對出發地與目的地的插座規格，不相容才建議帶
        // （台灣→日本同為 Type-A/B 就不會出現）
        let store = StaticDataStore.shared
        if let destination = store.country(code: trip.countryCode),
           let origin = store.country(code: trip.originCountryCode),
           Set(destination.plugTypes).isDisjoint(with: origin.plugTypes) {
            let types = destination.plugTypes.joined(separator: "/")
            let originName = origin.nameZh
            results.append(GeneratedItem(
                catalogItemID: "plug-adapter",
                name: "插座轉接頭（當地 Type-\(types)）",
                category: .electronics,
                quantity: 1,
                reason: "因為插座規格與\(originName)不同",
                sortIndex: 90
            ))
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
        let catalog = StaticDataStore.shared.packingCatalog
        trip.excludedPackingIDs.formUnion(trip.excludedPackingNames.compactMap { catalog.legacyID(name: $0) })
        let generated = generate(for: trip, preferences: preferences, weatherTags: weatherTags)
            .filter { !trip.excludedPackingIDs.contains($0.catalogItemID) && !trip.excludedPackingNames.contains($0.name) }
        let existing = trip.packingItems ?? []
        // Assign identity in place: preserve UUID, packed state, quantity, name and custom records.
        for item in existing where !item.isCustom && (item.catalogItemID ?? "").isEmpty {
            item.catalogItemID = catalog.legacyID(name: item.name)
        }
        let generatedIDs = Set(generated.map(\.catalogItemID))
        let existingIDs = Set(existing.compactMap { item in
            (item.catalogItemID ?? "").isEmpty ? catalog.legacyID(name: item.name) : item.catalogItemID
        })
        let existingNames = Set(existing.map(\.name))

        for item in generated where !existingIDs.contains(item.catalogItemID) && !existingNames.contains(item.name) {
            let packingItem = PackingItem(
                name: item.name,
                category: item.category,
                reasonKey: item.reason,
                quantity: item.quantity,
                isCustom: false,
                sortIndex: item.sortIndex,
                trip: trip
            )
            packingItem.catalogItemID = item.catalogItemID
            context.insert(packingItem)
        }

        for item in existing where !item.isCustom && !item.isPacked {
            // Unknown legacy items are retained: an incomplete mapping must never erase user data.
            guard let id = item.catalogItemID, catalog.item(id: id) != nil,
                  !generatedIDs.contains(id) else { continue }
            context.delete(item)
        }
    }
}
