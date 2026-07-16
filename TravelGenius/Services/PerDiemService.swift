//
//  PerDiemService.swift
//  TravelGenius
//

import Foundation

/// 依國家每日津貼標準，計算某日各類別的使用狀況
enum PerDiemService {
    struct CategoryUsage: Identifiable {
        let category: ExpenseCategory
        /// 上限（津貼標準幣別）
        let cap: Double
        /// 已使用（津貼標準幣別）
        let used: Double

        var ratio: Double { cap > 0 ? used / cap : 0 }
        var id: String { category.rawValue }
    }

    struct Result {
        let standard: PerDiemStandard
        let usages: [CategoryUsage]

        var worst: CategoryUsage? {
            usages.max { $0.ratio < $1.ratio }
        }
    }

    static func usage(for trip: Trip, on date: Date = .now) -> Result? {
        guard let standard = StaticDataStore.shared.perDiem(countryCode: trip.countryCode) else { return nil }
        let calendar = Calendar.current
        let todays = (trip.expenses ?? []).filter { calendar.isDate($0.date, inSameDayAs: date) }
        let service = CurrencyService.shared

        func used(in category: ExpenseCategory) -> Double {
            todays
                .filter { $0.category == category }
                .reduce(0.0) { total, expense in
                    // 支出原幣＝津貼標準幣別時直接取原值，避免經過匯率表往返造成誤差
                    if expense.currencyCode == standard.currencyCode {
                        return total + expense.amount.doubleValue
                    }
                    return total + service.convert(expense.amountInHome, from: trip.homeCurrencyCode, to: standard.currencyCode).doubleValue
                }
        }

        let usages = [
            CategoryUsage(category: .food, cap: standard.caps.food, used: used(in: .food)),
            CategoryUsage(category: .transport, cap: standard.caps.transport, used: used(in: .transport)),
            CategoryUsage(category: .lodging, cap: standard.caps.lodging, used: used(in: .lodging)),
        ]
        return Result(standard: standard, usages: usages)
    }
}
