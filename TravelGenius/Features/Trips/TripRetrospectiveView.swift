//
//  TripRetrospectiveView.swift
//  TravelGenius
//

import SwiftUI
import Charts

struct TripRetrospectiveView: View {
    let trip: Trip

    private var calc: RunwayCalculator { RunwayCalculator(trip: trip) }

    /// 與預算的差距（正 = 低於預算）
    private var savedRatio: Double {
        guard calc.totalBudget > 0 else { return 0 }
        return (calc.totalBudget - calc.spent) / calc.totalBudget
    }

    private var averagePerDay: Double {
        calc.spent / Double(max(trip.totalDays, 1))
    }

    /// 下次預算建議：實際日均 × 1.1 × 天數，取百位進位
    private var suggestion: Double {
        (averagePerDay * 1.1 * Double(trip.totalDays) / 100).rounded(.up) * 100
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("總支出")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    MoneyText(amount: Decimal(calc.spent), currencyCode: trip.homeCurrencyCode)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    if savedRatio >= 0 {
                        Text("低於預算 \(abs(savedRatio), format: .percent.precision(.fractionLength(1)))")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.green)
                    } else {
                        Text("超出預算 \(abs(savedRatio), format: .percent.precision(.fractionLength(1)))")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("支出節奏") {
                LabeledContent("平均每日") {
                    MoneyText(amount: Decimal(averagePerDay), currencyCode: trip.homeCurrencyCode)
                }
                if !calc.dailySeries.isEmpty {
                    Chart(calc.dailySeries) { day in
                        BarMark(
                            x: .value("日期", day.day, unit: .day),
                            y: .value("支出", day.total)
                        )
                        .foregroundStyle(.tint)
                        RuleMark(y: .value("每日預算", calc.dailyBudget))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 160)
                    .padding(.vertical, 4)
                    .accessibilityLabel("每日支出曲線")
                }
            }

            if !calc.categoryTotals.isEmpty {
                Section("類別佔比") {
                    Chart(calc.categoryTotals, id: \.category) { item in
                        BarMark(
                            x: .value("金額", item.total),
                            y: .value("類別", item.category.label)
                        )
                        .foregroundStyle(item.category.color.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: CGFloat(calc.categoryTotals.count) * 44)
                    .padding(.vertical, 4)
                    .accessibilityLabel("各類別支出佔比")
                }
            }

            Section("下次參考") {
                LabeledContent("下次預算建議") {
                    MoneyText(amount: Decimal(suggestion), currencyCode: trip.homeCurrencyCode)
                        .font(.headline)
                }
                Text("依實際日均支出加一成緩衝，以相同天數估算。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("旅程回顧")
        .navigationBarTitleDisplayMode(.inline)
    }
}
