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
    case upcoming
    case inProgress
    case completed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .upcoming: "未開始"
        case .inProgress: "進行中"
        case .completed: "已完成"
        }
    }

    var symbolName: String {
        switch self {
        case .upcoming: "calendar"
        case .inProgress: "airplane.departure"
        case .completed: "checkmark.circle"
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
    /// 舊版相容欄位。新版建立流程不再產生草稿。
    var isDraft: Bool = false
    /// 舊版相容欄位。
    var draftCreationStep: Int = 1
    /// 使用者主動按下「開始行程」的時間；日期本身不會自動改變狀態。
    var startedAt: Date?
    /// 使用者主動按下「完成行程」的時間。
    var completedAt: Date?
    /// 使用者在建立流程中已看過海關與出入境提醒。
    var hasReviewedTravelRules: Bool = false
    /// 使用者主動取消的自動推薦，避免重新產生清單時又被加入。
    var excludedPackingNamesRaw: String = ""
    /// 行李限重（公斤），預設 23（多數航空託運上限）
    var baggageAllowanceKg: Double = 23
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
        if completedAt != nil || isClosed { return .completed }
        if startedAt != nil { return .inProgress }
        return .upcoming
    }

    func lifecycleStatus(relativeTo date: Date) -> TripLifecycleStatus {
        lifecycleStatus
    }

    func shouldPromptToStart(relativeTo date: Date = .now) -> Bool {
        guard lifecycleStatus == .upcoming else { return false }
        return Calendar.current.startOfDay(for: date) >= Calendar.current.startOfDay(for: startDate)
    }

    func shouldPromptToComplete(relativeTo date: Date = .now) -> Bool {
        guard lifecycleStatus == .inProgress else { return false }
        return Calendar.current.startOfDay(for: date) >= Calendar.current.startOfDay(for: endDate)
    }

    func start(relativeTo date: Date = .now) {
        startedAt = date
        completedAt = nil
        isClosed = false
        isDraft = false
    }

    func complete(relativeTo date: Date = .now) {
        if startedAt == nil { startedAt = date }
        completedAt = date
        isClosed = true
    }

    func reopen(relativeTo date: Date = .now) {
        startedAt = date
        completedAt = nil
        isClosed = false
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

    /// 全部行李估計總重（公克）
    var estimatedTotalGrams: Int {
        (packingItems ?? []).reduce(0) { $0 + $1.estimatedTotalGrams }
    }

    /// 依總重（單件×數量）由重到輕排序 — 供「該砍哪些」提示。
    var itemsByWeightDescending: [PackingItem] {
        (packingItems ?? []).sorted { $0.estimatedTotalGrams > $1.estimatedTotalGrams }
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
