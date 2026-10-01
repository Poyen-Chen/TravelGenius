//
//  CanIBringService.swift
//  TravelGenius
//
//  亮點功能「這個能帶嗎」：離線比對海關違禁品與航空安檢規則（含口語別名），
//  即問即答並附官方來源。
//

import Foundation

struct BringVerdict: Identifiable {
    enum Kind: Int {
        case banned = 0
        case permit
        case declare
        case carryOnOnly
        case checkedOnly
        case limited
        case review
        case unrestricted

        var label: String {
            switch self {
            case .banned: "禁止攜帶"
            case .permit: "需事先許可"
            case .declare: "需申報"
            case .carryOnOnly: "限隨身・禁托運"
            case .checkedOnly: "限托運・禁隨身"
            case .limited: "有限量規定"
            case .review: "需進一步確認"
            case .unrestricted: "尚未收錄"
            }
        }

        var symbolName: String {
            switch self {
            case .banned: "xmark.octagon.fill"
            case .permit: "exclamationmark.triangle.fill"
            case .declare: "doc.text.magnifyingglass"
            case .carryOnOnly: "airplane"
            case .checkedOnly: "suitcase.rolling.fill"
            case .limited: "exclamationmark.triangle.fill"
            case .review: "checklist"
            case .unrestricted: "questionmark.circle.fill"
            }
        }
    }

    let kind: Kind
    /// 命中的規則名稱（例如「肉類製品（火腿、香腸等）」）
    let matchedName: String
    let reason: String
    let sourceName: String?
    let sourceUrl: String?
    let lastVerified: String?
    /// 方向標示（「入境日本・去程」「回程入境台灣」「航空安檢」）
    let context: String?

    var id: String { "\(kind.rawValue)-\(context ?? "")-\(matchedName)" }
}

enum CanIBringService {
    /// 同時查四道通關關卡與航線安檢；
    /// 回傳最嚴重的前三筆，查無命中時明確標為「尚未收錄」。
    static func check(
        _ query: String,
        destination: String,
        origin: String = "TW",
        travelStartDate: Date = .now,
        travelEndDate: Date = .now
    ) -> [BringVerdict] {
        let normalized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return [] }

        let store = StaticDataStore.shared
        var verdicts: [BringVerdict] = []

        func customsMatches(countryCode: String, context: String) {
            for item in store.prohibitedItems(countryCode: countryCode)
            where matches(
                query: normalized,
                name: item.itemZh,
                aliases: item.aliases,
                keywords: item.keywords,
                exclusions: item.exclusions
            ) {
                verdicts.append(BringVerdict(
                    kind: kind(for: item.severity),
                    matchedName: item.itemZh,
                    reason: item.reasonZh,
                    sourceName: item.sourceName,
                    sourceUrl: item.sourceUrl,
                    lastVerified: item.lastVerified,
                    context: context
                ))
            }
        }

        let destinationName = store.country(code: destination)?.nameZh ?? destination
        customsMatches(countryCode: destination, context: "入境\(destinationName)・去程")
        if origin != destination {
            let originName = store.country(code: origin)?.nameZh ?? origin
            customsMatches(countryCode: origin, context: "回程入境\(originName)")
        }

        for checkpoint in BorderCheckpoint.allCases {
            let countryCode: String
            switch checkpoint {
            case .originDeparture, .originArrival: countryCode = origin
            case .destinationArrival, .destinationDeparture: countryCode = destination
            }
            let countryName = store.country(code: countryCode)?.nameZh ?? countryCode
            let ruleDate: Date
            switch checkpoint {
            case .originDeparture, .destinationArrival: ruleDate = travelStartDate
            case .destinationDeparture, .originArrival: ruleDate = travelEndDate
            }
            for rule in store.borderRules(countryCode: countryCode, checkpoint: checkpoint, on: ruleDate)
            where matches(
                query: normalized,
                name: rule.titleZh,
                aliases: rule.aliases,
                keywords: rule.keywords,
                exclusions: rule.exclusions
            ) {
                verdicts.append(BringVerdict(
                    kind: kind(for: rule.status),
                    matchedName: rule.titleZh,
                    reason: rule.detailZh,
                    sourceName: rule.sourceName,
                    sourceUrl: rule.sourceUrl,
                    lastVerified: rule.lastVerified,
                    context: "\(countryName)\(checkpoint.isDeparture ? "出境" : "入境")・\(checkpoint.legLabel)"
                ))
            }
        }

        for (departureCountry, context) in [
            (origin, "去程・\(store.country(code: origin)?.nameZh ?? origin)出境航空安檢"),
            (destination, "回程・\(store.country(code: destination)?.nameZh ?? destination)出境航空安檢")
        ] {
            for rule in store.aviationRules(departureCountry: departureCountry)
            where matches(query: normalized, name: rule.itemZh, aliases: rule.aliases) {
                verdicts.append(BringVerdict(
                    kind: kind(for: rule.restriction),
                    matchedName: rule.itemZh,
                    reason: rule.detailZh,
                    sourceName: rule.sourceName,
                    sourceUrl: rule.sourceUrl,
                    lastVerified: rule.lastVerified,
                    context: context
                ))
            }
        }

        if verdicts.isEmpty {
            return [BringVerdict(
                kind: .unrestricted,
                matchedName: query.trimmingCharacters(in: .whitespacesAndNewlines),
                reason: "目前收錄的四道通關與航空安檢規則中沒有找到可判定的資料。這不代表可以攜帶；請向海關、檢疫機關或航空公司確認。",
                sourceName: nil,
                sourceUrl: nil,
                lastVerified: nil,
                context: nil
            )]
        }

        return Array(verdicts.sorted { $0.kind.rawValue < $1.kind.rawValue }.prefix(3))
    }

    /// 異體字正規化：讓「電子菸」「臺灣」等寫法也能命中
    private static func canonicalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "菸", with: "煙")
            .replacingOccurrences(of: "臺", with: "台")
            .replacingOccurrences(of: "裏", with: "裡")
    }

    /// 三層比對：
    /// 1. 別名雙向包含（「日本的感冒藥」⇋「感冒藥」，查詢至少 2 字）
    /// 2. 語意關鍵字（「肉絲」含「肉」→ 肉類製品），排除詞優先（「肉桂」不是肉品）
    private static func matches(
        query: String,
        name: String,
        aliases: [String]?,
        keywords: [String]? = nil,
        exclusions: [String]? = nil
    ) -> Bool {
        let query = canonicalize(query)

        if let exclusions, exclusions.contains(where: { query.contains(canonicalize($0)) }) {
            return false
        }

        let candidates = [name] + (aliases ?? [])
        for candidate in candidates {
            let lowered = canonicalize(candidate)
            if query.contains(lowered) { return true }
            if query.count >= 2 && lowered.contains(query) { return true }
        }

        if let keywords, keywords.contains(where: { query.contains(canonicalize($0)) }) {
            return true
        }
        return false
    }

    private static func kind(for severity: ProhibitedSeverity) -> BringVerdict.Kind {
        switch severity {
        case .banned: .banned
        case .permit: .permit
        case .declare: .declare
        case .review: .review
        }
    }

    private static func kind(for status: BorderRuleStatus) -> BringVerdict.Kind {
        switch status {
        case .avoid: .banned
        case .declare: .declare
        case .prepare, .review: .review
        }
    }

    private static func kind(for restriction: AviationRestriction) -> BringVerdict.Kind {
        switch restriction {
        case .banned: .banned
        case .carryOnOnly: .carryOnOnly
        case .checkedOnly: .checkedOnly
        case .limited: .limited
        }
    }
}
