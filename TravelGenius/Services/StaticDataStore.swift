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

struct Currency: Codable, Identifiable, Hashable {
    let code: String
    let symbol: String
    let nameZh: String
    let decimals: Int

    var id: String { code }
}

struct PerDiemStandard: Codable, Identifiable {
    struct Caps: Codable {
        let food: Double
        let transport: Double
        let lodging: Double
    }

    let countryCode: String
    let currencyCode: String
    let caps: Caps

    var id: String { countryCode }
}

struct PackingRule: Codable {
    struct Match: Codable {
        let countries: [String]?
        let months: [Int]?
        let tripTypes: [String]?
    }

    struct Item: Codable {
        let nameZh: String
        let category: String
        let quantity: Int?
        let perDay: Bool?
    }

    let layer: String
    let match: Match?
    let reasonZh: String
    let items: [Item]

    func applies(countryCode: String, month: Int, tripType: TripType) -> Bool {
        guard let match else { return true }
        if let countries = match.countries, !countries.contains(countryCode) { return false }
        if let months = match.months, !months.contains(month) { return false }
        if let tripTypes = match.tripTypes, !tripTypes.contains(tripType.rawValue) { return false }
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

    var id: String { "\(countryCode)-\(itemZh)" }
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

struct DrugEntry: Codable, Identifiable {
    let brandZh: String
    let aliases: [String]?
    let generic: String
    let genericZh: String

    var id: String { brandZh }
}

struct MedicalTranslation: Codable {
    let cardTitle: String
    let name: String
    let bloodType: String
    let allergies: String
    let medications: String
    let history: String
    let vaccines: String
    let insurance: String
    let emergencyContacts: String
    let helpSentence: String
}

struct MedicalTranslations: Codable {
    struct AllergenEntry: Codable {
        let zh: String
        let translations: [String: String]
    }

    let languages: [String: MedicalTranslation]
    let allergens: [AllergenEntry]
}

struct ExchangeRateTable: Codable {
    /// 基準幣別（rates 的值 = 1 單位該幣別折合多少基準幣別）
    let base: String
    let asOf: String
    let source: String?
    let sourceUrl: String?
    let rates: [String: Double]
}

final class StaticDataStore {
    static let shared = StaticDataStore()

    private(set) lazy var countries: [Country] = load("countries")
    private(set) lazy var currencies: [Currency] = load("currencies")
    private(set) lazy var exchangeRates: ExchangeRateTable = load("exchange_rates")
    private(set) lazy var perDiems: [PerDiemStandard] = load("per_diem")
    private(set) lazy var packingRules: [PackingRule] = load("packing_rules")
    private(set) lazy var prohibitedItems: [ProhibitedItem] = load("prohibited_items")
    private(set) lazy var etiquetteCards: [EtiquetteCard] = load("etiquette")
    private(set) lazy var drugMap: [DrugEntry] = load("drug_map")
    private(set) lazy var medicalTranslations: MedicalTranslations = load("medical_translations")

    func country(code: String) -> Country? {
        countries.first { $0.code == code }
    }

    func currency(code: String) -> Currency? {
        currencies.first { $0.code == code }
    }

    func perDiem(countryCode: String) -> PerDiemStandard? {
        perDiems.first { $0.countryCode == countryCode }
    }

    func prohibitedItems(countryCode: String) -> [ProhibitedItem] {
        prohibitedItems.filter { $0.countryCode == countryCode }
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
