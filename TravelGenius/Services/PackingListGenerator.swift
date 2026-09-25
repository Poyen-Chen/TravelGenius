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
        preferences: UserPreferences? = nil,
        weatherTags: Set<String>? = nil,
        weatherReference: PackingWeather? = nil
    ) -> [GeneratedItem] {
        guard let preferences = preferences ?? trip.packingPreferences
            ?? (trip.packingPreferencesRaw.isEmpty ? UserPreferences.load() : nil) else { return [] }
        let snapshot = weatherReference ?? trip.packingWeather
        guard trip.packingWeatherRaw.isEmpty || snapshot != nil else { return [] }
        let effectiveWeatherTags = weatherTags ?? snapshot?.tags
        let month = Calendar.current.component(.month, from: trip.startDate)
        var results: [GeneratedItem] = []
        var seenIDs = Set<String>()
        let catalog = StaticDataStore.shared.packingCatalog
        let modern = preferences.usesExplicitNeeds
        var matchingPreferences = preferences
        if modern {
            matchingPreferences.ageBand = .adult
            matchingPreferences.gender = .undisclosed
            matchingPreferences.party = .solo
        }

        for (ruleIndex, rule) in StaticDataStore.shared.packingRules.enumerated() {
            guard rule.applies(
                countryCode: trip.countryCode,
                month: month,
                preferences: matchingPreferences,
                weatherTags: effectiveWeatherTags
            ) else { continue }
            for (itemIndex, item) in rule.items.enumerated() {
                if modern && ["regular-medicine", "stomach-medicine", "charging-kit"].contains(item.itemId) { continue }
                // 輕便打包：略過「完整才帶」的加分項目
                if (preferences.packingStyle == .light || (modern && preferences.packingStyle == .normal)) && item.fullOnly == true { continue }
                // Stable identity, first matching rule wins (same precedence as before).
                guard seenIDs.insert(item.itemId).inserted,
                      let definition = catalog.item(id: item.itemId) else { continue }
                let perDayCap = preferences.packingStyle == .light ? 4 : (modern ? 99 : 7)
                let quantity = item.perDay == true ? min(trip.totalDays, perDayCap) : (item.quantity ?? 1)
                results.append(GeneratedItem(
                    catalogItemID: definition.id,
                    name: definition.nameZh,
                    category: definition.category,
                    quantity: quantity,
                    reason: rule.layer == "weather" && snapshot != nil
                        ? "\(snapshot!.reason(for: rule.match?.weatherTags ?? []))・\(weatherReason(rule.match?.weatherTags ?? []))"
                        : modern && rule.layer == "party" ? "旅行證件與行李收納" : rule.reasonZh,
                    sortIndex: ruleIndex * 100 + itemIndex
                ))
            }
        }

        if modern {
            func append(_ id: String, reason: String) {
                guard seenIDs.insert(id).inserted, let definition = catalog.item(id: id) else { return }
                results.append(.init(catalogItemID: id, name: definition.nameZh, category: definition.category,
                    quantity: 1, reason: reason, sortIndex: 5_000 + results.count))
            }
            for option in PersonalPackingOptions.devices where preferences.devices?.contains(option.id) == true {
                for id in option.itemIDs { append(id, reason: "我的常用設備：\(option.label)") }
            }
            if !(Set(preferences.devices ?? []).intersection(["phone", "tablet", "headphones"])).isEmpty {
                append("charging-kit", reason: "常用設備共用充電用品・請確認接頭、功率與數量")
            }
            for option in PersonalPackingOptions.needs where preferences.needs?.contains(option.id) == true {
                for id in option.itemIDs { append(id, reason: "我的常備需求：\(option.label)") }
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

    /// Read-only proposal. Never rewrites identity, exclusions, quantity or packed state.
    static func missingItems(for trip: Trip, weather: PackingWeather? = nil) -> [GeneratedItem] {
        let catalog = StaticDataStore.shared.packingCatalog
        let existing = trip.packingItems ?? []
        let ids = Set(existing.compactMap { $0.catalogItemID ?? catalog.legacyID(name: $0.name) })
        let names = Set(existing.map(\.name))
        let excluded = trip.excludedPackingIDs.union(trip.excludedPackingNames.compactMap { catalog.legacyID(name: $0) })
        return generate(for: trip, weatherReference: weather).filter {
            !ids.contains($0.id) && !names.contains($0.name)
                && !excluded.contains($0.id) && !trip.excludedPackingNames.contains($0.name)
        }
    }

    /// Recheck against current items/exclusions at confirmation, then insert only chosen candidates.
    /// A failed save removes only this operation's inserts, never rolls back unrelated user edits.
    @MainActor
    @discardableResult
    static func addMissing(trip: Trip, selectedIDs: Set<String>, weather: PackingWeather?, context: ModelContext) throws -> Int {
        let additions = missingItems(for: trip, weather: weather).filter { selectedIDs.contains($0.id) }
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosave }
        var inserted: [PackingItem] = []
        do {
            for candidate in additions {
                let item = PackingItem(name: candidate.name, category: candidate.category,
                    reasonKey: candidate.reason, quantity: candidate.quantity, isCustom: false,
                    sortIndex: candidate.sortIndex, trip: trip)
                item.catalogItemID = candidate.id
                context.insert(item); inserted.append(item)
            }
            try context.save()
            return inserted.count
        } catch {
            for item in inserted { context.delete(item) }
            throw error
        }
    }

    private static func weatherReason(_ tags: [String]) -> String {
        if tags.contains("rain") { return "雨具參考" }
        if tags.contains("hot") { return "防曬與炎熱天氣準備" }
        if tags.contains("cold") { return "保暖準備" }
        return "可增減的外層衣物"
    }

    /// 將產生結果合併進行程的清單：新項目加入、已不適用且未打包的自動項目移除
    @MainActor
    static func sync(
        trip: Trip,
        context: ModelContext,
        preferences: UserPreferences? = nil,
        weatherTags: Set<String>? = nil
    ) {
        trip.capturePackingPreferencesIfNeeded(preferences ?? .load())
        // A corrupt snapshot must never become an empty destructive merge.
        guard let frozenPreferences = trip.packingPreferences else { return }
        guard trip.packingWeatherRaw.isEmpty || trip.packingWeather != nil else { return }
        let catalog = StaticDataStore.shared.packingCatalog
        trip.excludedPackingIDs.formUnion(trip.excludedPackingNames.compactMap { catalog.legacyID(name: $0) })
        let generated = generate(for: trip, preferences: frozenPreferences, weatherTags: weatherTags)
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
