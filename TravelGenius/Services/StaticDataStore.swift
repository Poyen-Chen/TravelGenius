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

    var id: String { "\(countryCode)-\(cityZh)" }
}

struct PackingRule: Codable {
    struct Match: Codable {
        let countries: [String]?
        let months: [Int]?
        /// 線上天氣模式下取代 months 的標籤（rain / hot / cold / mild）
        let weatherTags: [String]?
        let parties: [String]?
        let experiences: [String]?
        let ageBands: [String]?
        let genders: [String]?
    }

    struct Item: Codable {
        let nameZh: String
        let category: String
        let quantity: Int?
        let perDay: Bool?
        /// true = 僅「完整打包」風格納入（輕便風格略過）
        let fullOnly: Bool?
    }

    let layer: String
    let match: Match?
    let reasonZh: String
    let items: [Item]

    func applies(
        countryCode: String,
        month: Int,
        preferences: UserPreferences,
        weatherTags: Set<String>?
    ) -> Bool {
        guard let match else { return true }
        if let countries = match.countries, !countries.contains(countryCode) { return false }
        if let parties = match.parties, !parties.contains(preferences.party.rawValue) { return false }
        if let experiences = match.experiences, !experiences.contains(preferences.experience.rawValue) { return false }
        if let ageBands = match.ageBands, !ageBands.contains(preferences.ageBand.rawValue) { return false }
        if let genders = match.genders, !genders.contains(preferences.gender.rawValue) { return false }

        // 天氣層：有即時預報時以 weatherTags 判定，否則退回月份規則
        if layer == "weather" {
            if let weatherTags {
                guard let ruleTags = match.weatherTags else { return false }
                return !weatherTags.isDisjoint(with: ruleTags)
            }
            if let months = match.months { return months.contains(month) }
            return false
        }
        if let months = match.months, !months.contains(month) { return false }
        return true
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

    private func load<T: Decodable>(_ name: String) -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(T.self, from: data)
        else {
            fatalError("Missing or invalid seed data: \(name).json")
        }
        return value
    }
}
