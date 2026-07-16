//
//  DailySpendChart.swift
//  TravelGenius
//

import SwiftUI
import Charts

struct DailySpendChart: View {
    let series: [RunwayCalculator.DayTotal]
    let dailyBudget: Double

    var body: some View {
        Chart {
            ForEach(series) { day in
                BarMark(
                    x: .value("日期", day.day, unit: .day),
                    y: .value("支出", day.total)
                )
                .foregroundStyle(.tint)
                .cornerRadius(3)
            }
            if dailyBudget > 0 {
                RuleMark(y: .value("每日預算", dailyBudget))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("每日預算")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day(), centered: true)
            }
        }
        .frame(height: 170)
        .accessibilityLabel("每日支出長條圖，含每日預算參考線")
    }
}
