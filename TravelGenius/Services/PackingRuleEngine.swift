import Foundation

/// The same all/any/none algebra applies to rules, needs and candidate items.
struct PackingTagCondition: Codable {
    let all: [String]?
    let any: [String]?
    let none: [String]?

    func matches(_ tags: Set<String>) -> Bool {
        (all == nil || Set(all!).isSubset(of: tags))
            && (any == nil || !Set(any!).isDisjoint(with: tags))
            && (none == nil || Set(none!).isDisjoint(with: tags))
    }

    var valid: Bool {
        [all, any, none].compactMap { $0 }.allSatisfy { values in
            !values.isEmpty && Set(values).count == values.count
                && values.allSatisfy { tag in
                    let parts = tag.split(separator: ":", omittingEmptySubsequences: false)
                    return parts.count == 2 && parts.allSatisfy { !$0.isEmpty }
                }
        }
    }
}

struct PackingRuleDocument: Codable {
    struct Quantity: Codable {
        let fixed: Int?
        let multiplier: Int?
        let perDays: Int?
        let maximum: Int?
        let laundryMaximum: Int?

        var valid: Bool {
            (fixed == nil || (1...99).contains(fixed!))
                && (multiplier == nil || (1...99).contains(multiplier!))
                && (perDays == nil || (1...99).contains(perDays!))
                && (maximum == nil || (1...99).contains(maximum!))
                && (laundryMaximum == nil || (1...99).contains(laundryMaximum!))
                && !(fixed != nil && (perDays != nil || multiplier != nil))
        }

        func resolve(days: Int, laundry: Bool) -> Int {
            let divisor = perDays ?? 1
            var value = fixed ?? (days * (multiplier ?? 1) + divisor - 1) / divisor
            if let maximum { value = min(value, maximum) }
            if laundry, let laundryMaximum { value = min(value, laundryMaximum) }
            return max(1, min(99, value))
        }
    }

    struct Need: Codable {
        let itemId: String?
        let need: String?
        let when: PackingTagCondition?
        let quantity: Quantity?
        let quantityByStyle: [String: Quantity]?
        let reasonZh: String?
        let nameZh: String?
        let sortIndex: Int?
    }

    struct Rule: Codable {
        let id: String
        let phase: Int
        let when: PackingTagCondition?
        let orderTag: String?
        let sortBase: Int?
        let reasonZh: String
        let needs: [Need]
    }

    let version: Int
    let rules: [Rule]

    var referencedItemIDs: Set<String> { Set(rules.flatMap { $0.needs.compactMap(\.itemId) }) }

    enum ContractError: Error { case invalidRule, invalidNeed, invalidQuantity }

    func validate(catalog: PackingCatalog) throws {
        guard version == 1, !rules.isEmpty, Set(rules.map(\.id)).count == rules.count else {
            throw ContractError.invalidRule
        }
        let ids = Set(catalog.items.map(\.id))
        let capabilities = Set(catalog.items.flatMap { $0.satisfies ?? [] })
        for rule in rules {
            guard !rule.id.isEmpty, !rule.reasonZh.isEmpty, (0...100).contains(rule.phase),
                  !rule.needs.isEmpty, rule.when?.valid != false,
                  rule.sortBase == nil || rule.sortBase! >= 0,
                  rule.orderTag == nil || rule.when?.all?.contains(rule.orderTag!) == true else {
                throw ContractError.invalidRule
            }
            for need in rule.needs {
                guard (need.itemId != nil) != (need.need != nil), need.when?.valid != false,
                      need.itemId.map(ids.contains) ?? need.need.map(capabilities.contains) ?? false,
                      need.sortIndex == nil || need.sortIndex! >= 0 else { throw ContractError.invalidNeed }
                guard need.quantity?.valid != false,
                      need.quantityByStyle == nil || (Set(need.quantityByStyle!.keys) == Set(PackingStyle.allCases.map(\.rawValue))
                        && need.quantityByStyle!.values.allSatisfy(\.valid)),
                      !(need.quantity != nil && need.quantityByStyle != nil) else { throw ContractError.invalidQuantity }
            }
        }
    }
}

/// Why an item was tailored to this trip, derived from the tag families its rule and need test.
/// Base rules test no tags and therefore carry no kind. Staple is assigned by the UI, not the engine.
enum PackingReasonKind: String, CaseIterable, Identifiable {
    case weather
    case trip
    case personal
    case destination
    case staple

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weather: "天氣"
        case .trip: "這趟安排"
        case .personal: "你的設定"
        case .destination: "目的地"
        case .staple: "常備"
        }
    }

    var symbolName: String {
        switch self {
        case .weather: "cloud.sun.fill"
        case .trip: "figure.hiking"
        case .personal: "person.fill"
        case .destination: "globe.asia.australia.fill"
        case .staple: "star.fill"
        }
    }

    static func kinds(testing conditions: [PackingTagCondition?]) -> Set<PackingReasonKind> {
        var tags: [String] = []
        for condition in conditions.compactMap({ $0 }) { tags += (condition.all ?? []) + (condition.any ?? []) }
        return Set(tags.compactMap { tag -> PackingReasonKind? in
            switch tag.split(separator: ":").first.map(String.init) {
            case "weather": .weather
            case "activity", "stay", "laundry": .trip
            case "device", "need", "style": .personal
            case "plug", "country": .destination
            default: nil
            }
        })
    }
}

/// One index over the canonical catalog; ID identity and artwork stay owned by the item.
struct PackingRuleEngine {
    let document: PackingRuleDocument
    let catalog: PackingCatalog
    private let itemsByID: [String: PackingCatalog.Item]
    private let candidatesByNeed: [String: [PackingCatalog.Item]]

    init(document: PackingRuleDocument, catalog: PackingCatalog) throws {
        try catalog.validate(referencedItemIDs: document.referencedItemIDs)
        try document.validate(catalog: catalog)
        self.document = document
        self.catalog = catalog
        itemsByID = Dictionary(uniqueKeysWithValues: catalog.items.map { ($0.id, $0) })
        var index: [String: [PackingCatalog.Item]] = [:]
        for item in catalog.items {
            for need in item.satisfies ?? [] { index[need, default: []].append(item) }
        }
        candidatesByNeed = index.mapValues { $0.sorted {
            ($0.priority ?? 10, $0.id) < ($1.priority ?? 10, $1.id)
        } }
    }

    func generate(tags: Set<String>, orderedTags: [String], days: Int, style: PackingStyle,
                  replacements: [String: String]) -> [PackingListGenerator.GeneratedItem] {
        var order: [String: Int] = [:]
        for (index, tag) in orderedTags.enumerated() where order[tag] == nil { order[tag] = index }
        let rules = document.rules.enumerated().sorted { lhs, rhs in
            let a = lhs.element, b = rhs.element
            return (a.phase, a.orderTag.flatMap { order[$0] } ?? 0, lhs.offset)
                < (b.phase, b.orderTag.flatMap { order[$0] } ?? 0, rhs.offset)
        }
        var seen = Set<String>()
        var results: [PackingListGenerator.GeneratedItem] = []
        var sortSequences: [Int: Int] = [:]
        func expand(_ text: String) -> String {
            replacements.reduce(text) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
        }
        for (_, rule) in rules where rule.when?.matches(tags) != false {
            for need in rule.needs where need.when?.matches(tags) != false {
                let item = need.itemId.flatMap { itemsByID[$0] }
                    ?? need.need.flatMap { candidatesByNeed[$0]?.first { $0.when?.matches(tags) != false } }
                let sortIndex: Int
                if let explicit = need.sortIndex { sortIndex = explicit }
                else if let base = rule.sortBase {
                    sortIndex = base + (sortSequences[base] ?? 0)
                    sortSequences[base, default: 0] += 1
                } else { sortIndex = 5_000 + results.count }
                guard let item, item.when?.matches(tags) != false, seen.insert(item.id).inserted else { continue }
                let quantity = need.quantityByStyle?[style.rawValue] ?? need.quantity
                results.append(.init(catalogItemID: item.id, name: expand(need.nameZh ?? item.nameZh),
                    category: item.category, quantity: quantity?.resolve(days: days, laundry: tags.contains("laundry:yes")) ?? 1,
                    reason: expand(need.reasonZh ?? rule.reasonZh), sortIndex: sortIndex,
                    kinds: PackingReasonKind.kinds(testing: [rule.when, need.when])))
            }
        }
        return results
    }
}
