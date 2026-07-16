//
//  DrugMapper.swift
//  TravelGenius
//

import Foundation

/// 藥品商品名 → 國際學名對照，以及過敏原離線翻譯
enum DrugMapper {
    /// 依輸入即時建議（比對中文商品名與英文別名）
    static func suggestions(for query: String) -> [DrugEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 1 else { return [] }
        let lowered = trimmed.lowercased()
        return StaticDataStore.shared.drugMap.filter { entry in
            entry.brandZh.localizedStandardContains(trimmed)
                || entry.generic.lowercased().contains(lowered)
                || (entry.aliases ?? []).contains { $0.lowercased().contains(lowered) }
        }
    }

    /// 完全比對商品名，回傳學名
    static func generic(forBrand brand: String) -> DrugEntry? {
        let trimmed = brand.trimmingCharacters(in: .whitespaces)
        return StaticDataStore.shared.drugMap.first {
            $0.brandZh == trimmed || ($0.aliases ?? []).contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        }
    }

    /// 過敏原翻譯：先查常見過敏原字典，再查藥品學名；查無回傳 nil（顯示原文）
    static func translateAllergen(_ nameZh: String, to language: String) -> String? {
        let store = StaticDataStore.shared
        if let entry = store.medicalTranslations.allergens.first(where: { $0.zh == nameZh }) {
            return entry.translations[language]
        }
        if let drug = generic(forBrand: nameZh) {
            return drug.generic
        }
        return nil
    }

    /// 支援的翻譯語言（依語言代碼排序穩定）
    static var supportedLanguages: [String] {
        StaticDataStore.shared.medicalTranslations.languages.keys.sorted()
    }

    static func languageLabel(_ code: String) -> String {
        switch code {
        case "ja": "日本語"
        case "en": "English"
        case "ko": "한국어"
        case "th": "ไทย"
        case "it": "Italiano"
        case "vi": "Tiếng Việt"
        default: code
        }
    }

    /// 行程目的地的預設翻譯語言；不支援（如台灣）時退回英文
    static func defaultLanguage(forCountry countryCode: String?) -> String {
        guard let countryCode,
              let country = StaticDataStore.shared.country(code: countryCode),
              StaticDataStore.shared.medicalTranslations.languages[country.languageCode] != nil
        else { return "en" }
        return country.languageCode
    }
}
