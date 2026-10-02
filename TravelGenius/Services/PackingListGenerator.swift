//
//  PackingListGenerator.swift
//  TravelGenius
//

import Foundation
import SwiftData

/// 單一 Swift 推薦引擎。建立時產生候選；既有清單只透過唯讀 Review
/// 提案，確認後才套用所選增、減、移除。
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

    struct QuantityIncrease: Identifiable {
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
        let increases: [QuantityIncrease]
        let reductions: [QuantityReduction]
        let removals: [RemovalSuggestion]

        var isEmpty: Bool { additions.isEmpty && increases.isEmpty && reductions.isEmpty && removals.isEmpty }
    }

    struct AppliedReview {
        let additions: Int
        let increases: Int
        let reductions: Int
        let removals: Int
    }

    /// 自訂項目的分組與排序（固定最後）
    static let customReason = "自訂"
    static let customSortIndex = 1_000_000

    /// Swift 規則可能產生的目錄 ID；啟動時由 PackingCatalog 驗證。
    static let referencedItemIDs: Set<String> = [
        "passport", "payment-card", "tops", "bottoms", "underwear", "socks", "walking-shoes",
        "toothbrush", "toothpaste", "sleepwear", "phone", "laptop", "tablet", "camera",
        "smartwatch", "headphones", "charging-kit", "laptop-charger", "camera-charger",
        "memory-card", "watch-charger", "power-bank", "plug-adapter", "skincare",
        "sanitary-products", "travel-document-backup", "driving-documents", "light-jacket",
        "sweater-fleece", "warm-coat", "scarf", "warm-hat", "waterproof-gloves",
        "folding-umbrella", "rain-jacket", "water-bottle", "sunscreen", "sun-hat",
        "sunglasses", "hand-warmer", "swimsuit", "wet-item-bag", "outdoor-shoes", "daypack",
        "waterproof-nonslip-shoes", "thermal-base-layer", "ski-socks", "ski-goggles",
        "ski-jacket", "ski-pants", "workout-clothes", "business-clothes", "business-cards",
        "formal-clothes", "formal-shoes", "locker-lock", "slippers", "quick-dry-towel",
        "laundry-supplies", "laundry-bag"
    ]

    static func generate(
        for trip: Trip,
        preferences: UserPreferences? = nil,
        packingContext: TripPackingContext? = nil,
        weatherTags: Set<String>? = nil,
        weatherReference: PackingWeather? = nil
    ) -> [GeneratedItem] {
        let resolvedPreferences: UserPreferences
        if let supplied = preferences {
            resolvedPreferences = supplied
        } else if trip.packingPreferencesRaw.isEmpty {
            resolvedPreferences = .forNewTrips()
        } else {
            guard let saved = trip.packingPreferences else { return [] }
            resolvedPreferences = saved
        }
        let snapshot = weatherReference ?? trip.packingWeather
        guard trip.packingWeatherRaw.isEmpty || snapshot != nil else { return [] }
        guard trip.packingContextRaw.isEmpty || trip.packingContext != nil else { return [] }
        let packingContext = packingContext ?? trip.packingContext ?? .empty
        guard packingContext.valid else { return [] }
        let month = Calendar.current.component(.month, from: trip.startDate)
        var results: [GeneratedItem] = []
        var seenIDs = Set<String>()
        let catalog = StaticDataStore.shared.packingCatalog

        func append(
            _ id: String,
            quantity: Int = 1,
            reason: String,
            sortIndex: Int? = nil
        ) {
            guard seenIDs.insert(id).inserted,
                  let definition = catalog.item(id: id) else { return }
            results.append(.init(catalogItemID: id, name: definition.nameZh, category: definition.category,
                quantity: max(1, min(quantity, 99)), reason: reason,
                sortIndex: sortIndex ?? (5_000 + results.count)))
        }

        let days = max(1, min(trip.totalDays, 99))
        let topQuantityWithoutLaundry: Int
        let bottomQuantityWithoutLaundry: Int
        let laundryTopCap: Int
        let laundryBottomCap: Int
        let laundryUnderwearAndSocksCap: Int
        switch resolvedPreferences.packingStyle {
        case .light:
            topQuantityWithoutLaundry = (days + 1) / 2
            bottomQuantityWithoutLaundry = (days + 3) / 4
            (laundryTopCap, laundryBottomCap, laundryUnderwearAndSocksCap) = (2, 2, 3)
        case .normal:
            topQuantityWithoutLaundry = (days * 2 + 2) / 3
            bottomQuantityWithoutLaundry = (days + 2) / 3
            (laundryTopCap, laundryBottomCap, laundryUnderwearAndSocksCap) = (3, 2, 4)
        case .full:
            topQuantityWithoutLaundry = days
            bottomQuantityWithoutLaundry = (days + 1) / 2
            (laundryTopCap, laundryBottomCap, laundryUnderwearAndSocksCap) = (4, 3, 5)
        }
        let hasLaundry = packingContext.laundry == .yes
        let topQuantity = hasLaundry ? min(topQuantityWithoutLaundry, laundryTopCap) : topQuantityWithoutLaundry
        let bottomQuantity = hasLaundry ? min(bottomQuantityWithoutLaundry, laundryBottomCap) : bottomQuantityWithoutLaundry
        let underwearAndSocksQuantity = hasLaundry ? min(days, laundryUnderwearAndSocksCap) : days

        func clothingReason(for item: String) -> String {
            hasLaundry
                ? "基本衣物・途中會洗衣，已依\(item)更換頻率與打包風格減量"
                : "基本衣物・依\(item)更換頻率、旅行天數與打包風格估算"
        }

        append("passport", reason: "國際旅行基本必備", sortIndex: 0)
        append("payment-card", reason: "基本付款工具", sortIndex: 1)
        append("tops", quantity: topQuantity, reason: clothingReason(for: "上衣"), sortIndex: 2)
        append("bottoms", quantity: bottomQuantity, reason: clothingReason(for: "下身衣物"), sortIndex: 3)
        append("underwear", quantity: underwearAndSocksQuantity, reason: clothingReason(for: "內衣褲"), sortIndex: 4)
        append("socks", quantity: underwearAndSocksQuantity, reason: clothingReason(for: "襪子"), sortIndex: 5)
        append("walking-shoes", reason: "一般旅行步行需求", sortIndex: 6)
        append("toothbrush", reason: "基本盥洗用品", sortIndex: 7)
        append("toothpaste", reason: "基本盥洗用品", sortIndex: 8)
        if resolvedPreferences.packingStyle == .full {
            append("sleepwear", reason: "準備齊全模式", sortIndex: 9)
        }

        let selectedDevices = Set(PersonalPackingOptions.validDevices(resolvedPreferences.devices))
        for option in PersonalPackingOptions.devices where selectedDevices.contains(option.id) {
            for id in option.itemIDs { append(id, reason: "我的常用設備：\(option.label)") }
        }
        if !selectedDevices.isDisjoint(with: ["phone", "tablet", "headphones"]) {
            append("charging-kit", reason: "常用設備共用充電用品・請確認接頭、功率與數量")
        }
        if !selectedDevices.isDisjoint(with: ["phone", "tablet"]) {
            append("power-bank", reason: "手機或平板的外出供電")
        }
        let selectedNeeds = Set(PersonalPackingOptions.validNeeds(resolvedPreferences.needs))
        for option in PersonalPackingOptions.needs where selectedNeeds.contains(option.id) {
            for id in option.itemIDs { append(id, reason: "我的常備需求：\(option.label)") }
        }

        let resolvedWeatherTags = weatherTags ?? snapshot?.tags ?? seasonalWeatherTags(for: trip, month: month)
        let weatherSource = snapshot?.reason(for: Array(resolvedWeatherTags)) ?? "依目的地月份的季節參考"
        if resolvedWeatherTags.contains("mild") {
            append("light-jacket", reason: "\(weatherSource)・方便增減外層")
        }
        if resolvedWeatherTags.contains("cold") {
            for id in ["sweater-fleece", "warm-coat", "scarf", "warm-hat", "waterproof-gloves"] {
                append(id, reason: "\(weatherSource)・寒冷天氣保暖")
            }
        }
        if resolvedWeatherTags.contains("rain") {
            append("folding-umbrella", reason: "\(weatherSource)・有雨時的一般雨具")
        }
        let hasSnowActivity = packingContext.activities.contains(.snow) || packingContext.activities.contains(.skiing)
        if resolvedPreferences.packingStyle == .full && (resolvedWeatherTags.contains("cold") || hasSnowActivity) {
            append("hand-warmer", quantity: min(5, days), reason: "寒冷或雪地・準備齊全模式")
        }
        appendContextItems(packingContext, weatherTags: resolvedWeatherTags) { id, quantity, reason, sortIndex in
            append(id, quantity: quantity, reason: reason, sortIndex: sortIndex)
        }

        // 只有目的地完整涵蓋出發地插頭型式時才視為相容；共享其中一種插頭不足以保證相容。
        let store = StaticDataStore.shared
        if let destination = store.country(code: trip.countryCode),
           let origin = store.country(code: trip.originCountryCode) {
            let destinationPlugTypes = Set(destination.plugTypes)
            let originPlugTypes = Set(origin.plugTypes)
            let needsAdapter = !originPlugTypes.isSubset(of: destinationPlugTypes)
            if needsAdapter, seenIDs.insert("plug-adapter").inserted {
                let types = destination.plugTypes.joined(separator: "/")
                let originName = origin.nameZh
                results.append(.init(catalogItemID: "plug-adapter", name: "插座轉接頭（當地 Type-\(types)）",
                    category: .electronics, quantity: 1,
                    reason: "目的地不保證支援\(originName)常見的所有插頭型式", sortIndex: 90))
            }
        }

        return results
    }

    private static func seasonalWeatherTags(for trip: Trip, month: Int) -> Set<String> {
        let cityName = trip.city.isEmpty
            ? StaticDataStore.shared.defaultCity(countryCode: trip.countryCode)?.cityZh
            : trip.city
        guard let cityName,
              let profile = StaticDataStore.shared.seasonalProfiles.first(where: {
                  $0.cityID == "\(trip.countryCode)-\(cityName)"
              }) else { return [] }
        return profile.tags(month: month)
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

    /// Read-only comparison between the current checklist and the single Swift rule set.
    static func review(
        for trip: Trip,
        preferences: UserPreferences? = nil,
        packingContext: TripPackingContext? = nil,
        weather: PackingWeather? = nil
    ) -> Review {
        let generated = generate(for: trip, preferences: preferences, packingContext: packingContext, weatherReference: weather)
        return review(for: trip, generated: generated)
    }

    static func review(for trip: Trip, generated: [GeneratedItem]) -> Review {
        let catalog = StaticDataStore.shared.packingCatalog
        let existing = trip.packingItems ?? []
        // Every valid recommendation contains the base set. An empty result means
        // a stored input could not be decoded, so never turn it into removal proposals.
        guard !generated.isEmpty else {
            return Review(additions: [], increases: [], reductions: [], removals: [])
        }
        let targets = Dictionary(uniqueKeysWithValues: generated.map { ($0.id, $0) })
        let existingIDs = Set(existing.compactMap { $0.catalogItemID ?? catalog.id(named: $0.name) })
        let existingNames = Set(existing.map(\.name))
        let excluded = trip.excludedPackingIDs.union(trip.excludedPackingNames.compactMap { catalog.id(named: $0) })

        let additions = generated.filter {
            !existingIDs.contains($0.id) && !existingNames.contains($0.name)
                && !excluded.contains($0.id) && !trip.excludedPackingNames.contains($0.name)
        }
        var increases: [QuantityIncrease] = []
        var reductions: [QuantityReduction] = []
        var removals: [RemovalSuggestion] = []
        for item in existing where !item.isCustom {
            guard let id = item.catalogItemID ?? catalog.id(named: item.name), catalog.item(id: id) != nil else { continue }
            if let target = targets[id] {
                if item.quantity < target.quantity {
                    increases.append(.init(itemID: item.id, catalogItemID: id, name: item.name,
                        currentQuantity: item.quantity, suggestedQuantity: target.quantity,
                        reason: target.reason, isPacked: item.isPacked))
                } else if item.quantity > target.quantity {
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
        return Review(additions: additions, increases: increases, reductions: reductions, removals: removals)
    }

    static func missingItems(for trip: Trip, weather: PackingWeather? = nil) -> [GeneratedItem] {
        review(for: trip, weather: weather).additions
    }

    @MainActor
    @discardableResult
    static func applyReview(
        trip: Trip,
        selectedAdditionIDs: Set<String>,
        selectedIncreaseIDs: Set<UUID> = [],
        selectedReductionIDs: Set<UUID>,
        selectedRemovalIDs: Set<UUID>,
        preferences: UserPreferences? = nil,
        packingContext: TripPackingContext? = nil,
        weather: PackingWeather?,
        context: ModelContext
    ) throws -> AppliedReview {
        let current = review(for: trip, preferences: preferences, packingContext: packingContext, weather: weather)
        let additions = current.additions.filter { selectedAdditionIDs.contains($0.id) }
        let increases = current.increases.filter { selectedIncreaseIDs.contains($0.id) }
        let reductions = current.reductions.filter { selectedReductionIDs.contains($0.id) }
        let removals = current.removals.filter { selectedRemovalIDs.contains($0.id) }
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosave }
        var inserted: [PackingItem] = []
        var originalQuantities: [(PackingItem, Int)] = []
        var deleted: [PackingItem] = []
        let originalReviewPending = trip.packingReviewPending
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
            for increase in increases {
                guard let item = itemsByID[increase.itemID] else { continue }
                originalQuantities.append((item, item.quantity))
                item.quantity = increase.suggestedQuantity
            }
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
            trip.packingReviewPending = current.additions.contains { !selectedAdditionIDs.contains($0.id) }
                || current.increases.contains { !selectedIncreaseIDs.contains($0.id) }
                || current.reductions.contains { !selectedReductionIDs.contains($0.id) }
                || current.removals.contains { !selectedRemovalIDs.contains($0.id) }
            try context.save()
            return .init(additions: inserted.count, increases: increases.count,
                reductions: reductions.count, removals: deleted.count)
        } catch {
            for item in inserted { context.delete(item) }
            for (item, quantity) in originalQuantities { item.quantity = quantity }
            for item in deleted { context.insert(item) }
            trip.packingReviewPending = originalReviewPending
            throw error
        }
    }

    @MainActor
    @discardableResult
    static func addMissing(trip: Trip, selectedIDs: Set<String>, weather: PackingWeather?, context: ModelContext) throws -> Int {
        try applyReview(trip: trip, selectedAdditionIDs: selectedIDs, selectedReductionIDs: [],
            selectedRemovalIDs: [], weather: weather, context: context).additions
    }

}
