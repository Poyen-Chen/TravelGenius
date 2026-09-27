//
//  PackingListGenerator.swift
//  TravelGenius
//

import Foundation
import SwiftData

/// 保留歷史規則層的輸出契約，並在新版明確輸入上疊加個人需求與行程情境。
/// 建立時產生候選；既有清單只透過唯讀 Review 提案，確認後才套用所選增、減、移除。
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

    struct QuantityReduction: Identifiable {
        let itemID: UUID
        let catalogItemID: String
        let name: String
        let currentQuantity: Int
        let suggestedQuantity: Int
        let reason: String
        let isPacked: Bool

        var id: UUID { itemID }
    }

    struct RemovalSuggestion: Identifiable {
        let itemID: UUID
        let catalogItemID: String
        let name: String
        let reason: String
        let isPacked: Bool

        var id: UUID { itemID }
    }

    struct Review {
        let additions: [GeneratedItem]
        let reductions: [QuantityReduction]
        let removals: [RemovalSuggestion]

        var isEmpty: Bool { additions.isEmpty && reductions.isEmpty && removals.isEmpty }
    }

    struct AppliedReview {
        let additions: Int
        let reductions: Int
        let removals: Int
    }

    /// 自訂項目的分組與排序（固定最後）
    static let customReason = "自訂"
    static let customSortIndex = 1_000_000

    static func generate(
        for trip: Trip,
        preferences: UserPreferences? = nil,
        packingContext: TripPackingContext? = nil,
        weatherTags: Set<String>? = nil,
        weatherReference: PackingWeather? = nil
    ) -> [GeneratedItem] {
        guard let preferences = preferences ?? trip.packingPreferences
            ?? (trip.packingPreferencesRaw.isEmpty ? UserPreferences.forNewTrips() : nil) else { return [] }
        let snapshot = weatherReference ?? trip.packingWeather
        guard trip.packingWeatherRaw.isEmpty || snapshot != nil else { return [] }
        guard trip.packingContextRaw.isEmpty || trip.packingContext != nil else { return [] }
        let packingContext = packingContext ?? trip.packingContext ?? .empty
        guard packingContext.valid else { return [] }
        let effectiveWeatherTags = weatherTags ?? snapshot?.tags
        let month = Calendar.current.component(.month, from: trip.startDate)
        var results: [GeneratedItem] = []
        var seenIDs = Set<String>()
        let catalog = StaticDataStore.shared.packingCatalog
        let modern = preferences.usesExplicitNeeds

        func append(
            _ id: String,
            quantity: Int = 1,
            reason: String,
            sortIndex: Int? = nil,
            displayName: String? = nil
        ) {
            guard (!modern || catalog.isActive(id: id)),
                  seenIDs.insert(id).inserted,
                  let definition = catalog.item(id: id) else { return }
            results.append(.init(catalogItemID: id, name: displayName ?? definition.nameZh, category: definition.category,
                quantity: max(1, min(quantity, 99)), reason: reason,
                sortIndex: sortIndex ?? (5_000 + results.count)))
        }

        if modern {
            let days = max(1, min(trip.totalDays, 99))
            let baseDailyQuantity = min(days, preferences.packingStyle == .light ? 4 : 99)
            let laundryDailyCap: Int
            let laundryBottomCap: Int
            switch preferences.packingStyle {
            case .light: (laundryDailyCap, laundryBottomCap) = (3, 2)
            case .normal: (laundryDailyCap, laundryBottomCap) = (4, 2)
            case .full: (laundryDailyCap, laundryBottomCap) = (5, 3)
            }
            let dailyQuantity = packingContext.laundry == .yes ? min(days, laundryDailyCap) : baseDailyQuantity
            let bottomQuantity = packingContext.laundry == .yes ? min(days, laundryBottomCap) : baseDailyQuantity
            let clothingReason = packingContext.laundry == .yes
                ? "基本衣物・途中會洗衣，已依打包風格減量"
                : "基本衣物・依旅行天數與打包風格準備"

            append("passport", reason: "國際旅行基本必備", sortIndex: 0)
            append("payment-card", reason: "基本付款工具", sortIndex: 1)
            append("tops", quantity: dailyQuantity, reason: clothingReason, sortIndex: 2)
            append("bottoms", quantity: bottomQuantity, reason: clothingReason, sortIndex: 3)
            append("underwear", quantity: dailyQuantity, reason: clothingReason, sortIndex: 4)
            append("socks", quantity: dailyQuantity, reason: clothingReason, sortIndex: 5)
            append("walking-shoes", reason: "一般旅行步行需求", sortIndex: 6)
            append("toothbrush", reason: "基本盥洗用品", sortIndex: 7)
            append("toothpaste", reason: "基本盥洗用品", sortIndex: 8)
            if preferences.packingStyle == .full {
                append("sleepwear", reason: "準備齊全模式", sortIndex: 9)
            }

            let selectedDevices = Set(PersonalPackingOptions.validDevices(preferences.devices) ?? [])
            for option in PersonalPackingOptions.devices where selectedDevices.contains(option.id) {
                for id in option.itemIDs { append(id, reason: "我的常用設備：\(option.label)") }
            }
            if !selectedDevices.isDisjoint(with: ["phone", "tablet", "headphones"]) {
                append("charging-kit", reason: "常用設備共用充電用品・請確認接頭、功率與數量")
            }
            if !selectedDevices.isDisjoint(with: ["phone", "tablet"]) {
                append("power-bank", reason: "手機或平板的外出供電")
            }
            let selectedNeeds = Set(PersonalPackingOptions.validNeeds(preferences.needs) ?? [])
            for option in PersonalPackingOptions.needs where selectedNeeds.contains(option.id) {
                for id in option.itemIDs { append(id, reason: "我的常備需求：\(option.label)") }
            }

            let weatherTags: Set<String>
            if let effectiveWeatherTags {
                weatherTags = effectiveWeatherTags
            } else {
                let matchedWeatherRules = StaticDataStore.shared.packingRules.filter { rule in
                    rule.layer == "weather"
                        && rule.applies(countryCode: trip.countryCode, month: month,
                            preferences: preferences, weatherTags: nil)
                }
                weatherTags = Set(matchedWeatherRules.flatMap { $0.match?.weatherTags ?? [] })
            }
            let weatherSource: String = snapshot?.reason(for: Array(weatherTags)) ?? "依旅行月份的季節參考"
            if weatherTags.contains("mild") {
                append("light-jacket", reason: "\(weatherSource)・方便增減外層")
            }
            if weatherTags.contains("cold") {
                for id in ["sweater-fleece", "warm-coat", "scarf", "warm-hat", "waterproof-gloves"] {
                    append(id, reason: "\(weatherSource)・寒冷天氣保暖")
                }
            }
            if weatherTags.contains("rain") {
                append("folding-umbrella", reason: "\(weatherSource)・有雨時的一般雨具")
            }
            let hasSnowActivity = packingContext.activities.contains(.snow) || packingContext.activities.contains(.skiing)
            if preferences.packingStyle == .full && (weatherTags.contains("cold") || hasSnowActivity) {
                append("hand-warmer", quantity: min(5, days), reason: "寒冷或雪地・準備齊全模式")
            }
            appendContextItems(packingContext, weatherTags: weatherTags) { id, quantity, reason, sortIndex in
                append(id, quantity: quantity, reason: reason, sortIndex: sortIndex)
            }
        } else {
            for (ruleIndex, rule) in StaticDataStore.shared.packingRules.enumerated() {
                guard rule.applies(
                    countryCode: trip.countryCode,
                    month: month,
                    preferences: preferences,
                    weatherTags: effectiveWeatherTags
                ) else { continue }
                for (itemIndex, item) in rule.items.enumerated() {
                    if preferences.packingStyle == .light && item.fullOnly == true { continue }
                    let styleCap = preferences.packingStyle == .light ? 4 : 7
                    let quantity = item.perDay == true ? min(trip.totalDays, styleCap) : (item.quantity ?? 1)
                    let reason: String
                    if rule.layer == "weather", let snapshot {
                        reason = "\(snapshot.reason(for: rule.match?.weatherTags ?? []))・\(weatherReason(rule.match?.weatherTags ?? []))"
                    } else {
                        reason = rule.reasonZh
                    }
                    append(item.itemId, quantity: quantity, reason: reason,
                        sortIndex: ruleIndex * 100 + itemIndex,
                        displayName: catalog.legacyDisplayName(id: item.itemId))
                }
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
            if seenIDs.insert("plug-adapter").inserted {
                results.append(.init(catalogItemID: "plug-adapter", name: "插座轉接頭（當地 Type-\(types)）",
                    category: .electronics, quantity: 1, reason: "因為插座規格與\(originName)不同", sortIndex: 90))
            }
        }

        return results
    }

    private static func appendContextItems(
        _ context: TripPackingContext,
        weatherTags: Set<String>,
        append: (String, Int, String, Int?) -> Void
    ) {
        var sequence = 0
        func add(_ id: String, reason: String) {
            append(id, 1, reason, 6_000 + sequence)
            sequence += 1
        }
        for activity in context.activities {
            let reason = "因為有\(activity.label)安排"
            switch activity {
            case .water:
                ["swimsuit", "wet-item-bag", "sunscreen", "sun-hat", "sunglasses"]
                    .forEach { add($0, reason: reason) }
            case .outdoors:
                ["outdoor-shoes", "daypack", "water-bottle", "sunscreen", "sun-hat", "sunglasses"]
                    .forEach { add($0, reason: reason) }
                if weatherTags.contains("rain") { add("rain-jacket", reason: "有雨且安排健行／登山・與摺疊傘並列") }
            case .snow:
                ["waterproof-nonslip-shoes", "warm-hat", "waterproof-gloves", "sunscreen", "sun-hat", "sunglasses"]
                    .forEach { add($0, reason: reason) }
            case .skiing:
                ["thermal-base-layer", "ski-socks", "ski-goggles", "ski-jacket", "ski-pants",
                 "waterproof-gloves", "sunscreen", "sun-hat", "sunglasses"]
                    .forEach { add($0, reason: $0 == "waterproof-gloves" ? "滑雪／單板需要防水保暖手套" : reason) }
            case .spa:
                break // Compatibility-only legacy value; V1 has no automatic hot-spring item.
            case .exercise:
                ["workout-clothes", "water-bottle"].forEach { add($0, reason: reason) }
            case .business:
                ["business-clothes", "business-cards"].forEach { add($0, reason: reason) }
            case .formal:
                ["formal-clothes", "formal-shoes"].forEach { add($0, reason: reason) }
            case .driving:
                add("driving-documents", reason: reason)
            }
        }

        if context.laundry == .yes {
            add("laundry-supplies", reason: "因為途中會洗衣")
            add("laundry-bag", reason: "因為途中會洗衣・分開收納待洗衣物")
        }

        if context.stays.contains(.hostel) {
            add("locker-lock", reason: "青旅／共用住宿的置物櫃收納")
            add("slippers", reason: "青旅／共用住宿的淋浴空間")
            add("quick-dry-towel", reason: "青旅／共用住宿自備毛巾")
        }
    }

    /// Read-only comparison between the preserved checklist and the currently selected rules.
    static func review(
        for trip: Trip,
        preferences: UserPreferences? = nil,
        packingContext: TripPackingContext? = nil,
        weather: PackingWeather? = nil
    ) -> Review {
        let catalog = StaticDataStore.shared.packingCatalog
        let existing = trip.packingItems ?? []
        let generated = generate(for: trip, preferences: preferences, packingContext: packingContext, weatherReference: weather)
        let targets = Dictionary(uniqueKeysWithValues: generated.map { ($0.id, $0) })
        let existingIDs = Set(existing.compactMap { $0.catalogItemID ?? catalog.legacyID(name: $0.name) })
        let existingNames = Set(existing.map(\.name))
        let excluded = trip.excludedPackingIDs.union(trip.excludedPackingNames.compactMap { catalog.legacyID(name: $0) })

        let additions = generated.filter {
            !existingIDs.contains($0.id) && !existingNames.contains($0.name)
                && !excluded.contains($0.id) && !trip.excludedPackingNames.contains($0.name)
        }
        var reductions: [QuantityReduction] = []
        var removals: [RemovalSuggestion] = []
        for item in existing where !item.isCustom {
            guard let id = item.catalogItemID ?? catalog.legacyID(name: item.name), catalog.item(id: id) != nil else { continue }
            if let target = targets[id] {
                if item.quantity > target.quantity {
                    reductions.append(.init(itemID: item.id, catalogItemID: id, name: item.name,
                        currentQuantity: item.quantity, suggestedQuantity: target.quantity,
                        reason: target.reason, isPacked: item.isPacked))
                }
            } else {
                removals.append(.init(itemID: item.id, catalogItemID: id, name: item.name,
                    reason: "目前目的地、天氣與這趟設定已不再產生此項建議",
                    isPacked: item.isPacked))
            }
        }
        return Review(additions: additions, reductions: reductions, removals: removals)
    }

    static func missingItems(for trip: Trip, weather: PackingWeather? = nil) -> [GeneratedItem] {
        review(for: trip, weather: weather).additions
    }

    @MainActor
    @discardableResult
    static func applyReview(
        trip: Trip,
        selectedAdditionIDs: Set<String>,
        selectedReductionIDs: Set<UUID>,
        selectedRemovalIDs: Set<UUID>,
        preferences: UserPreferences? = nil,
        packingContext: TripPackingContext? = nil,
        weather: PackingWeather?,
        replacePreferencesOnSuccess: UserPreferences? = nil,
        captureContextOnSuccess: TripPackingContext? = nil,
        context: ModelContext
    ) throws -> AppliedReview {
        let current = review(for: trip, preferences: preferences, packingContext: packingContext, weather: weather)
        let additions = current.additions.filter { selectedAdditionIDs.contains($0.id) }
        let reductions = current.reductions.filter { selectedReductionIDs.contains($0.id) }
        let removals = current.removals.filter { selectedRemovalIDs.contains($0.id) }
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosave }
        var inserted: [PackingItem] = []
        var originalQuantities: [(PackingItem, Int)] = []
        var deleted: [PackingItem] = []
        let originalPreferences = trip.packingPreferencesRaw
        let originalContext = trip.packingContextRaw
        do {
            for candidate in additions {
                let item = PackingItem(name: candidate.name, category: candidate.category,
                    reasonKey: candidate.reason, quantity: candidate.quantity, isCustom: false,
                    sortIndex: candidate.sortIndex, trip: trip)
                item.catalogItemID = candidate.id
                context.insert(item)
                inserted.append(item)
            }
            let itemsByID = Dictionary(uniqueKeysWithValues: (trip.packingItems ?? []).map { ($0.id, $0) })
            for reduction in reductions {
                guard let item = itemsByID[reduction.itemID] else { continue }
                originalQuantities.append((item, item.quantity))
                item.quantity = reduction.suggestedQuantity
            }
            for removal in removals {
                guard let item = itemsByID[removal.itemID] else { continue }
                deleted.append(item)
                context.delete(item)
            }
            if let replacePreferencesOnSuccess { trip.replacePackingPreferences(replacePreferencesOnSuccess) }
            if let captureContextOnSuccess { trip.capturePackingContextIfNeeded(captureContextOnSuccess) }
            try context.save()
            return .init(additions: inserted.count, reductions: originalQuantities.count, removals: deleted.count)
        } catch {
            for item in inserted { context.delete(item) }
            for (item, quantity) in originalQuantities { item.quantity = quantity }
            for item in deleted { context.insert(item) }
            trip.packingPreferencesRaw = originalPreferences
            trip.packingContextRaw = originalContext
            throw error
        }
    }

    @MainActor
    @discardableResult
    static func addMissing(trip: Trip, selectedIDs: Set<String>, weather: PackingWeather?, context: ModelContext) throws -> Int {
        try applyReview(trip: trip, selectedAdditionIDs: selectedIDs, selectedReductionIDs: [],
            selectedRemovalIDs: [], weather: weather, context: context).additions
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
        guard trip.packingContextRaw.isEmpty || trip.packingContext != nil else { return }
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
