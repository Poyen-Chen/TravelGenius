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

@Model
final class Trip {
    var id: UUID = UUID()
    var name: String = ""
    var countryCode: String = "JP"
    /// 目的地城市（中文名，選填；影響城市限定的文化提醒）
    var city: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var homeCurrencyCode: String = "TWD"
    var localCurrencyCode: String = "JPY"
    var totalBudget: Decimal = 0
    var tripTypeRaw: String = TripType.leisure.rawValue
    var isClosed: Bool = false
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

    func contains(_ date: Date) -> Bool {
        startDate <= date && date <= endDate
    }
}
