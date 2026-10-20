import Foundation
import SwiftData

final class FixtureProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data, [String: String]))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data, headers) = try Self.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@main struct BackendRegression {
    static func check(_ value: Bool, _ message: String) { precondition(value, message) }
    static func rejects(_ message: String, _ action: () throws -> Void) {
        do { try action(); preconditionFailure(message) } catch {}
    }
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let files = try Dictionary(uniqueKeysWithValues: ReferenceDataCache.files.map {
            ($0, try Data(contentsOf: Bundle.main.url(forResource: $0, withExtension: "json")!))
        })
        let manifest = try JSONEncoder().encode(ReferenceDataCache.Manifest(contractVersion: 1, files: files.mapValues(ReferenceDataCache.hash)))
        let cache = try ReferenceDataCache(root: root.appendingPathComponent("cache"), bundled: files)
        check(cache.active == nil, "fresh cache must use bundle")
        try cache.stage(manifest: manifest, data: files, etag: "v1")
        check(cache.active == nil, "staging must not change current launch")
        let next = try ReferenceDataCache(root: cache.root, bundled: files)
        check(next.active != nil && next.etag == "v1", "next launch promotes entire generation")
        var corrupt = files; corrupt["packing_rules"] = Data("{}".utf8)
        rejects("hash mismatch accepted") { try next.stage(manifest: manifest, data: corrupt, etag: "bad") }
        let badManifest = try JSONEncoder().encode(ReferenceDataCache.Manifest(contractVersion: 1, files: corrupt.mapValues(ReferenceDataCache.hash)))
        rejects("invalid rules with matching hash accepted") { try next.stage(manifest: badManifest, data: corrupt, etag: "bad") }
        var catalog = try JSONSerialization.jsonObject(with: files["packing_items"]!) as! [String: Any]
        var items = catalog["items"] as! [[String: Any]]; items[0]["artworkKey"] = "unknown-art"; catalog["items"] = items
        corrupt = files; corrupt["packing_items"] = try JSONSerialization.data(withJSONObject: catalog)
        rejects("unshipped artwork accepted") { try ReferenceDataCache.validate(corrupt, bundled: files) }
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [FixtureProtocol.self]
        let session = URLSession(configuration: configuration)
        let url = URL(string: "https://fixture.invalid/data/")!
        let updater = ReferenceDataUpdater()
        FixtureProtocol.handler = { request in
            if request.url!.lastPathComponent == "manifest.json" { return (200, manifest, ["ETag": "v2"]) }
            if request.url!.lastPathComponent == "border_rules.json" { return (503, Data(), [:]) }
            return (200, files[request.url!.deletingPathExtension().lastPathComponent]!, [:])
        }
        check(await updater.refresh(baseURL: url, cache: next, session: session) == .failed, "partial response accepted")
        let retained = try ReferenceDataCache(root: cache.root, bundled: files)
        check(retained.etag == "v1", "partial download changed active")
        FixtureProtocol.handler = { request in
            check(request.value(forHTTPHeaderField: "If-None-Match") == "v1", "missing conditional header")
            return (304, Data(), [:])
        }
        check(await updater.refresh(baseURL: url, cache: retained, session: session) == .notModified, "304 with validated cache")
        FixtureProtocol.handler = { _ in (304, Data(), [:]) }
        check(await updater.refresh(baseURL: url, cache: cache, session: session) == .rejected, "304 without cache accepted")
        FixtureProtocol.handler = { request in
            if request.url!.lastPathComponent == "manifest.json" { return (200, manifest, ["ETag": "v2"]) }
            return (200, files[request.url!.deletingPathExtension().lastPathComponent]!, [:])
        }
        check(await updater.refresh(baseURL: url, cache: retained, session: session) == .updated, "complete refresh failed")
        check(retained.etag == "v1", "current generation mutated")
        let refreshed = try ReferenceDataCache(root: cache.root, bundled: files)
        check(refreshed.etag == "v2", "full update not promoted")
        let activeID = try String(contentsOf: cache.root.appendingPathComponent("active"), encoding: .utf8)
        try Data("corrupt".utf8).write(to: cache.root.appendingPathComponent(activeID).appendingPathComponent("cities.json"))
        let fallback = try ReferenceDataCache(root: cache.root, bundled: files)
        check(fallback.active == nil && fallback.data(for: "packing_rules") == files["packing_rules"], "corrupt cache must fall back as whole bundle")
        check(PackingTagCondition(all: ["a:1"], any: ["b:1", "b:2"], none: ["c:1"]).matches(["a:1", "b:2"]), "all/any/none")
        check(!PackingTagCondition(all: ["a:1"], any: nil, none: ["c:1"]).matches(["a:1", "c:1"]), "excluded tag matched")
        let decoder = JSONDecoder()
        let canonical = try decoder.decode(PackingCatalog.self, from: files["packing_items"]!)
        let needDocument = try decoder.decode(PackingRuleDocument.self, from: Data(#"{"version":1,"rules":[{"id":"rain","phase":0,"reasonZh":"fixture","needs":[{"need":"rain-cover"}]}]}"#.utf8))
        let engine = try PackingRuleEngine(document: needDocument, catalog: canonical)
        check(engine.generate(tags: [], orderedTags: [], days: 5, style: .normal, replacements: [:]).first?.id == "folding-umbrella", "candidate priority changed")
        var candidates = try JSONSerialization.jsonObject(with: files["packing_items"]!) as! [String: Any]
        var candidateItems = candidates["items"] as! [[String: Any]]
        let umbrella = candidateItems.firstIndex { $0["id"] as? String == "folding-umbrella" }!
        candidateItems[umbrella]["when"] = ["none": ["activity:hiking"]]
        candidates["items"] = candidateItems
        let conditional = try decoder.decode(PackingCatalog.self, from: JSONSerialization.data(withJSONObject: candidates))
        let fallbackEngine = try PackingRuleEngine(document: needDocument, catalog: conditional)
        check(fallbackEngine.generate(tags: ["activity:hiking"], orderedTags: [], days: 5, style: .normal, replacements: [:]).first?.id == "rain-jacket", "ineligible candidate selected")
        let badRule = try decoder.decode(PackingRuleDocument.self, from: Data(#"{"version":1,"rules":[{"id":"missing","phase":0,"reasonZh":"fixture","needs":[{"itemId":"missing-id"}]}]}"#.utf8))
        rejects("unknown catalog reference accepted") { _ = try PackingRuleEngine(document: badRule, catalog: canonical) }
        let trip = Trip(name: "snapshot", countryCode: "JP", startDate: .now, endDate: .now,
            homeCurrencyCode: "TWD", localCurrencyCode: "JPY", totalBudget: 0, tripType: .leisure)
        let oldDevices = UserDefaults.standard.object(forKey: "pref.devices")
        defer {
            if let oldDevices { UserDefaults.standard.set(oldDevices, forKey: "pref.devices") }
            else { UserDefaults.standard.removeObject(forKey: "pref.devices") }
        }
        UserDefaults.standard.set(["phone"], forKey: "pref.devices")
        let first = PackingListGenerator.generate(for: trip, weatherTags: []).map(\.id)
        UserDefaults.standard.set(["laptop"], forKey: "pref.devices")
        check(PackingListGenerator.generate(for: trip, weatherTags: []).map(\.id) == first, "legacy trip depended on device defaults")
        reasonKinds()
        try library(root: root)
        print("backend contracts, atomic cache, ETag/partial failure, bundle fallback, library migration and weight retention: PASS")
    }
    /// Badge provenance follows the tag families a rule tests; base rules carry none.
    @MainActor static func reasonKinds() {
        let trip = Trip(name: "kinds", countryCode: "JP", startDate: .now, endDate: .now.addingTimeInterval(4 * 86_400),
            homeCurrencyCode: "TWD", localCurrencyCode: "JPY", totalBudget: 0, tripType: .leisure)
        trip.originCountryCode = "GB"
        let kinds = Dictionary(uniqueKeysWithValues: PackingListGenerator.generate(for: trip,
            preferences: UserPreferences(packingStyle: .normal, devices: ["laptop"], needs: []),
            packingContext: TripPackingContext(activities: [.outdoors], stays: [], laundry: .unknown),
            weatherTags: ["cold"]).map { ($0.catalogItemID, $0.kinds) })
        check(kinds["passport"] == [], "base item must carry no reason kind")
        check(kinds["warm-coat"] == [.weather], "weather item kind")
        check(kinds["outdoor-shoes"] == [.trip], "activity item kind")
        check(kinds["laptop"] == [.personal], "device item kind")
        check(kinds["plug-adapter"] == [.destination], "plug item kind")
        // `none` only marks the default branch: clothing is tailored when laundry cuts the count, not otherwise.
        check(kinds["socks"] == [], "default clothing must carry no reason kind")
        let laundry = Dictionary(uniqueKeysWithValues: PackingListGenerator.generate(for: trip,
            preferences: UserPreferences(packingStyle: .normal, devices: [], needs: []),
            packingContext: TripPackingContext(activities: [], stays: [], laundry: .yes),
            weatherTags: []).map { ($0.catalogItemID, $0.kinds) })
        check(laundry["socks"] == [.trip], "laundry clothing kind")
    }
    @MainActor static func library(root: URL) throws {
        let suite = "backend-regression-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let item = PackingStaples.Item(name: " My gear ", category: .other, quantity: 2, unitWeightKg: 0.42)
        let second = PackingStaples.Item(name: "second gear", category: .other, quantity: 3)
        try PackingStaples.save([item, second], defaults: defaults)
        let original = defaults.data(forKey: PackingStaples.storageKey)
        let schema = Schema([PackingLibraryItem.self, PackingLibraryMigration.self])
        let configuration = ModelConfiguration(schema: schema, url: root.appendingPathComponent("library.store"), cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let library = PackingLibraryStore(container: container, defaults: defaults)
            check(try library.essentials() == [item, second], "migration lost identity/quantity/weight")
            check(try library.essentials().count == 2, "migration duplicated")
            try library.recordUsage(name: "ＭＹ GEAR", category: .other, unitWeightKg: 0)
            check(try library.essentials().first?.unitWeightKg == 0.42, "zero input erased known weight")
            try library.saveEssentials([])
            check(try library.essentials().isEmpty, "essential removal failed")
        }
        let reopened = try ModelContainer(for: schema, configurations: [configuration])
        let library = PackingLibraryStore(container: reopened, defaults: defaults)
        check(try library.essentials().isEmpty, "relaunch resurrected legacy essential")
        check(defaults.data(forKey: PackingStaples.storageKey) == original, "migration overwrote original")
        let records = try ModelContext(reopened).fetch(FetchDescriptor<PackingLibraryItem>())
        check(records.count == 2 && records.reduce(0, { $0 + $1.useCount }) == 1, "normalized usage duplicated library")
        let invalidSuite = "backend-invalid-\(UUID().uuidString)"
        let invalidDefaults = UserDefaults(suiteName: invalidSuite)!
        defer { invalidDefaults.removePersistentDomain(forName: invalidSuite) }
        invalidDefaults.set(Data("broken".utf8), forKey: PackingStaples.storageKey)
        let memory = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let invalid = PackingLibraryStore(container: memory, defaults: invalidDefaults)
        rejects("corrupt legacy source accepted") { _ = try invalid.essentials() }
        check(try ModelContext(memory).fetchCount(FetchDescriptor<PackingLibraryMigration>()) == 0, "failed migration marked complete")
    }
}
