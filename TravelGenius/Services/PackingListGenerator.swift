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
    /// 從個人行李庫「每趟必帶」自動帶入的項目，在清單裡自成一組
    static let libraryEssentialReason = "我的必帶"
    static let customSortIndex = 1_000_000

    /// - Parameter preferences: 不傳則沿用行程快照。草稿也會同步，因此不可預設讀裝置偏好，
    ///   否則同一份草稿在兩台裝置會看到不同的建議清單。
    static func generate(
        for trip: Trip,
        preferences: UserPreferences? = nil,
        weatherTags: Set<String>? = nil
    ) -> [GeneratedItem] {
        let preferences = preferences ?? trip.packingPreferences
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
                // 輕便打包：略過「完整才帶」的加分項目
                if preferences.packingStyle == .light && item.fullOnly == true { continue }
                // 同名項目只取第一次出現（例如夏季與換季都有摺疊傘）
                guard !seenNames.contains(item.nameZh) else { continue }
                seenNames.insert(item.nameZh)
                let perDayCap = preferences.packingStyle == .light ? 4 : 7
                let quantity = item.perDay == true ? min(trip.totalDays, perDayCap) : (item.quantity ?? 1)
                results.append(GeneratedItem(
                    name: item.nameZh,
                    category: PackingCategory(rawValue: item.category) ?? .other,
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
    /// - Parameter preferences: 傳入值代表「使用者剛改了偏好」，會一併寫回行程快照。
    ///   不傳則沿用行程既有快照——絕不可改讀裝置當下偏好，否則另一台裝置會依自己的
    ///   偏好刪掉本機產生的項目，再同步回來造成跨裝置資料破壞。
    @MainActor
    static func sync(
        trip: Trip,
        context: ModelContext,
        preferences: UserPreferences? = nil,
        weatherTags: Set<String>? = nil
    ) {
        if let preferences { trip.packingPreferences = preferences }
        let preferences = trip.packingPreferences
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
