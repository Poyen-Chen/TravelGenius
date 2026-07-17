//
//  Trip.swift
//  TravelGenius
//

import Foundation
import SwiftData

enum TripType: String, Codable, CaseIterable, Identifiable {
    case leisure
    case business
    case backpacking
    case family

    var id: String { rawValue }

    var label: String {
        switch self {
        case .leisure: "觀光"
        case .business: "商務"
        case .backpacking: "背包"
        case .family: "家庭"
        }
    }
}

enum TripLifecycleStatus: String, CaseIterable, Identifiable {
    case draft
    case upcoming
    case inProgress
    case history

    var id: String { rawValue }

    var label: String {
        switch self {
        case .draft: "草稿"
        case .upcoming: "未開始"
        case .inProgress: "進行中"
        case .history: "歷史行程"
        }
    }

    var symbolName: String {
        switch self {
        case .draft: "doc.badge.clock"
        case .upcoming: "calendar"
        case .inProgress: "airplane.departure"
        case .history: "clock.arrow.circlepath"
        }
    }
}

@Model
final class Trip {
    var id: UUID = UUID()
    var name: String = ""
    var countryCode: String = "JP"
    /// 目的地城市（中文名，選填；影響城市限定的文化提醒）
    var city: String = ""
    /// 出發地（回程入境的海關規定、航線安檢規則依此判定）
    var originCountryCode: String = "TW"
    var originCity: String = "台北"
    var startDate: Date = Date()
    var endDate: Date = Date()
    var homeCurrencyCode: String = "TWD"
    var localCurrencyCode: String = "JPY"
    var totalBudget: Decimal = 0
    var tripTypeRaw: String = TripType.leisure.rawValue
    var isClosed: Bool = false
    /// 建立流程尚未完成；草稿不會成為「目前行程」。
    var isDraft: Bool = false
    /// 草稿停留的建立步驟（1...3）。
    var draftCreationStep: Int = 1
    /// 使用者在建立流程中已看過海關與出入境提醒。
    var hasReviewedTravelRules: Bool = false
    /// 使用者主動取消的自動推薦，避免重新產生清單時又被加入。
    var excludedPackingNamesRaw: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Expense.trip)
    var expenses: [Expense]? = []

    @Relationship(deleteRule: .cascade, inverse: \PackingItem.trip)
    var packingItems: [PackingItem]? = []

    init(
        name: String,
        countryCode: String,
        startDate: Date,
        endDate: Date,
        homeCurrencyCode: String,
        localCurrencyCode: String,
        totalBudget: Decimal,
        tripType: TripType
    ) {
        self.name = name
        self.countryCode = countryCode
        self.startDate = startDate
        self.endDate = endDate
        self.homeCurrencyCode = homeCurrencyCode
        self.localCurrencyCode = localCurrencyCode
        self.totalBudget = totalBudget
        self.tripTypeRaw = tripType.rawValue
    }

    var tripType: TripType {
        get { TripType(rawValue: tripTypeRaw) ?? .leisure }
        set { tripTypeRaw = newValue.rawValue }
    }

    var lifecycleStatus: TripLifecycleStatus {
        lifecycleStatus(relativeTo: .now)
    }

    func lifecycleStatus(relativeTo date: Date) -> TripLifecycleStatus {
        if isDraft { return .draft }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        if isClosed || today > end { return .history }
        if today < start { return .upcoming }
        return .inProgress
    }

    var excludedPackingNames: Set<String> {
        get {
            Set(excludedPackingNamesRaw
                .split(separator: "\n")
                .map(String.init))
        }
        set {
            excludedPackingNamesRaw = newValue.sorted().joined(separator: "\n")
        }
    }

    func excludePackingItem(named name: String) {
        var names = excludedPackingNames
        names.insert(name)
        excludedPackingNames = names
    }

    func includePackingItem(named name: String) {
        var names = excludedPackingNames
        names.remove(name)
        excludedPackingNames = names
    }

    /// 旅程總天數（含出發與回程當日）
    var totalDays: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(days + 1, 1)
    }

    var sortedExpenses: [Expense] {
        (expenses ?? []).sorted { $0.date > $1.date }
    }

    /// 已花費金額（本幣）
    var spentHome: Decimal {
        (expenses ?? []).reduce(0) { $0 + $1.amountInHome }
    }

    /// 日期是否落在旅程期間（endDate 儲存為回程日 00:00，需涵蓋回程日整天）
    func contains(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        guard let dayAfterEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) else {
            return false
        }
        return date >= start && date < dayAfterEnd
    }
}
