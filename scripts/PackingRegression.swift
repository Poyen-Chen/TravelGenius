import Foundation
import SwiftData

@main
struct PackingRegression {
    static func expect(_ value: Bool) { precondition(value) }
    static let prefs = UserPreferences(ageBand: .adult, gender: .undisclosed, party: .solo, experience: .some, packingStyle: .full)

    static func trip(country: String = "JP", month: Int = 9, days: Int = 5) -> Trip {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: month, day: 10))!
        return Trip(name: "Regression fixture", countryCode: country, startDate: start,
                    endDate: Calendar.current.date(byAdding: .day, value: days - 1, to: start)!,
                    homeCurrencyCode: "TWD", localCurrencyCode: "JPY", totalBudget: 0, tripType: .leisure)
    }

    @MainActor
    static func main() throws {
        let mode = CommandLine.arguments[1]
        if mode == "matrix" {
            var count = 0
            for country in ["JP", "KR", "HK", "US", "VN"] {
                for month in 1...12 {
                    for days in [1, 5, 12] {
                        for style in PackingStyle.allCases {
                            for party in TravelParty.allCases {
                                for weather: Set<String>? in [nil, [], ["hot", "rain"], ["cold", "mild"]] {
                                    var preferences = prefs
                                    preferences.packingStyle = style
                                    preferences.party = party
                                    preferences.ageBand = AgeBand.allCases[month % AgeBand.allCases.count]
                                    preferences.gender = GenderPreference.allCases[month % GenderPreference.allCases.count]
                                    preferences.experience = TravelExperience.allCases[(month / 3) % TravelExperience.allCases.count]
                                    let items = PackingListGenerator.generate(for: trip(country: country, month: month, days: days), preferences: preferences, weatherTags: weather)
                                    #if !LEGACY
                                    precondition(Set(items.map(\.catalogItemID)).count == items.count)
                                    #endif
                                    let rows = items.map { "\($0.name)|\($0.category.rawValue)|\($0.quantity)|\($0.reason)|\($0.sortIndex)" }
                                    print("\(count):" + rows.joined(separator: ";"))
                                    count += 1
                                }
                            }
                        }
                    }
                }
            }
            return
        }
        let url = URL(fileURLWithPath: CommandLine.arguments[2])
        let schema = Schema([Trip.self, PackingItem.self, Expense.self, MedicalProfile.self,
                             Medication.self, AllergyRecord.self, VaccineRecord.self, EmergencyContact.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        if mode == "seed" {
            let fixture = trip()
            context.insert(fixture)
            let rows: [(String, Bool, Bool, Int)] = [
                ("護照", true, false, 1), ("換洗衣物", false, false, 99),
                ("行動電源", false, true, 3), ("舊版未知用品", false, false, 2),
                ("保暖外套", false, false, 1), ("圍巾手套", true, false, 1)
            ]
            for (index, row) in rows.enumerated() {
                let item = PackingItem(name: row.0, category: .other, reasonKey: "fixture", quantity: row.3, isCustom: row.2, trip: fixture)
                item.id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
                item.isPacked = row.1
                context.insert(item)
            }
            fixture.excludedPackingNames = ["防曬乳"]
            try context.save()
            print("legacy fixture saved")
            return
        }
        #if !LEGACY
        let fixture = try context.fetch(FetchDescriptor<Trip>()).first!
        if mode == "verify-reopen" {
            let items = try context.fetch(FetchDescriptor<PackingItem>())
            precondition(items.first { $0.name == "護照" }?.isPacked == true)
            precondition(items.first { $0.name == "換洗衣物" }?.quantity == 99)
            precondition(!items.contains { $0.catalogItemID == "sunscreen" || $0.catalogItemID == "luggage-lock" })
            precondition(fixture.excludedPackingIDs.contains("luggage-lock"))
            #if STAGE3
            precondition(fixture.packingPreferences == prefs)
            #endif
            print("reopened persisted candidate store: PASS")
            return
        }
        let catalog = StaticDataStore.shared.packingCatalog
        try catalog.validate(rules: StaticDataStore.shared.packingRules)
        precondition(catalog.legacyID(name: "插座轉接頭（當地 Type-G）") == "plug-adapter")
        // Reject malformed bundled contracts before applying any merge.
        let invalid = PackingCatalog(version: 1, items: catalog.items + [catalog.items[0]])
        do { try invalid.validate(rules: StaticDataStore.shared.packingRules); fatalError("duplicate accepted") }
        catch PackingCatalog.ContractError.duplicateIdentity { }
        let missing = PackingCatalog(version: 1, items: catalog.items.filter { $0.id != "passport" })
        do { try missing.validate(rules: StaticDataStore.shared.packingRules); fatalError("missing reference accepted") }
        catch PackingCatalog.ContractError.invalidReference { }
        var invalidRules = try JSONSerialization.jsonObject(with: JSONEncoder().encode(StaticDataStore.shared.packingRules)) as! [[String: Any]]
        var invalidItems = invalidRules[0]["items"] as! [[String: Any]]
        invalidItems[0]["quantity"] = 0
        invalidRules[0]["items"] = invalidItems
        let invalidQuantityRules = try JSONDecoder().decode([PackingRule].self, from: JSONSerialization.data(withJSONObject: invalidRules))
        do { try catalog.validate(rules: invalidQuantityRules); fatalError("invalid quantity accepted") }
        catch PackingCatalog.ContractError.invalidQuantity { }

        PackingListGenerator.sync(trip: fixture, context: context, preferences: prefs)
        try context.save()
        var items = try context.fetch(FetchDescriptor<PackingItem>())
        precondition(items.first { $0.name == "護照" }?.id.uuidString == "00000000-0000-0000-0000-000000000001")
        precondition(items.first { $0.name == "護照" }?.catalogItemID == "passport")
        precondition(items.first { $0.name == "護照" }?.isPacked == true)
        precondition(items.first { $0.name == "換洗衣物" }?.quantity == 99)
        precondition(items.filter { $0.name == "行動電源" }.count == 1)
        precondition(items.first { $0.name == "行動電源" }?.isCustom == true)
        precondition(items.first { $0.name == "行動電源" }?.catalogItemID == nil)
        precondition(items.contains { $0.name == "舊版未知用品" })
        precondition(!items.contains { $0.name == "保暖外套" })
        precondition(items.contains { $0.name == "圍巾手套" && $0.isPacked })
        precondition(!items.contains { $0.catalogItemID == "sunscreen" })
        let firstIDs = Set(items.map(\.id))
        PackingListGenerator.sync(trip: fixture, context: context, preferences: prefs)
        try context.save()
        items = try context.fetch(FetchDescriptor<PackingItem>())
        precondition(Set(items.map(\.id)) == firstIDs)
        // A saved item label can change without generating a duplicate.
        let passport = items.first { $0.catalogItemID == "passport" }!
        passport.name = "我的護照"
        let lock = items.first { $0.catalogItemID == "luggage-lock" }!
        lock.name = "改過名稱的行李鎖"
        fixture.excludePackingItem(lock)
        context.delete(lock)
        try context.save()
        PackingListGenerator.sync(trip: fixture, context: context, preferences: prefs)
        try context.save()
        items = try context.fetch(FetchDescriptor<PackingItem>())
        precondition(items.filter { $0.catalogItemID == "passport" }.count == 1)
        precondition(!items.contains { $0.catalogItemID == "luggage-lock" })
        passport.name = "護照"
        try context.save()
        #if STAGE3
        precondition(fixture.packingPreferences == prefs)
        let frozen = fixture.packingPreferencesRaw
        let before = Set(items.map(\.id))
        var changed = prefs
        changed.party = .family
        changed.packingStyle = .light
        // Explicit input cannot overwrite an established snapshot either.
        PackingListGenerator.sync(trip: fixture, context: context, preferences: changed)
        try context.save()
        precondition(fixture.packingPreferencesRaw == frozen)
        expect(Set(try context.fetch(FetchDescriptor<PackingItem>()).map(\.id)) == before)
        let defaultKeys = [UserPreferences.ageKey, UserPreferences.genderKey, UserPreferences.partyKey,
                           UserPreferences.experienceKey, UserPreferences.packingStyleKey]
        let previousDefaults = defaultKeys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(defaultKeys, previousDefaults) {
                if let value { UserDefaults.standard.set(value, forKey: key) }
                else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }
        changed.save()
        PackingListGenerator.sync(trip: fixture, context: context)
        try context.save()
        precondition(fixture.packingPreferences == prefs)
        expect(Set(try context.fetch(FetchDescriptor<PackingItem>()).map(\.id)) == before)
        let newTrip = trip()
        newTrip.capturePackingPreferencesIfNeeded(.load())
        precondition(newTrip.packingPreferences == changed)
        let newItems = PackingListGenerator.generate(for: newTrip)
        precondition(newItems.contains { $0.id == "children-medicine" })
        precondition(newItems.first { $0.id == "clothes-change" }?.quantity == 4)
        precondition(!PackingListGenerator.generate(for: fixture).contains { $0.id == "children-medicine" })

        let suiteName = "Packmon-Staples-Test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let staple = PackingStaples.Item(name: "  護照  ", category: .documents, quantity: 3)
        try PackingStaples.save([staple], defaults: defaults)
        let copied = try PackingStaples.load(defaults: defaults)
        precondition(copied == [staple])
        precondition(PackingStaples.catalogID(for: staple.name) == "passport")
        precondition(PackingStaples.matches(staple, recommendation: newItems.first { $0.id == "passport" }!))
        do { try PackingStaples.save([staple, .init(name: "護照", category: .documents, quantity: 1)], defaults: defaults); fatalError("duplicate staple") }
        catch PackingStaples.ValidationError.duplicate { }
        expect(try PackingStaples.load(defaults: defaults) == copied)
        for quantity in [0, 100] {
            do { try PackingStaples.save([.init(name: "Test", category: .other, quantity: quantity)], defaults: defaults); fatalError("invalid staple quantity") }
            catch PackingStaples.ValidationError.invalid { }
        }
        do { try PackingStaples.save([.init(name: "  ", category: .other, quantity: 1)], defaults: defaults); fatalError("blank staple") }
        catch PackingStaples.ValidationError.invalid { }
        try PackingStaples.save([], defaults: defaults)
        precondition(copied.count == 1) // Draft copy unaffected by library change.
        let encoded = UserDefaults.standard.data(forKey: PackingStaples.storageKey)
        defer {
            if let encoded { UserDefaults.standard.set(encoded, forKey: PackingStaples.storageKey) }
            else { UserDefaults.standard.removeObject(forKey: PackingStaples.storageKey) }
        }
        try PackingStaples.save([staple])
        PackingListGenerator.sync(trip: fixture, context: context)
        try context.save()
        expect(Set(try context.fetch(FetchDescriptor<PackingItem>()).map(\.id)) == before)
        defaults.set(Data("broken".utf8), forKey: PackingStaples.storageKey)
        do { _ = try PackingStaples.load(defaults: defaults); fatalError("corrupt library accepted") } catch { }
        fixture.packingPreferencesRaw = "broken"
        PackingListGenerator.sync(trip: fixture, context: context)
        expect(Set(try context.fetch(FetchDescriptor<PackingItem>()).map(\.id)) == before)
        fixture.packingPreferencesRaw = frozen
        try context.save()
        let isolated = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let stapleContext = ModelContext(isolated)
        let stapleTrip = trip()
        stapleContext.insert(stapleTrip)
        let stapleCopy = PackingItem(name: "  護照  ", category: .documents, reasonKey: "我的常備用品", quantity: 3, isCustom: true, trip: stapleTrip)
        stapleCopy.catalogItemID = PackingStaples.catalogID(for: stapleCopy.name)
        stapleContext.insert(stapleCopy)
        PackingListGenerator.sync(trip: stapleTrip, context: stapleContext, preferences: prefs)
        try stapleContext.save()
        let stapleRows = try stapleContext.fetch(FetchDescriptor<PackingItem>())
        precondition(stapleRows.filter { $0.catalogItemID == "passport" }.count == 1)
        precondition(stapleRows.first { $0.catalogItemID == "passport" }?.quantity == 3)
        stapleTrip.excludePackingItem(stapleCopy)
        stapleContext.delete(stapleCopy)
        try stapleContext.save()
        PackingListGenerator.sync(trip: stapleTrip, context: stapleContext)
        try stapleContext.save()
        expect(try stapleContext.fetch(FetchDescriptor<PackingItem>()).allSatisfy { $0.catalogItemID != "passport" })
        print("snapshot freeze, changed global defaults, new-trip adoption, staples validation/isolation, corrupt snapshot safety: PASS")
        #endif
        print("legacy migration, stable identity, merge preservation, exclusions, idempotence: PASS")
        #endif
    }
}
