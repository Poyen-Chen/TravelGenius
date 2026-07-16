//
//  Expense.swift
//  TravelGenius
//

import Foundation
import SwiftData

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case food
    case transport
    case lodging
    case shopping
    case entertainment
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .food: "餐飲"
        case .transport: "交通"
        case .lodging: "住宿"
        case .shopping: "購物"
        case .entertainment: "娛樂"
        case .other: "其他"
        }
    }

    var symbolName: String {
        switch self {
        case .food: "fork.knife"
        case .transport: "tram.fill"
        case .lodging: "bed.double.fill"
        case .shopping: "bag.fill"
        case .entertainment: "theatermasks.fill"
        case .other: "ellipsis.circle"
        }
    }
}

@Model
final class Expense {
    var id: UUID = UUID()
    var amount: Decimal = 0
    var currencyCode: String = "TWD"
    /// 記帳當下凍結的匯率（1 單位 currencyCode 折合多少本幣），離線歷史不受日後匯率變動影響
    var rateToHome: Decimal = 1
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var note: String = ""
    var date: Date = Date()
    var isReimbursable: Bool = false
    @Attribute(.externalStorage) var receiptImageData: Data?
    var trip: Trip?

    init(
        amount: Decimal,
        currencyCode: String,
        rateToHome: Decimal,
        category: ExpenseCategory,
        note: String = "",
        date: Date = Date(),
        trip: Trip? = nil
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.rateToHome = rateToHome
        self.categoryRaw = category.rawValue
        self.note = note
        self.date = date
        self.trip = trip
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// 折算為本幣的金額
    var amountInHome: Decimal {
        amount * rateToHome
    }
}
