//
//  CategoryBreakdownChart.swift
//  TravelGenius
//

import SwiftUI
import Charts

struct CategoryBreakdownChart: View {
    let totals: [(category: ExpenseCategory, total: Double)]
    let currencyCode: String

    private var grandTotal: Double {
        totals.reduce(0) { $0 + $1.total }
    }

    var body: some View {
        VStack(spacing: 12) {
            Chart(totals, id: \.category) { item in
                SectorMark(
                    angle: .value("金額", item.total),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .foregroundStyle(item.category.color.gradient)
                .cornerRadius(3)
            }
            .frame(height: 180)
            .accessibilityLabel("各類別支出圓餅圖")

            VStack(spacing: 8) {
                ForEach(totals, id: \.category) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.category.color)
                            .frame(width: 9, height: 9)
                        Text(item.category.label)
                            .font(.footnote)
                        Spacer()
                        if grandTotal > 0 {
                            Text(item.total / grandTotal, format: .percent.precision(.fractionLength(0)))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        MoneyText(amount: Decimal(item.total), currencyCode: currencyCode)
                            .font(.footnote)
                    }
                }
            }
        }
    }
}
