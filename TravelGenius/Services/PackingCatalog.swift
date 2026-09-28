import Foundation

/// Bundled, versioned identity contract. Display names may change; IDs must not.
struct PackingCatalog: Decodable {
    struct Item: Decodable {
        let id: String
        let nameZh: String
        let category: PackingCategory
        let legacyNames: [String]
        /// Bundled artwork owned by this canonical item definition.
        let artworkKey: String?
    }

    let version: Int
    let activeItemIDs: [String]?
    let items: [Item]

    func item(id: String) -> Item? { items.first { $0.id == id } }
    func isActive(id: String) -> Bool { activeItemIDs?.contains(id) == true }
    func legacyDisplayName(id: String) -> String? {
        guard let item = item(id: id) else { return nil }
        return item.legacyNames.first ?? item.nameZh
    }

    func legacyID(name: String) -> String? {
        if let item = items.first(where: { $0.nameZh == name || $0.legacyNames.contains(name) }) {
            return item.id
        }
        // The old generator interpolated plug types into the display name.
        if name.hasPrefix("插座轉接頭（當地 Type-"), name.hasSuffix("）") {
            return item(id: "plug-adapter")?.id
        }
        return nil
    }

    /// Resolve a trip record to its canonical definition. Stable identity always wins;
    /// exact legacy-name lookup is read-only compatibility for pre-ID records.
    func definition(catalogID: String?, name: String, isCustom: Bool) -> Item? {
        if let catalogID, !catalogID.isEmpty { return item(id: catalogID) }
        guard !isCustom, let legacyID = legacyID(name: name) else { return nil }
        return item(id: legacyID)
    }

    enum ContractError: Error {
        case invalidVersion, duplicateIdentity, invalidReference, invalidQuantity,
             invalidActiveCatalog, invalidArtwork
    }

    func validate(rules: [PackingRule]) throws {
        guard version == 2 else { throw ContractError.invalidVersion }
        var ids = Set<String>()
        var names = [String: String]()
        for item in items {
            guard !item.id.isEmpty, !item.nameZh.isEmpty, ids.insert(item.id).inserted else {
                throw ContractError.duplicateIdentity
            }
            for name in item.legacyNames + [item.nameZh] {
                guard names[name] == nil || names[name] == item.id else { throw ContractError.duplicateIdentity }
                names[name] = item.id
            }
        }
        guard let activeItemIDs,
              activeItemIDs.count == 61,
              Set(activeItemIDs).count == activeItemIDs.count,
              Set(activeItemIDs).isSubset(of: ids) else {
            throw ContractError.invalidActiveCatalog
        }
        let activeIDs = Set(activeItemIDs)
        let artworkKeys = items.filter { activeIDs.contains($0.id) }.compactMap(\.artworkKey)
        let allowedArtworkCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        guard artworkKeys.count == activeIDs.count,
              Set(artworkKeys).count == artworkKeys.count,
              artworkKeys.allSatisfy({ !$0.isEmpty && $0.rangeOfCharacter(from: allowedArtworkCharacters.inverted) == nil }),
              items.filter({ !activeIDs.contains($0.id) }).allSatisfy({ $0.artworkKey == nil }) else {
            throw ContractError.invalidArtwork
        }
        guard ids.contains("plug-adapter") else { throw ContractError.invalidReference }
        var ruleIDs = Set<String>()
        for rule in rules {
            guard !rule.id.isEmpty, ruleIDs.insert(rule.id).inserted else { throw ContractError.duplicateIdentity }
            for reference in rule.items {
                guard ids.contains(reference.itemId) else { throw ContractError.invalidReference }
                guard (reference.quantity ?? 1) > 0,
                      !(reference.perDay == true && reference.quantity != nil) else { throw ContractError.invalidQuantity }
            }
        }
    }
}
