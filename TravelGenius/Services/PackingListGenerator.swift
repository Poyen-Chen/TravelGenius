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
        /// 目錄 id。去重與比對都用它，不再用顯示名稱做鍵。
        let catalogItemID: String
        let name: String
        let category: PackingCategory
        let quantity: Int
        /// 目錄記載的單件重量，0 代表交給 PackingWeight 估算
        let weightGrams: Int
        let reason: String
        let sortIndex: Int

        var id: String { catalogItemID }
    }

    /// 自訂項目的分組與排序（固定最後）
    static let customReason = "自訂"
    /// 從個人行李庫「每趟必帶」自動帶入的項目，在清單裡自成一組
    static let libraryEssentialReason = "我的必帶"
    static let customSortIndex = 1_000_000

    // MARK: - Context tags

    /// 把一趟行程攤平成 tag 集合，規則只跟這個集合比對。
    /// 新增一個判斷維度（活動、住宿、行李限重…）只要在這裡多放一個 tag，
    /// 規則 JSON 就能立刻使用，不必改動比對邏輯。
    static func contextTags(
        for trip: Trip,
        preferences: UserPreferences,
        weatherTags: Set<String>?
    ) -> Set<String> {
        var tags: Set<String> = []
        let store = StaticDataStore.shared

        tags.insert("country:\(trip.countryCode)")
        tags.insert("origin:\(trip.originCountryCode)")

        let month = Calendar.current.component(.month, from: trip.startDate)
        tags.insert("month:\(month)")

        // 有即時預報就用預報，沒有就用月份推估。退路收斂在這裡，
        // 規則本身只需要寫 weather:hot，不必各自處理兩套來源。
        if let weatherTags, !weatherTags.isEmpty {
            tags.insert("forecast:live")
            for tag in weatherTags { tags.insert("weather:\(tag)") }
        } else {
            tags.insert("forecast:estimated")
            for tag in estimatedWeatherTags(month: month) { tags.insert("weather:\(tag)") }
        }

        tags.insert("party:\(preferences.party.rawValue)")
        tags.insert("experience:\(preferences.experience.rawValue)")
        tags.insert("age:\(preferences.ageBand.rawValue)")
        tags.insert("gender:\(preferences.gender.rawValue)")
        tags.insert("style:\(preferences.packingStyle == .light ? "light" : "full")")

        let days = max(trip.totalDays, 1)
        tags.insert("days:\(days)")
        tags.insert("duration:\(days <= 3 ? "short" : (days <= 7 ? "medium" : "long"))")

        // 插座相容性從國家資料推導，不必逐一列舉國家組合
        if let destination = store.country(code: trip.countryCode),
           let origin = store.country(code: trip.originCountryCode) {
            let compatible = !Set(destination.plugTypes).isDisjoint(with: origin.plugTypes)
            tags.insert(compatible ? "plug:compatible" : "plug:incompatible")
        }

        return tags
    }

    /// 無預報時的月份推估（北半球）。有預報時不會用到這裡。
    private static func estimatedWeatherTags(month: Int) -> [String] {
        switch month {
        case 6, 7, 8, 9: ["hot"]
        case 12, 1, 2: ["cold"]
        default: ["mild"]
        }
    }

    // MARK: - Generation

    /// - Parameter preferences: 不傳則沿用行程快照。草稿也會同步，因此不可預設讀裝置偏好，
    ///   否則同一份草稿在兩台裝置會看到不同的建議清單。
    static func generate(
        for trip: Trip,
        preferences: UserPreferences? = nil,
        weatherTags: Set<String>? = nil
    ) -> [GeneratedItem] {
        let preferences = preferences ?? trip.packingPreferences
        let store = StaticDataStore.shared
        let context = contextTags(for: trip, preferences: preferences, weatherTags: weatherTags)
        let perDayCap = preferences.packingStyle == .light ? 4 : 7

        var results: [GeneratedItem] = []
        var seenItemIDs = Set<String>()

        for (ruleIndex, rule) in store.packingRules.enumerated() where rule.applies(to: context) {
            let reason = expand(rule.reasonZh, for: trip, context: context)
            for (needIndex, need) in rule.needs.enumerated() {
                if let condition = need.when, !condition.matches(context) { continue }
                guard let item = resolve(need, in: store, context: context) else { continue }
                // 依目錄 id 去重：同一件東西被兩條規則叫到只會出現一次
                guard seenItemIDs.insert(item.id).inserted else { continue }

                let quantity = need.perDay == true
                    ? min(max(trip.totalDays, 1), perDayCap)
                    : (need.quantity ?? 1)

                results.append(GeneratedItem(
                    catalogItemID: item.id,
                    name: item.nameZh,
                    category: item.packingCategory,
                    quantity: quantity,
                    weightGrams: item.weightGrams ?? 0,
                    reason: reason,
                    sortIndex: ruleIndex * 100 + needIndex
                ))
            }
        }

        return results
    }

    /// itemId 直接取；need 則查 satisfies 索引，取優先度最高、且本身條件成立的候選。
    private static func resolve(
        _ need: PackingRule.Need,
        in store: StaticDataStore,
        context: Set<String>
    ) -> PackingCatalogItem? {
        if let itemID = need.itemId { return store.packingCatalogByID[itemID] }
        guard let needKey = need.need else { return nil }
        return store.packingItemsBySatisfiedNeed[needKey]?.first
    }

    /// 理由字串裡的佔位符，讓規則能寫出帶有行程細節的說明。
    private static func expand(_ template: String, for trip: Trip, context: Set<String>) -> String {
        guard template.contains("{") else { return template }
        let store = StaticDataStore.shared
        var text = template
        if let origin = store.country(code: trip.originCountryCode) {
            text = text.replacingOccurrences(of: "{originCountry}", with: origin.nameZh)
        }
        if let destination = store.country(code: trip.countryCode) {
            text = text.replacingOccurrences(of: "{destinationCountry}", with: destination.nameZh)
            text = text.replacingOccurrences(
                of: "{plugTypes}",
                with: destination.plugTypes.joined(separator: "/")
            )
        }
        text = text.replacingOccurrences(of: "{days}", with: String(max(trip.totalDays, 1)))
        return text
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

        // 比對以目錄 id 為主。舊版建立的項目沒有 id，退回比名稱，
        // 才不會在升級後把既有項目當成新項目重複加入。
        let generatedIDs = Set(generated.map(\.catalogItemID))
        let generatedNames = Set(generated.map(\.name))
        let existingIDs = Set(existing.map(\.catalogItemId).filter { !$0.isEmpty })
        let existingNames = Set(existing.map(\.name))

        for item in generated
        where !existingIDs.contains(item.catalogItemID) && !existingNames.contains(item.name) {
            let packingItem = PackingItem(
                name: item.name,
                category: item.category,
                reasonKey: item.reason,
                quantity: item.quantity,
                isCustom: false,
                sortIndex: item.sortIndex,
                trip: trip
            )
            packingItem.catalogItemId = item.catalogItemID
            packingItem.weightGrams = item.weightGrams
            context.insert(packingItem)
        }

        // 數量會隨天數與打包風格改變（例如五天行程從完整的 5 件降為輕便的 4 件），
        // 所以仍在建議中的自動項目要更新數量，只增減品項是不夠的。
        let generatedByID = Dictionary(
            generated.map { ($0.catalogItemID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for item in existing where !item.isCustom && !item.isPacked {
            guard let match = generatedByID[item.catalogItemId] else { continue }
            if item.quantity != match.quantity { item.quantity = match.quantity }
        }

        for item in existing where !item.isCustom && !item.isPacked {
            let stillGenerated = item.catalogItemId.isEmpty
                ? generatedNames.contains(item.name)
                : generatedIDs.contains(item.catalogItemId)
            if !stillGenerated { context.delete(item) }
        }
    }
}
