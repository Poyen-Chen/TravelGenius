import Foundation
import CryptoKit

/// An immutable, whole-generation cache. Runtime never combines remote and bundled files.
final class ReferenceDataCache: @unchecked Sendable {
    static let files = ["countries", "cities", "packing_items", "packing_rules", "prohibited_items",
                        "aviation_rules", "etiquette", "border_rules", "seasonal_weather"]
    struct Manifest: Codable {
        let contractVersion: Int
        let files: [String: String]
    }
    enum Failure: Error { case invalidManifest, invalidData, incompatibleCatalog, invalidResponse }
    let root: URL
    let bundled: [String: Data]
    let active: [String: Data]?
    let etag: String?
    static let shared: ReferenceDataCache = {
        let build = "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "0")-\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "0")"
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReferenceData/contract-1/\(build)")
        let bundled = Dictionary(uniqueKeysWithValues: files.map { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { fatalError("Missing seed: \(name)") }
            return (name, data)
        })
        do { return try ReferenceDataCache(root: root, bundled: bundled) }
        catch { fatalError("Invalid bundled data contract: \(error)") }
    }()
    init(root: URL, bundled: [String: Data]) throws {
        self.root = root; self.bundled = bundled
        try Self.validate(bundled, bundled: bundled)
        // Pointer promotion is atomic; a crash leaves a complete previous or next generation.
        if let stage = Self.readPointer("staged", root: root),
           let _ = try? Self.readGeneration(stage, root: root, bundled: bundled) {
            try stage.write(to: root.appendingPathComponent("active"), atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(at: root.appendingPathComponent("staged"))
        }
        if let pointer = Self.readPointer("active", root: root),
           let data = try? Self.readGeneration(pointer, root: root, bundled: bundled) {
            active = data
            etag = try? String(contentsOf: root.appendingPathComponent(pointer).appendingPathComponent("etag"), encoding: .utf8)
        } else { active = nil; etag = nil }
    }
    func data(for name: String) -> Data? { (active ?? bundled)[name] }
    private static func readPointer(_ name: String, root: URL) -> String? {
        guard let value = try? String(contentsOf: root.appendingPathComponent(name), encoding: .utf8),
              UUID(uuidString: value) != nil else { return nil }
        return value
    }
    private static func readGeneration(_ id: String, root: URL, bundled: [String: Data]) throws -> [String: Data] {
        let directory = root.appendingPathComponent(id)
        let manifest = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        let data = try Dictionary(uniqueKeysWithValues: files.map {
            ($0, try Data(contentsOf: directory.appendingPathComponent("\($0).json")))
        })
        try verify(manifest: manifest, data: data, bundled: bundled)
        return data
    }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func verify(manifest: Data, data: [String: Data], bundled: [String: Data]) throws {
        let contract = try JSONDecoder().decode(Manifest.self, from: manifest)
        guard contract.contractVersion == 1, Set(contract.files.keys) == Set(files),
              Set(data.keys) == Set(files),
              files.allSatisfy({ contract.files[$0] == hash(data[$0]!) }) else { throw Failure.invalidManifest }
        try validate(data, bundled: bundled)
    }
    static func validate(_ data: [String: Data], bundled: [String: Data]) throws {
        func decode<T: Decodable>(_ name: String, _ type: T.Type) throws -> T {
            guard let bytes = data[name] else { throw Failure.invalidData }
            return try JSONDecoder().decode(type, from: bytes)
        }
        let catalog = try decode("packing_items", PackingCatalog.self)
        let rules = try decode("packing_rules", PackingRuleDocument.self)
        try catalog.validate(referencedItemIDs: rules.referencedItemIDs)
        try rules.validate(catalog: catalog)
        guard let original = bundled["packing_items"] else { throw Failure.invalidData }
        let shipped = try JSONDecoder().decode(PackingCatalog.self, from: original)
        // Catalog presentation is versioned with the app, never changed by a backend update.
        guard catalog.items.count == shipped.items.count,
              catalog.items.allSatisfy({ item in
                  shipped.items.contains { $0.id == item.id && $0.nameZh == item.nameZh
                      && $0.category == item.category && $0.artworkKey == item.artworkKey }
              }) else { throw Failure.incompatibleCatalog }
        let countries = try decode("countries", [Country].self)
        let codes = Set(countries.map(\.code))
        let required = Set(StaticDataStore.destinationCountryCodes + StaticDataStore.focusCountryCodes)
        let cities = try decode("cities", [City].self)
        let cityIDs = Set(cities.map(\.id))
        guard codes.count == countries.count, required.isSubset(of: codes), !cities.isEmpty,
              cityIDs.count == cities.count, cities.allSatisfy({ codes.contains($0.countryCode)
                  && !$0.cityZh.isEmpty && $0.lat.isFinite && $0.lon.isFinite
                  && (-90...90).contains($0.lat) && (-180...180).contains($0.lon) }),
              required.allSatisfy({ code in cities.contains { $0.countryCode == code && $0.isDefault } })
        else { throw Failure.invalidData }
        let profiles = try decode("seasonal_weather", [SeasonalProfile].self)
        let profileIDs = Set(profiles.map(\.cityID))
        let destinationIDs = Set(cities.filter { StaticDataStore.destinationCountryCodes.contains($0.countryCode) }.map(\.id))
        guard profileIDs.isSubset(of: cityIDs), destinationIDs.isSubset(of: profileIDs), profiles.count == profileIDs.count,
              profiles.allSatisfy({ $0.version == 1 && TimeZone(identifier: $0.timeZoneID) != nil
                  && ($0.hot + $0.cold + $0.rain).allSatisfy { (1...12).contains($0) } })
        else { throw Failure.invalidData }
        let prohibited = try decode("prohibited_items", [ProhibitedItem].self)
        let aviation = try decode("aviation_rules", [AviationRule].self)
        let etiquette = try decode("etiquette", [EtiquetteCard].self)
        let border = try decode("border_rules", [BorderRule].self)
        guard !prohibited.isEmpty, !aviation.isEmpty, !etiquette.isEmpty, !border.isEmpty,
              prohibited.allSatisfy({ codes.contains($0.countryCode) }),
              etiquette.allSatisfy({ codes.contains($0.countryCode) }),
              aviation.allSatisfy({ Set($0.departureCountries ?? []).isSubset(of: codes) }),
              Set(border.map(\.id)).count == border.count,
              border.allSatisfy({ codes.contains($0.countryCode) && !$0.id.isEmpty
                  && URL(string: $0.sourceUrl)?.scheme == "https" })
        else { throw Failure.invalidData }
    }
    /// Called only after the entire downloaded manifest has passed integrity and cross-file checks.
    func stage(manifest: Data, data: [String: Data], etag: String?) throws {
        try Self.verify(manifest: manifest, data: data, bundled: bundled)
        let id = UUID().uuidString
        let directory = root.appendingPathComponent(id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            for (name, bytes) in data { try bytes.write(to: directory.appendingPathComponent("\(name).json"), options: .atomic) }
            try manifest.write(to: directory.appendingPathComponent("manifest.json"), options: .atomic)
            if let etag { try etag.write(to: directory.appendingPathComponent("etag"), atomically: true, encoding: .utf8) }
            try id.write(to: root.appendingPathComponent("staged"), atomically: true, encoding: .utf8)
            var excluded = root
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try? excluded.setResourceValues(values)
        } catch { try? FileManager.default.removeItem(at: directory); throw error }
    }
}

/// Serializes refreshes; a failed/partial download never alters the last validated generation.
actor ReferenceDataUpdater {
    static let shared = ReferenceDataUpdater()
    enum Outcome: String { case disabled, busy, updated, notModified, rejected, failed }
    private var refreshing = false
    static var configuredBaseURL: URL? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-disableReferenceDataUpdate") { return nil }
        #if DEBUG
        if let index = args.firstIndex(of: "-referenceDataBaseURL"), index + 1 < args.count {
            return URL(string: args[index + 1])
        }
        #endif
        guard let value = Bundle.main.object(forInfoDictionaryKey: "PackSmartReferenceDataBaseURL") as? String,
              let url = URL(string: value), url.scheme == "https" else { return nil }
        return url
    }
    func refresh(baseURL: URL? = ReferenceDataUpdater.configuredBaseURL, cache: ReferenceDataCache = .shared,
                 session: URLSession = .shared) async -> Outcome {
        guard let baseURL else { return .disabled }
        guard !refreshing else { return .busy }
        refreshing = true
        defer { refreshing = false }
        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("manifest.json"))
            request.cachePolicy = .reloadIgnoringLocalCacheData; request.timeoutInterval = 20
            if cache.active != nil, let etag = cache.etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
            let (manifest, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed }
            if http.statusCode == 304 { return cache.active == nil ? .rejected : .notModified }
            guard http.statusCode == 200, manifest.count <= 64_000 else { return .failed }
            let decoded = try JSONDecoder().decode(ReferenceDataCache.Manifest.self, from: manifest)
            guard decoded.contractVersion == 1, Set(decoded.files.keys) == Set(ReferenceDataCache.files) else { return .rejected }
            var data: [String: Data] = [:]
            for name in ReferenceDataCache.files {
                var fileRequest = URLRequest(url: baseURL.appendingPathComponent("\(name).json"))
                fileRequest.cachePolicy = .reloadIgnoringLocalCacheData; fileRequest.timeoutInterval = 20
                let (bytes, response) = try await session.data(for: fileRequest)
                guard (response as? HTTPURLResponse)?.statusCode == 200, bytes.count <= 5_000_000 else { return .failed }
                data[name] = bytes
            }
            do { try cache.stage(manifest: manifest, data: data, etag: http.value(forHTTPHeaderField: "ETag")) }
            catch { return .rejected }
            return .updated
        } catch { return .failed }
    }
}
