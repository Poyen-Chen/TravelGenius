//
//  PackSmartDesignSystem.swift
//  TravelGenius
//

import SwiftUI

/// PackSmart 的原生 iOS 設計語彙。
/// 顏色採語意命名並交給系統處理明暗模式；排版全面使用 Dynamic Type。
enum PackSmartDesign {
    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    enum ColorToken {
        static let accent = Color.accentColor
        static let warm = Color.orange
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red
        static let canvas = Color(.systemGroupedBackground)
        static let surface = Color(.secondarySystemGroupedBackground)
        static let elevatedSurface = Color(.systemBackground)
        static let separator = Color(.separator)
    }
}

struct PackSmartCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(PackSmartDesign.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PackSmartDesign.ColorToken.elevatedSurface,
                in: RoundedRectangle(cornerRadius: PackSmartDesign.Radius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PackSmartDesign.Radius.medium, style: .continuous)
                    .stroke(PackSmartDesign.ColorToken.separator.opacity(0.45), lineWidth: 0.5)
            }
    }
}

struct PackSmartPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                PackSmartDesign.ColorToken.accent.opacity(isEnabled ? 1 : 0.45),
                in: RoundedRectangle(cornerRadius: PackSmartDesign.Radius.medium, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.985)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct FlowProgressHeader: View {
    let currentStep: Int
    let totalSteps: Int
    let title: String
    let subtitle: String

    private var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PackSmartDesign.Spacing.small) {
            HStack {
                Text("步驟 \(currentStep)／\(totalSteps)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(.accentColor)
                .accessibilityLabel("建立行程進度")
                .accessibilityValue("第 \(currentStep) 步，共 \(totalSteps) 步")
            Text(title)
                .font(.system(.title, design: .rounded).weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
