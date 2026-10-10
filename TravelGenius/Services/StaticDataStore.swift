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

enum ProhibitedSeverity: String, Codable, CaseIterable {
    case banned
    case permit
    case declare
    case review

    var label: String {
        switch self {
        case .banned: "禁止"
        case .permit: "需許可"
        case .declare: "需申報"
        case .review: "需確認"
        }
    }

    var symbolName: String {
        switch self {
        case .banned: "xmark.octagon.fill"
        case .permit: "exclamationmark.triangle.fill"
        case .declare: "doc.text.magnifyingglass"
        case .review: "checklist"
        }
    }
}

enum BorderCheckpoint: String, Codable, CaseIterable, Identifiable {
    case originDeparture
    case destinationArrival
    case destinationDeparture
    case originArrival

    var id: String { rawValue }

    var number: Int {
        switch self {
        case .originDeparture: 1
        case .destinationArrival: 2
        case .destinationDeparture: 3
        case .originArrival: 4
        }
    }

    var isDeparture: Bool {
        self == .originDeparture || self == .destinationDeparture
    }

    func countryCode(for trip: Trip) -> String {
        switch self {
        case .originDeparture, .originArrival: trip.originCountryCode
        case .destinationArrival, .destinationDeparture: trip.countryCode
        }
    }

    func title(for trip: Trip) -> String {
        let code = countryCode(for: trip)
        let country = StaticDataStore.shared.country(code: code)?.nameZh ?? code
        return "\(country)\(isDeparture ? "出境" : "入境")"
    }

    func date(for trip: Trip) -> Date {
        switch self {
        case .originDeparture, .destinationArrival: trip.startDate
        case .destinationDeparture, .originArrival: trip.endDate
        }
    }

    var legLabel: String {
        switch self {
        case .originDeparture, .destinationArrival: "去程"
        case .destinationDeparture, .originArrival: "回程"
        }
    }
}

enum BorderAuthority: String, Codable, CaseIterable, Identifiable {
    case customs
    case quarantine
    case aviation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .customs: "海關"
        case .quarantine: "檢疫"
        case .aviation: "航空安檢"
        }
    }

    var symbolName: String {
        switch self {
        case .customs: "doc.text.magnifyingglass"
        case .quarantine: "leaf"
        case .aviation: "airplane"
        }
    }
}

enum BorderRuleStatus: String, Codable {
    case avoid
    case declare
    case prepare
    case review

    var label: String {
        switch self {
        case .avoid: "避免攜帶"
        case .declare: "達門檻需申報"
        case .prepare: "待完成"
        case .review: "需確認"
        }
    }

    var symbolName: String {
        switch self {
        case .avoid: "xmark.octagon.fill"
        case .declare: "doc.text.magnifyingglass"
        case .prepare: "checklist"
        case .review: "exclamationmark.triangle.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .prepare: 0
        case .avoid: 1
        case .review: 2
        case .declare: 3
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
    /// 通關畫面的行動式標題；未提供時沿用 itemZh。
    let actionZh: String?
    /// nil 代表海關；動植物檢疫等條目需明確標示。
    let authority: BorderAuthority?
    /// 通關首頁的顯示優先序；數字越小越先顯示。
    let priority: Int?

    var id: String { "\(countryCode)-\(itemZh)" }
}

struct BorderRule: Codable, Identifiable {
    let id: String
    let countryCode: String
    let checkpoint: BorderCheckpoint
    let authority: BorderAuthority
    let status: BorderRuleStatus
    let titleZh: String
    let actionZh: String
    let detailZh: String
    let lastVerified: String
    let sourceName: String
    let sourceUrl: String
    let aliases: [String]?
    let keywords: [String]?
    let exclusions: [String]?
    let priority: Int?
    /// 日期採含首日／末日。nil 代表沒有日期邊界。
    let effectiveFrom: String?
    let effectiveUntil: String?

    func applies(on date: Date) -> Bool {
        let day = Self.dateFormatter.string(from: date)
        if let effectiveFrom, day < effectiveFrom {
            return false
        }
        if let effectiveUntil, day > effectiveUntil {
            return false
        }
        return true
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
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
    /// nil = 所有出發地通用；有值 = 只套用在實際離境的國家／地區。
    let departureCountries: [String]?
    let aliases: [String]?

    var id: String { itemZh }

    func applies(departureCountry: String) -> Bool {
        guard let departureCountries else { return true }
        return departureCountries.contains(departureCountry)
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
    static let destinationCountryCodes = ["JP", "KR", "HK", "US", "VN"]

    var destinationCountries: [Country] {
        Self.destinationCountryCodes.compactMap { country(code: $0) }
    }

    private(set) lazy var countries: [Country] = load("countries")
    private(set) lazy var cities: [City] = load("cities")
    private(set) lazy var seasonalProfiles: [SeasonalProfile] = load("seasonal_weather")
    private(set) lazy var packingRules: PackingRuleDocument = load("packing_rules")
    private(set) lazy var packingCatalog: PackingCatalog = {
        let catalog: PackingCatalog = load("packing_items")
        do { try catalog.validate(referencedItemIDs: PackingListGenerator.referencedItemIDs) }
        catch { fatalError("Invalid bundled packing contract: \(error)") }
        return catalog
    }()
    private(set) lazy var packingEngine: PackingRuleEngine = {
        do { return try PackingRuleEngine(document: packingRules, catalog: packingCatalog) }
        catch { fatalError("Invalid packing rule contract: \(error)") }
    }()
    private(set) lazy var prohibitedItems: [ProhibitedItem] = load("prohibited_items")
    private(set) lazy var borderRules: [BorderRule] = load("border_rules")
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

    func borderRules(countryCode: String, checkpoint: BorderCheckpoint, on date: Date = .now) -> [BorderRule] {
        borderRules.filter {
            $0.countryCode == countryCode
                && $0.checkpoint == checkpoint
                && $0.applies(on: date)
        }
    }

    func aviationRules(departureCountry: String) -> [AviationRule] {
        aviationRules.filter { $0.applies(departureCountry: departureCountry) }
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
        guard let data = ReferenceDataCache.shared.data(for: name),
              let value = try? JSONDecoder().decode(T.self, from: data)
        else {
            fatalError("Missing or invalid seed data: \(name).json")
        }
        return value
    }
}
