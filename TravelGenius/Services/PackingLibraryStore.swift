import Foundation
import SwiftData

/// Separate schema/store prevents enabling personal-library sync from uploading legacy health models.
@Model
final class PackingLibraryItem {
    var id: UUID = UUID()
    var name: String = ""
    var normalizedName: String = ""
    var categoryRaw: String = PackingCategory.other.rawValue
    var quantity: Int = 1
    var unitWeightKg: Double? = nil
    var isEssential: Bool = false
    var sortIndex: Int = 0
    var useCount: Int = 0
    var lastUsedAt: Date = Date()
    init(_ item: PackingStaples.Item) { update(item) }
    func update(_ item: PackingStaples.Item) {
        id = item.id; name = item.name; normalizedName = PackingStaples.normalized(item.name)
        categoryRaw = item.category.rawValue; quantity = item.quantity
        unitWeightKg = item.unitWeightKg; isEssential = true
    }
    var staple: PackingStaples.Item {
        .init(id: id, name: name, category: PackingCategory(rawValue: categoryRaw) ?? .other,
              quantity: quantity, unitWeightKg: unitWeightKg)
    }
}

@Model
final class PackingLibraryMigration {
    var key: String = "staples-v1"
    var completed: Bool = true
    init() {}
}

@MainActor
final class PackingLibraryStore {
    let container: ModelContainer
    private let defaults: UserDefaults
    private let migrationKey: String
    init(container: ModelContainer, defaults: UserDefaults = .standard) {
        self.container = container; self.defaults = defaults
        let installKey = "packing.library.installation-id"
        let id = defaults.string(forKey: installKey) ?? UUID().uuidString
        defaults.set(id, forKey: installKey)
        migrationKey = "staples-v1-\(id)"
    }
    static func open() throws -> PackingLibraryStore {
        let schema = Schema([PackingLibraryItem.self, PackingLibraryMigration.self])
        // CloudKit stays opt-in through signed build configuration; no team/container is assumed.
        let identifier = Bundle.main.object(forInfoDictionaryKey: "PackSmartLibraryCloudContainer") as? String
        let configuration = ModelConfiguration("PackingLibrary", schema: schema,
            cloudKitDatabase: identifier.map { .private($0) } ?? .none)
        return try PackingLibraryStore(container: ModelContainer(for: schema, configurations: [configuration]))
    }
    private func migratedContext() throws -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let markers = try context.fetch(FetchDescriptor<PackingLibraryMigration>())
        guard !markers.contains(where: { $0.key == migrationKey && $0.completed }) else { return context }
        // Read the preserved original directly, avoiding recursion through the facade.
        let legacy: [PackingStaples.Item]
        if let data = defaults.data(forKey: PackingStaples.storageKey) {
            struct Document: Decodable { let version: Int; let items: [PackingStaples.Item] }
            let document = try JSONDecoder().decode(Document.self, from: data)
            guard document.version == 1 else { throw PackingStaples.ValidationError.invalid }
            try PackingStaples.validate(document.items)
            legacy = document.items
        } else { legacy = [] }
        let existing = try context.fetch(FetchDescriptor<PackingLibraryItem>())
        for (index, item) in legacy.enumerated() where !existing.contains(where: {
            $0.id == item.id || $0.normalizedName == PackingStaples.normalized(item.name)
        }) {
            let record = PackingLibraryItem(item); record.sortIndex = index; context.insert(record)
        }
        let marker = PackingLibraryMigration(); marker.key = migrationKey
        context.insert(marker)
        try context.save() // Data and migration marker commit together; original defaults are retained.
        return context
    }
    func essentials() throws -> [PackingStaples.Item] {
        let context = try migratedContext()
        let items = try context.fetch(FetchDescriptor<PackingLibraryItem>())
            .filter(\.isEssential).sorted { ($0.sortIndex, $0.id.uuidString) < ($1.sortIndex, $1.id.uuidString) }.map(\.staple)
        try PackingStaples.validate(items) // Never silently discard conflicting/corrupt synced records.
        return items
    }
    func saveEssentials(_ items: [PackingStaples.Item]) throws {
        try PackingStaples.validate(items)
        let context = try migratedContext()
        let existing = try context.fetch(FetchDescriptor<PackingLibraryItem>())
        let ids = Set(items.map(\.id))
        // Retain history; removal from essentials is a durable flag, not a defaults resurrection.
        for record in existing where record.isEssential && !ids.contains(record.id) { record.isEssential = false }
        try PackingStaples.validate(existing.filter(\.isEssential).map(\.staple))
        for (index, item) in items.enumerated() {
            let record: PackingLibraryItem
            if let found = existing.first(where: { $0.id == item.id }) { record = found; record.update(item) }
            else if let found = existing.first(where: { $0.normalizedName == PackingStaples.normalized(item.name) }) { record = found; record.update(item) }
            else { record = PackingLibraryItem(item); context.insert(record) }
            record.sortIndex = index
        }
        try context.save()
    }
    /// Allows future callers to accumulate usage without changing the current UI or trip records.
    func recordUsage(name: String, category: PackingCategory, unitWeightKg: Double? = nil) throws {
        let item = PackingStaples.Item(name: name, category: category, quantity: 1, unitWeightKg: unitWeightKg)
        try PackingStaples.validate([item])
        let context = try migratedContext()
        let records = try context.fetch(FetchDescriptor<PackingLibraryItem>())
        let record: PackingLibraryItem
        if let found = records.first(where: { $0.normalizedName == PackingStaples.normalized(name) }) {
            record = found
            if let weight = unitWeightKg, weight > 0 { record.unitWeightKg = weight }
        } else {
            record = PackingLibraryItem(item); record.isEssential = false; context.insert(record)
        }
        record.useCount += 1; record.lastUsedAt = .now
        try context.save()
    }
}
