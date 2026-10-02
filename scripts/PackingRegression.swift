import Foundation
import SwiftData

@main
struct PackingRegression {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func preferences(style: PackingStyle = .normal, devices: [String] = [], needs: [String] = []) -> UserPreferences {
        UserPreferences(packingStyle: style, devices: devices, needs: needs)
    }

    static func trip(country: String = "JP", city: String = "東京", month: Int = 9, days: Int = 5) -> Trip {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: month, day: 10))!
        let trip = Trip(name: "Regression fixture", countryCode: country, startDate: start,
            endDate: Calendar.current.date(byAdding: .day, value: days - 1, to: start)!,
            homeCurrencyCode: "TWD", localCurrencyCode: "JPY", totalBudget: 0, tripType: .leisure)
        trip.city = city
        trip.originCountryCode = "TW"
        return trip
    }

    @MainActor
    static func main() throws {
        try validateCatalog()
        validateRuleMatrix()
        try validateSnapshotsAndReview()
        print("single Swift recommendation engine, 61-item catalog, trip-edit review safety: PASS")
    }

    static func validateCatalog() throws {
        let catalog = StaticDataStore.shared.packingCatalog
        let ids = Set(catalog.items.map(\.id))
        try catalog.validate(referencedItemIDs: PackingListGenerator.referencedItemIDs)
        expect(catalog.items.count == 61, "catalog must contain exactly 61 V1 items")
        expect(ids.count == 61, "catalog IDs must be unique")
        expect(PackingListGenerator.referencedItemIDs.isSubset(of: ids), "Swift rule references must exist")
        expect(catalog.id(named: "護照") == "passport", "current display name must resolve")
        expect(catalog.id(named: "插座轉接頭（當地 Type-G）") == "plug-adapter", "dynamic plug name must resolve")
        let artworkKeys = catalog.items.compactMap(\.artworkKey)
        expect(artworkKeys.count == 61, "every catalog item must own artwork")
        expect(Set(artworkKeys).count == 61, "artwork keys must be unique")
        let duplicate = PackingCatalog(version: catalog.version, items: catalog.items + [catalog.items[0]])
        do {
            try duplicate.validate(referencedItemIDs: PackingListGenerator.referencedItemIDs)
            fatalError("duplicate catalog identity accepted")
        } catch PackingCatalog.ContractError.duplicateIdentity { }
        do {
            try catalog.validate(referencedItemIDs: PackingListGenerator.referencedItemIDs.union(["missing-item"]))
            fatalError("missing Swift rule reference accepted")
        } catch PackingCatalog.ContractError.invalidReference { }
    }

    static func expectedClothing(days: Int, style: PackingStyle) -> (tops: Int, bottoms: Int) {
        switch style {
        case .light: ((days + 1) / 2, (days + 3) / 4)
        case .normal: ((days * 2 + 2) / 3, (days + 2) / 3)
        case .full: (days, (days + 1) / 2)
        }
    }

    static func validateRuleMatrix() {
        let catalogIDs = Set(StaticDataStore.shared.packingCatalog.items.map(\.id))
        let cities = ["JP": "東京", "KR": "首爾", "HK": "香港", "US": "紐約", "VN": "河內"]
        var cases = 0

        for (country, city) in cities {
            for month in 1...12 {
                for days in [1, 5, 12] {
                    for style in PackingStyle.allCases {
                        let output = PackingListGenerator.generate(
                            for: trip(country: country, city: city, month: month, days: days),
                            preferences: preferences(style: style, devices: ["phone", "camera"], needs: ["skincare"])
                        )
                        let ids = output.map(\.id)
                        expect(Set(ids).count == ids.count, "recommendations must be deduplicated")
                        expect(Set(ids).isSubset(of: catalogIDs), "recommendations must stay inside V1 catalog")
                        for required in ["passport", "payment-card", "tops", "bottoms", "underwear", "socks",
                                         "walking-shoes", "toothbrush", "toothpaste"] {
                            expect(ids.contains(required), "missing base item \(required)")
                        }
                        let expected = expectedClothing(days: days, style: style)
                        expect(output.first { $0.id == "tops" }?.quantity == expected.tops,
                               "top replacement interval mismatch")
                        expect(output.first { $0.id == "bottoms" }?.quantity == expected.bottoms,
                               "bottom replacement interval mismatch")
                        expect(output.first { $0.id == "underwear" }?.quantity == days,
                               "underwear must remain daily without laundry")
                        expect(output.first { $0.id == "socks" }?.quantity == days,
                               "socks must remain daily without laundry")
                        expect(!ids.contains("local-cash"), "local cash has no accepted trigger")
                        expect(ids.contains("sleepwear") == (style == .full), "sleepwear style policy mismatch")
                        expect(ids.contains("charging-kit"), "shared charger missing")
                        expect(ids.contains("power-bank"), "phone power bank missing")
                        cases += 1
                    }
                }
            }
        }

        let explicitRain = PackingListGenerator.generate(for: trip(), preferences: preferences(),
            packingContext: .init(activities: [.outdoors], stays: [], laundry: .no), weatherTags: ["rain"])
        expect(explicitRain.contains { $0.id == "folding-umbrella" }, "rain umbrella missing")
        expect(explicitRain.contains { $0.id == "rain-jacket" }, "rain plus hiking jacket missing")

        let januaryTokyo = PackingListGenerator.generate(for: trip(month: 1), preferences: preferences())
        expect(januaryTokyo.contains { $0.id == "warm-coat" }, "seasonal city fallback missing")

        let samePlug = PackingListGenerator.generate(for: trip(), preferences: preferences(), weatherTags: [])
        expect(!samePlug.contains { $0.id == "plug-adapter" }, "Taiwan to Japan must not add adapter")
        let differentPlug = PackingListGenerator.generate(for: trip(country: "KR", city: "首爾"),
            preferences: preferences(), weatherTags: [])
        expect(differentPlug.contains { $0.id == "plug-adapter" }, "incompatible plug must add adapter")
        let partialPlug = PackingListGenerator.generate(for: trip(country: "VN", city: "河內"),
            preferences: preferences(), weatherTags: [])
        expect(partialPlug.contains { $0.id == "plug-adapter" }, "partial plug overlap must still add adapter")

        let context = TripPackingContext(
            activities: [.water, .outdoors, .snow, .skiing, .exercise, .business, .formal, .driving],
            stays: [.hostel], laundry: .yes)
        let contextual = PackingListGenerator.generate(for: trip(days: 12),
            preferences: preferences(style: .normal), packingContext: context, weatherTags: ["rain", "cold"])
        expect(contextual.first { $0.id == "tops" }?.quantity == 3, "laundry top cap mismatch")
        expect(contextual.first { $0.id == "bottoms" }?.quantity == 2, "laundry bottom cap mismatch")
        expect(contextual.first { $0.id == "underwear" }?.quantity == 4, "laundry underwear cap mismatch")
        expect(contextual.first { $0.id == "socks" }?.quantity == 4, "laundry socks cap mismatch")
        for id in ["swimsuit", "wet-item-bag", "outdoor-shoes", "daypack", "waterproof-nonslip-shoes",
                   "thermal-base-layer", "ski-socks", "ski-goggles", "ski-jacket", "ski-pants",
                   "workout-clothes", "business-clothes", "business-cards", "formal-clothes", "formal-shoes",
                   "driving-documents", "locker-lock", "slippers", "quick-dry-towel", "laundry-supplies", "laundry-bag"] {
            expect(contextual.contains { $0.id == id }, "missing contextual item \(id)")
        }
        expect(cases == 540, "unexpected matrix size")
        print("\(cases) single-engine destination/month/day/style cases: PASS")
    }

    @MainActor
    static func validateSnapshotsAndReview() throws {
        let prefs = preferences(style: .normal)
        let contextValue = TripPackingContext(activities: [], stays: [], laundry: .yes)
        let decodedPreferences = try JSONDecoder().decode(UserPreferences.self, from: JSONEncoder().encode(prefs))
        let decodedContext = try JSONDecoder().decode(TripPackingContext.self, from: JSONEncoder().encode(contextValue))
        expect(decodedPreferences == prefs, "preferences round trip failed")
        expect(decodedContext == contextValue, "context round trip failed")

        let schema = Schema([Trip.self, PackingItem.self, Expense.self, MedicalProfile.self,
            Medication.self, AllergyRecord.self, VaccineRecord.self, EmergencyContact.self])
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let modelContext = ModelContext(container)
        modelContext.autosaveEnabled = false

        let fixture = trip(days: 8)
        fixture.capturePackingPreferencesIfNeeded(prefs)
        fixture.capturePackingContextIfNeeded(contextValue)
        modelContext.insert(fixture)

        let tops = PackingItem(name: "上衣", category: .clothing, reasonKey: "原始建議",
            quantity: 12, sortIndex: 1, trip: fixture)
        tops.catalogItemID = "tops"
        let bottoms = PackingItem(name: "下身衣物", category: .clothing, reasonKey: "原始建議",
            quantity: 1, sortIndex: 2, trip: fixture)
        bottoms.catalogItemID = "bottoms"
        let obsolete = PackingItem(name: "正式鞋款", category: .clothing, reasonKey: "先前條件",
            quantity: 1, sortIndex: 3, trip: fixture)
        obsolete.catalogItemID = "formal-shoes"
        obsolete.isPacked = true
        let custom = PackingItem(name: "我的正式鞋", category: .clothing, reasonKey: "自訂",
            quantity: 1, isCustom: true, sortIndex: 4, trip: fixture)
        modelContext.insert(tops)
        modelContext.insert(bottoms)
        modelContext.insert(obsolete)
        modelContext.insert(custom)
        try modelContext.save()

        let review = PackingListGenerator.review(for: fixture)
        expect(review.reductions.first { $0.itemID == tops.id }?.suggestedQuantity == 3,
               "laundry top reduction missing")
        expect(review.increases.first { $0.itemID == bottoms.id }?.suggestedQuantity == 2,
               "quantity increase missing")
        expect(review.removals.contains { $0.itemID == obsolete.id && $0.isPacked },
               "obsolete automatic item missing")
        expect(!review.removals.contains { $0.itemID == custom.id }, "custom item must be protected")

        let applied = try PackingListGenerator.applyReview(trip: fixture, selectedAdditionIDs: [],
            selectedReductionIDs: [tops.id], selectedRemovalIDs: [obsolete.id], weather: nil, context: modelContext)
        expect(applied.increases == 0 && applied.reductions == 1 && applied.removals == 1,
               "selected review changes not applied")
        expect(tops.quantity == 3 && bottoms.quantity == 1, "unselected increase must remain unchanged")
        expect(fixture.packingReviewPending, "unselected increase must preserve review reminder")
        expect((fixture.packingItems ?? []).contains { $0.id == custom.id }, "custom item was removed")

        let followUpReview = PackingListGenerator.review(for: fixture)
        let followUp = try PackingListGenerator.applyReview(trip: fixture,
            selectedAdditionIDs: Set(followUpReview.additions.map(\.id)),
            selectedIncreaseIDs: Set(followUpReview.increases.map(\.id)),
            selectedReductionIDs: Set(followUpReview.reductions.map(\.id)),
            selectedRemovalIDs: Set(followUpReview.removals.map(\.id)),
            weather: nil, context: modelContext)
        expect(followUp.increases == 1 && bottoms.quantity == 2, "selected increase not applied")
        expect(!fixture.packingReviewPending, "completed review reminder must clear")

        let fresh = trip(country: "KR", city: "首爾")
        fresh.capturePackingPreferencesIfNeeded(preferences(devices: ["phone"]))
        fresh.capturePackingContextIfNeeded(.empty)
        modelContext.insert(fresh)
        let additions = PackingListGenerator.missingItems(for: fresh)
        let added = try PackingListGenerator.addMissing(trip: fresh, selectedIDs: Set(additions.map(\.id)),
            weather: nil, context: modelContext)
        expect(added == additions.count && added > 9, "new checklist additions failed")
        let repeated = try PackingListGenerator.addMissing(trip: fresh, selectedIDs: Set(additions.map(\.id)),
            weather: nil, context: modelContext)
        expect(repeated == 0, "repeated review created duplicates")

        fresh.packingPreferencesRaw = "broken"
        let protected = PackingListGenerator.review(for: fresh)
        expect(protected.isEmpty, "corrupt input must not create removal proposals")
        print("snapshots, two-way review, custom protection, pending reminder, idempotence: PASS")
    }
}
