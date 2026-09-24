import Foundation

/// Explicitly managed local defaults, copied into creation drafts; never read by trip sync.
enum PackingStaples {
    struct Item: Codable, Identifiable, Equatable {
        var id = UUID()
        var name: String
        var category: PackingCategory
        var quantity: Int
        var unitWeightKg: Double? = nil
    }
    private struct Document: Codable {
        let version: Int
        let items: [Item]
    }
    static let storageKey = "packing.staples.v1"
    enum ValidationError: LocalizedError {
        case invalid, duplicate
        var errorDescription: String? {
            switch self {
            case .invalid: "常備用品資料無法讀取，或名稱／數量不正確。原資料未被覆寫。"
            case .duplicate: "已有同名的常備用品，請編輯原項目。"
            }
        }
    }
    static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
    static func validate(_ items: [Item]) throws {
        var names = Set<String>()
        var ids = Set<UUID>()
        var catalogIDs = Set<String>()
        for item in items {
            if let weight = item.unitWeightKg, !weight.isFinite || !(0...100).contains(weight) {
                throw ValidationError.invalid
            }
            guard !normalized(item.name).isEmpty, (1...99).contains(item.quantity), ids.insert(item.id).inserted else {
                throw ValidationError.invalid
            }
            guard names.insert(normalized(item.name)).inserted else { throw ValidationError.duplicate }
            if let id = catalogID(for: item.name), !catalogIDs.insert(id).inserted { throw ValidationError.duplicate }
        }
    }
    static func load(defaults: UserDefaults = .standard) throws -> [Item] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard document.version == 1 else { throw ValidationError.invalid }
        try validate(document.items)
        return document.items
    }
    static func save(_ items: [Item], defaults: UserDefaults = .standard) throws {
        try validate(items)
        let data = try JSONEncoder().encode(Document(version: 1, items: items))
        defaults.set(data, forKey: storageKey)
    }

    static func matchingItem(_ item: PackingItem, in items: [Item]) -> Item? {
        items.first { normalized($0.name) == normalized(item.name)
            || (catalogID(for: $0.name) != nil && catalogID(for: $0.name) == item.catalogItemID) }
    }
    static func matches(_ staple: Item, recommendation: PackingListGenerator.GeneratedItem) -> Bool {
        normalized(staple.name) == normalized(recommendation.name)
            || catalogID(for: staple.name) == recommendation.id
    }
    static func catalogID(for name: String) -> String? {
        let catalog = StaticDataStore.shared.packingCatalog
        return catalog.legacyID(name: name) ?? catalog.items.first { item in
            (item.legacyNames + [item.nameZh]).contains { normalized($0) == normalized(name) }
        }?.id
    }
}
