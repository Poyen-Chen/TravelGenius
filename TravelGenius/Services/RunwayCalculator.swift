//
//  RunwayCalculator.swift
//  TravelGenius
//

import Foundation

enum RunwayStatus: String {
    case safe
    case caution
    case over

    var label: String {
        switch self {
        case .safe: "安全"
        case .caution: "注意"
        case .over: "超支"
        }
    }
}

/// 跑道計算：全部以本幣（Double）計算，供儀表板與圖表使用
struct RunwayCalculator {
    struct DayTotal: Identifiable {
        let day: Date
        let total: Double
        var id: Date { day }
    }

    let totalBudget: Double
    let totalDays: Int
    let spent: Double
    let spentBeforeToday: Double
    let todaySpent: Double
    /// 已經過的旅程天數（含今日；未出發為 0）
    let daysElapsed: Int
    /// 旅程剩餘天數（含今日；已結束為 0）
    let remainingTripDays: Int
    /// 出發日至今（不超過回程日）的每日支出
    let dailySeries: [DayTotal]
    let categoryTotals: [(category: ExpenseCategory, total: Double)]

    init(trip: Trip, now: Date = .now) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: trip.startDate)
        let end = calendar.startOfDay(for: trip.endDate)

        totalBudget = trip.totalBudget.doubleValue
        totalDays = trip.totalDays

        let expenses = trip.expenses ?? []
        spent = expenses.reduce(0) { $0 + $1.amountInHome.doubleValue }
        todaySpent = expenses
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .reduce(0) { $0 + $1.amountInHome.doubleValue }
        spentBeforeToday = spent - todaySpent

        if today < start {
            daysElapsed = 0
        } else {
            let capped = min(today, end)
            daysElapsed = (calendar.dateComponents([.day], from: start, to: capped).day ?? 0) + 1
        }

        if today > end {
            remainingTripDays = 0
        } else {
            let from = max(today, start)
            remainingTripDays = (calendar.dateComponents([.day], from: from, to: end).day ?? 0) + 1
        }

        let byDay = Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
        var series: [DayTotal] = []
        var day = start
        let lastDay = min(max(today, start), end)
        while day <= lastDay {
            let total = (byDay[day] ?? []).reduce(0.0) { $0 + $1.amountInHome.doubleValue }
            series.append(DayTotal(day: day, total: total))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        dailySeries = series

        let byCategory = Dictionary(grouping: expenses) { $0.category }
        categoryTotals = ExpenseCategory.allCases.compactMap { category in
            guard let items = byCategory[category], !items.isEmpty else { return nil }
            let total = items.reduce(0.0) { $0 + $1.amountInHome.doubleValue }
            return (category, total)
        }
    }

    var remainingBudget: Double { totalBudget - spent }

    /// 依總預算平均分配的每日預算
    var dailyBudget: Double {
        totalDays > 0 ? totalBudget / Double(totalDays) : 0
    }

    /// 日燒錢率：已花費 ÷ 已經過天數
    var burnRatePerDay: Double {
        daysElapsed > 0 ? spent / Double(daysElapsed) : 0
    }

    /// 跑道：照目前燒錢率還能撐幾天（尚無支出時為 nil）
    var runwayDays: Double? {
        burnRatePerDay > 0 ? max(remainingBudget, 0) / burnRatePerDay : nil
    }

    /// 今日建議上限：(總預算 − 今日前已花費) ÷ 剩餘天數（當日內維持穩定；行程結束後為 0）
    var todayCap: Double {
        guard remainingTripDays > 0 else { return 0 }
        return max(totalBudget - spentBeforeToday, 0) / Double(remainingTripDays)
    }

    var status: RunwayStatus {
        // 未設定預算時不判定超支
        guard totalBudget > 0 else { return .safe }
        if remainingBudget < 0 { return .over }
        guard let runway = runwayDays else { return .safe }
        let remaining = Double(remainingTripDays)
        if runway >= remaining { return .safe }
        if runway >= remaining * 0.8 { return .caution }
        return .over
    }
}

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
