import Foundation

/// Bundled V1 catalog. Recommendation behavior lives in Swift; this file only
/// provides item identity, display name and category.
struct PackingCatalog: Decodable {
    struct Item: Decodable {
        let id: String
        let nameZh: String
        let category: PackingCategory
        /// Bundled artwork owned by this canonical item definition.
        let artworkKey: String?
    }

    let version: Int
    let items: [Item]

    func item(id: String) -> Item? { items.first { $0.id == id } }

    func id(named name: String) -> String? {
        if let item = items.first(where: { $0.nameZh == name }) {
            return item.id
        }
        // The displayed plug type is dynamic even though its catalog identity is stable.
        if name.hasPrefix("插座轉接頭（當地 Type-"), name.hasSuffix("）") {
            return item(id: "plug-adapter")?.id
        }
        return nil
    }

    /// Resolve a trip record to its canonical definition. Stable identity always wins;
    /// exact current-name lookup is only a read-only fallback for pre-ID records.
    func definition(catalogID: String?, name: String, isCustom: Bool) -> Item? {
        if let catalogID, !catalogID.isEmpty { return item(id: catalogID) }
        guard !isCustom, let id = id(named: name) else { return nil }
        return item(id: id)
    }

    enum ContractError: Error {
        case invalidVersion, invalidItemCount, duplicateIdentity, invalidReference, invalidArtwork
    }

    func validate(referencedItemIDs: Set<String>) throws {
        guard version == 2 else { throw ContractError.invalidVersion }
        var ids = Set<String>()
        var names = Set<String>()
        for item in items {
            guard !item.id.isEmpty, !item.nameZh.isEmpty,
                  ids.insert(item.id).inserted,
                  names.insert(item.nameZh).inserted else {
                throw ContractError.duplicateIdentity
            }
        }
        let artworkKeys = items.compactMap(\.artworkKey)
        let allowedArtworkCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        guard artworkKeys.count == items.count,
              Set(artworkKeys).count == artworkKeys.count,
              artworkKeys.allSatisfy({ !$0.isEmpty && $0.rangeOfCharacter(from: allowedArtworkCharacters.inverted) == nil }) else {
            throw ContractError.invalidArtwork
        }
        guard items.count == 61 else { throw ContractError.invalidItemCount }
        guard referencedItemIDs.isSubset(of: ids) else { throw ContractError.invalidReference }
    }
}
