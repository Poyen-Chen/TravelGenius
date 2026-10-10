//
//  PackingListGenerator.swift
//  TravelGenius
//

import Foundation
import SwiftData

/// 單一 JSON 標籤推薦引擎。建立時產生候選；既有清單只透過唯讀 Review
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

    /// References come from the same JSON rule document used for generation.
    static var referencedItemIDs: Set<String> { StaticDataStore.shared.packingRules.referencedItemIDs }

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
            resolvedPreferences = UserPreferences(packingStyle: .normal, devices: ["phone"], needs: [])
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
        let store = StaticDataStore.shared
        let weather = weatherTags ?? snapshot?.tags ?? seasonalWeatherTags(for: trip, month: month)
        let days = max(1, min(trip.totalDays, 99))
        var tags: Set<String> = ["country:\(trip.countryCode)", "origin:\(trip.originCountryCode)",
            "month:\(month)", "days:\(days)", "duration:\(days <= 3 ? "short" : days <= 7 ? "medium" : "long")",
            "style:\(resolvedPreferences.packingStyle.rawValue)", "laundry:\(packingContext.laundry.rawValue)",
            snapshot?.days.isEmpty == false ? "forecast:live" : "forecast:estimated"]
        tags.formUnion(weather.map { "weather:\($0)" })
        tags.formUnion(PersonalPackingOptions.validDevices(resolvedPreferences.devices).map { "device:\($0)" })
        tags.formUnion(PersonalPackingOptions.validNeeds(resolvedPreferences.needs).map { "need:\($0)" })
        let orderedActivities = packingContext.activities.map { "activity:\($0.rawValue)" }
        tags.formUnion(orderedActivities)
        tags.formUnion(packingContext.stays.map { "stay:\($0.rawValue)" })
        let destination = store.country(code: trip.countryCode)
        let origin = store.country(code: trip.originCountryCode)
        if let destination, let origin {
            tags.insert(Set(origin.plugTypes).isSubset(of: Set(destination.plugTypes)) ? "plug:compatible" : "plug:incompatible")
        }
        return store.packingEngine.generate(tags: tags, orderedTags: orderedActivities, days: days,
            style: resolvedPreferences.packingStyle,
            replacements: ["originCountry": origin?.nameZh ?? trip.originCountryCode,
                "destinationCountry": destination?.nameZh ?? trip.countryCode,
                "plugTypes": destination?.plugTypes.joined(separator: "/") ?? "",
                "days": String(days),
                "weatherSource": snapshot?.reason(for: Array(weather)) ?? "依目的地月份的季節參考"])
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

    /// Read-only comparison between the current checklist and the validated JSON rule set.
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
