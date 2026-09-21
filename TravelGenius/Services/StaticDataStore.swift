//
//  StaticDataStore.swift
//  TravelGenius
//

import Foundation

struct Country: Codable, Identifiable, Hashable {
    struct EmergencyNumbers: Codable, Hashable {
        let police: String
        let ambulance: String
        let fire: String
    }

    let code: String
    let nameZh: String
    let nameEn: String
    let currencyCode: String
    let languageCode: String
    let emergency: EmergencyNumbers
    let plugTypes: [String]
    let voltage: String
    /// 自動欄位的開放資料來源（由 scripts/fetch_reference.py 產生）
    let sourceUrl: String?

    var id: String { code }

    var flagEmoji: String {
        code.unicodeScalars
            .compactMap { UnicodeScalar(127397 + $0.value) }
            .map(String.init)
            .joined()
    }
}

struct City: Codable, Identifiable, Hashable {
    let countryCode: String
    let cityZh: String
    let lat: Double
    let lon: Double
    let isDefault: Bool
    /// 自動欄位的開放資料來源（由 scripts/fetch_reference.py 產生）
    let sourceUrl: String?

    var id: String { "\(countryCode)-\(cityZh)" }
}

/// 物品目錄：每件東西只在這裡定義一次，規則以 id 引用。
/// `satisfies` 讓多件物品成為同一需求的候選（例如摺疊傘與輕便雨衣都能擋雨），
/// 解析時依 priority 取最優先的一件。
struct PackingCatalogItem: Codable, Identifiable {
    let id: String
    let nameZh: String
    let category: String
    let weightGrams: Int?
    let tags: [String]?
    let satisfies: [String]?
    /// 同一需求的候選排序，數字小的優先。未指定視為 10。
    let priority: Int?

    var resolvedPriority: Int { priority ?? 10 }
    var packingCategory: PackingCategory { PackingCategory(rawValue: category) ?? .other }
}

/// Tag 條件式。三個欄位都省略代表「永遠成立」。
/// all：全部都要在 context 裡；any：至少一個；none：一個都不能有。
struct TagCondition: Codable {
    let all: [String]?
    let any: [String]?
    let none: [String]?

    func matches(_ context: Set<String>) -> Bool {
        if let all, !Set(all).isSubset(of: context) { return false }
        if let any, Set(any).isDisjoint(with: context) { return false }
        if let none, !Set(none).isDisjoint(with: context) { return false }
        return true
    }
}

struct PackingRule: Codable {
    /// 一項需求：指定 itemId 直接取該物品，指定 need 則透過 satisfies 索引解析。
    struct Need: Codable {
        let itemId: String?
        let need: String?
        let quantity: Int?
        /// true = 數量隨天數成長（受打包風格上限節制）
        let perDay: Bool?
        /// 這一項自己的條件，讓同一條規則能依情境增減內容
        let when: TagCondition?
    }

    let id: String
    let when: TagCondition?
    let reasonZh: String
    let needs: [Need]

    func applies(to context: Set<String>) -> Bool {
        when?.matches(context) ?? true
    }
}

enum ProhibitedSeverity: String, Codable, CaseIterable {
    case banned
    case permit
    case declare

    var label: String {
        switch self {
        case .banned: "禁止"
        case .permit: "需許可"
        case .declare: "需申報"
        }
    }

    var symbolName: String {
        switch self {
        case .banned: "xmark.octagon.fill"
        case .permit: "exclamationmark.triangle.fill"
        case .declare: "doc.text.magnifyingglass"
        }
    }
}

struct ProhibitedItem: Codable, Identifiable {
    let countryCode: String
    let itemZh: String
    let severity: ProhibitedSeverity
    let reasonZh: String
    let lastVerified: String
    /// 官方資訊來源（顯示於條目旁，供查證）
    let sourceName: String?
    let sourceUrl: String?
    /// 「能帶嗎」查詢用的口語同義詞（肉鬆、香腸 → 肉類製品）
    let aliases: [String]?
    /// 語意關鍵字：查詢詞含任一關鍵字即命中（肉絲、肉脯 → 含「肉」）
    let keywords: [String]?
    /// 排除詞：查詢詞含任一排除詞則不命中（肉桂、素肉不是肉品）
    let exclusions: [String]?

    var id: String { "\(countryCode)-\(itemZh)" }
}

enum AviationRestriction: String, Codable {
    case banned
    case carryOnOnly
    case checkedOnly
    case limited

    var label: String {
        switch self {
        case .banned: "禁止"
        case .carryOnOnly: "限隨身"
        case .checkedOnly: "限托運"
        case .limited: "限量"
        }
    }

    var symbolName: String {
        switch self {
        case .banned: "xmark.octagon.fill"
        case .carryOnOnly: "airplane"
        case .checkedOnly: "suitcase.rolling.fill"
        case .limited: "exclamationmark.triangle.fill"
        }
    }
}

struct AviationRule: Codable, Identifiable {
    let itemZh: String
    let restriction: AviationRestriction
    let detailZh: String
    let lastVerified: String
    let sourceName: String?
    let sourceUrl: String?
    /// nil = 所有航班通用；有值 = 僅特定目的地國家顯示
    let countries: [String]?
    let aliases: [String]?

    var id: String { itemZh }

    /// 航線任一端（出發地或目的地）符合即適用
    func applies(route: Set<String>) -> Bool {
        guard let countries else { return true }
        return !route.isDisjoint(with: countries)
    }
}

struct EtiquetteCard: Codable, Identifiable {
    let countryCode: String
    /// nil = 全國通用；有值 = 城市限定（例如「東京」）
    let cityZh: String?
    let titleZh: String
    let bodyZh: String
    /// 涉及法規罰則的條目附上官方來源
    let sourceName: String?
    let sourceUrl: String?

    var id: String { "\(countryCode)-\(cityZh ?? "全國")-\(titleZh)" }
}

final class StaticDataStore {
    static let shared = StaticDataStore()

    /// 聚焦版鎖定東亞三國
    static let focusCountryCodes = ["JP", "KR", "TW"]

    private(set) lazy var countries: [Country] = load("countries")
    private(set) lazy var cities: [City] = load("cities")
    private(set) lazy var packingRules: [PackingRule] = load("packing_rules")
    private(set) lazy var packingCatalog: [PackingCatalogItem] = load("packing_items")

    /// id → 物品。規則以 id 引用，去重也用 id，不再比對顯示名稱。
    private(set) lazy var packingCatalogByID: [String: PackingCatalogItem] =
        Dictionary(packingCatalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    /// need → 候選物品（已依 priority 排序）。這是 need 解析用的索引。
    private(set) lazy var packingItemsBySatisfiedNeed: [String: [PackingCatalogItem]] = {
        var index: [String: [PackingCatalogItem]] = [:]
        for item in packingCatalog {
            for need in item.satisfies ?? [] { index[need, default: []].append(item) }
        }
        return index.mapValues { $0.sorted { $0.resolvedPriority < $1.resolvedPriority } }
    }()
    private(set) lazy var prohibitedItems: [ProhibitedItem] = load("prohibited_items")
    private(set) lazy var etiquetteCards: [EtiquetteCard] = load("etiquette")
    private(set) lazy var aviationRules: [AviationRule] = load("aviation_rules")

    var focusCountries: [Country] {
        Self.focusCountryCodes.compactMap { code in countries.first { $0.code == code } }
    }

    func country(code: String) -> Country? {
        countries.first { $0.code == code }
    }

    func cities(countryCode: String) -> [City] {
        cities.filter { $0.countryCode == countryCode }
    }

    func defaultCity(countryCode: String) -> City? {
        cities(countryCode: countryCode).first { $0.isDefault }
            ?? cities(countryCode: countryCode).first
    }

    func city(countryCode: String, name: String) -> City? {
        cities.first { $0.countryCode == countryCode && $0.cityZh == name }
    }

    func prohibitedItems(countryCode: String) -> [ProhibitedItem] {
        prohibitedItems.filter { $0.countryCode == countryCode }
    }

    func aviationRules(destination: String, origin: String = "TW") -> [AviationRule] {
        let route: Set<String> = [destination, origin]
        return aviationRules.filter { $0.applies(route: route) }
    }

    func etiquetteCards(countryCode: String) -> [EtiquetteCard] {
        etiquetteCards.filter { $0.countryCode == countryCode }
    }

    /// 該國有城市限定文化提醒的城市清單（依資料檔順序去重）
    func etiquetteCities(countryCode: String) -> [String] {
        var seen = Set<String>()
        return etiquetteCards(countryCode: countryCode)
            .compactMap(\.cityZh)
            .filter { seen.insert($0).inserted }
    }

    /// 遠端優先、Bundle 保底：有通過驗證的熱更新快取就用快取，否則讀 App 內建的 SeedData
    private func load<T: Decodable>(_ name: String) -> T {
        if let cached = ReferenceDataUpdater.cachedData(for: name),
           let value = try? JSONDecoder().decode(T.self, from: cached) {
            #if DEBUG
            NSLog("REFERENCE-DATA load %@ from cache", name)
            #endif
            return value
        }
        #if DEBUG
        NSLog("REFERENCE-DATA load %@ from bundle", name)
        #endif
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(T.self, from: data)
        else {
            fatalError("Missing or invalid seed data: \(name).json")
        }
        return value
    }
}
