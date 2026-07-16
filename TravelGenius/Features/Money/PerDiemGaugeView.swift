//
//  PerDiemGaugeView.swift
//  TravelGenius
//

import SwiftUI

/// 津貼儀表：今日各類別相對每日津貼標準的使用率
struct PerDiemGaugeView: View {
    let trip: Trip

    var body: some View {
        if let result = PerDiemService.usage(for: trip) {
            let warningActive = (result.worst?.ratio ?? 0) >= 0.8
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("津貼儀表")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("每日標準・\(result.standard.currencyCode)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                HStack {
                    ForEach(result.usages) { usage in
                        gauge(for: usage)
                            .frame(maxWidth: .infinity)
                    }
                }

                if let worst = result.worst, worst.ratio >= 0.8 {
                    Label(
                        worst.ratio >= 1
                            ? "「\(worst.category.label)」已超過今日津貼上限"
                            : "「\(worst.category.label)」接近今日津貼上限",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(worst.ratio >= 1 ? .red : .orange)
                }

                Text("津貼標準為內建預設值，請依公司差旅政策調整。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .sensoryFeedback(.warning, trigger: warningActive) { old, new in !old && new }
        }
    }

    private func gauge(for usage: PerDiemService.CategoryUsage) -> some View {
        let tint: Color = usage.ratio >= 1 ? .red : usage.ratio >= 0.8 ? .orange : .green
        return VStack(spacing: 6) {
            Gauge(value: min(usage.ratio, 1)) {
                Image(systemName: usage.category.symbolName)
            } currentValueLabel: {
                Text(usage.ratio, format: .percent.precision(.fractionLength(0)))
                    .font(.caption2)
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(tint)
            Text(usage.category.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(usage.category.label)津貼已使用 \(Int(usage.ratio * 100))%")
    }
}
