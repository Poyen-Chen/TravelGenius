//
//  PackmonDesignSystem.swift
//  TravelGenius
//

import SwiftUI

/// 可在執行期間切換的設計系統版本。
/// 新設計進場時新增一個 case 與對應 token，即可和現行版本並存驗證。
enum PackmonThemeID: String, CaseIterable, Identifiable {
    case current
    case structureC
    case warmCompanion
    case trustBlueCTA

    static let storageKey = "design.theme.structure-c"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .current: "現行設計"
        case .structureC: "結構 C"
        case .warmCompanion: "暖橘陪伴"
        case .trustBlueCTA: "信任藍 CTA"
        }
    }

    var detail: String {
        switch self {
        case .current: "目前上線中的間距、圓角與系統色彩。"
        case .structureC: "Claude Design 結構 C 的陶土橘與暖米色介面。"
        case .warmCompanion: "品牌提案 A：暖橘作主要操作色，強化活力與陪伴感。"
        case .trustBlueCTA: "品牌提案 B：信任藍作主要操作色，暖橘保留品牌識別。"
        }
    }

    var isExperimental: Bool {
        switch self {
        case .warmCompanion, .trustBlueCTA: true
        case .current, .structureC: false
        }
    }

    var theme: PackmonTheme {
        switch self {
        case .current: .current
        case .structureC: .structureC
        case .warmCompanion: .warmCompanion
        case .trustBlueCTA: .trustBlueCTA
        }
    }
}

/// 所有可替換的視覺決策集中在這個 value type。
/// Feature 只讀語意 token，不直接知道目前是哪一套設計。
struct PackmonTheme {
    struct Spacing {
        let xSmall: CGFloat
        let small: CGFloat
        let medium: CGFloat
        let large: CGFloat
        let xLarge: CGFloat
    }

    struct Radius {
        let small: CGFloat
        let medium: CGFloat
        let large: CGFloat
    }

    struct Colors {
        let accent: Color
        let accentSoft: Color
        let secondaryAccent: Color
        let warm: Color
        let success: Color
        let warning: Color
        let danger: Color
        let text: Color
        let secondaryText: Color
        let canvas: Color
        let surface: Color
        let elevatedSurface: Color
        let separator: Color
    }

    let id: PackmonThemeID
    let spacing: Spacing
    let radius: Radius
    let colors: Colors

    static let current = PackmonTheme(
        id: .current,
        spacing: Spacing(xSmall: 4, small: 8, medium: 16, large: 24, xLarge: 32),
        radius: Radius(small: 10, medium: 16, large: 24),
        colors: Colors(
            accent: .accentColor,
            accentSoft: Color.accentColor.opacity(0.12),
            secondaryAccent: .green,
            warm: .orange,
            success: .green,
            warning: .orange,
            danger: .red,
            text: .primary,
            secondaryText: .secondary,
            canvas: Color(uiColor: .systemGroupedBackground),
            surface: Color(uiColor: .secondarySystemGroupedBackground),
            elevatedSurface: Color(uiColor: .systemBackground),
            separator: Color(uiColor: .separator)
        )
    )

    /// Claude Design Artifact「結構 C」實際使用的語意 token。
    static let structureC = PackmonTheme(
        id: .structureC,
        spacing: Spacing(xSmall: 4.4, small: 8.8, medium: 17.6, large: 26.4, xLarge: 35.2),
        radius: Radius(small: 8, medium: 16, large: 28),
        colors: Colors(
            accent: Color(red: 198 / 255, green: 113 / 255, blue: 57 / 255),
            accentSoft: Color(red: 1, green: 242 / 255, blue: 235 / 255),
            secondaryAccent: Color(red: 122 / 255, green: 138 / 255, blue: 94 / 255),
            warm: Color(red: 214 / 255, green: 127 / 255, blue: 72 / 255),
            success: Color(red: 122 / 255, green: 138 / 255, blue: 94 / 255),
            warning: Color(red: 214 / 255, green: 127 / 255, blue: 72 / 255),
            danger: Color(red: 166 / 255, green: 70 / 255, blue: 55 / 255),
            text: Color(red: 32 / 255, green: 30 / 255, blue: 29 / 255),
            secondaryText: Color(red: 100 / 255, green: 92 / 255, blue: 80 / 255),
            canvas: Color(red: 245 / 255, green: 234 / 255, blue: 216 / 255),
            surface: Color(red: 235 / 255, green: 221 / 255, blue: 197 / 255),
            elevatedSurface: Color(red: 249 / 255, green: 244 / 255, blue: 237 / 255),
            separator: Color(red: 32 / 255, green: 30 / 255, blue: 29 / 255).opacity(0.16)
        )
    )

    /// 《UI 與品牌視覺建議》提案 A：暖橘承擔品牌與主要操作角色。
    /// 保留結構 C 的 spacing/radius，讓驗證只比較色彩角色。
    static let warmCompanion = PackmonTheme(
        id: .warmCompanion,
        spacing: structureC.spacing,
        radius: structureC.radius,
        colors: Colors(
            accent: Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255),
            accentSoft: Color(red: 1, green: 237 / 255, blue: 213 / 255),
            secondaryAccent: Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255),
            warm: Color(red: 251 / 255, green: 146 / 255, blue: 60 / 255),
            success: Color(red: 22 / 255, green: 163 / 255, blue: 74 / 255),
            warning: Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255),
            danger: Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255),
            text: Color(red: 154 / 255, green: 52 / 255, blue: 18 / 255),
            secondaryText: Color(red: 124 / 255, green: 45 / 255, blue: 18 / 255).opacity(0.76),
            canvas: Color(red: 1, green: 247 / 255, blue: 237 / 255),
            surface: Color(red: 1, green: 237 / 255, blue: 213 / 255),
            elevatedSurface: .white,
            separator: Color(red: 154 / 255, green: 52 / 255, blue: 18 / 255).opacity(0.16)
        )
    )

    /// 《UI 與品牌視覺建議》提案 B：信任藍承擔主要 CTA，暖橘退為品牌強調色。
    static let trustBlueCTA = PackmonTheme(
        id: .trustBlueCTA,
        spacing: structureC.spacing,
        radius: structureC.radius,
        colors: Colors(
            accent: Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255),
            accentSoft: Color(red: 239 / 255, green: 246 / 255, blue: 1),
            secondaryAccent: Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255),
            warm: Color(red: 251 / 255, green: 146 / 255, blue: 60 / 255),
            success: Color(red: 22 / 255, green: 163 / 255, blue: 74 / 255),
            warning: Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255),
            danger: Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255),
            text: Color(red: 67 / 255, green: 20 / 255, blue: 7 / 255),
            secondaryText: Color(red: 124 / 255, green: 45 / 255, blue: 18 / 255).opacity(0.76),
            canvas: Color(red: 1, green: 247 / 255, blue: 237 / 255),
            surface: Color(red: 1, green: 237 / 255, blue: 213 / 255),
            elevatedSurface: .white,
            separator: Color(red: 154 / 255, green: 52 / 255, blue: 18 / 255).opacity(0.16)
        )
    )
}

private struct PackmonThemeKey: EnvironmentKey {
    static let defaultValue = PackmonTheme.current
}

extension EnvironmentValues {
    var packmonTheme: PackmonTheme {
        get { self[PackmonThemeKey.self] }
        set { self[PackmonThemeKey.self] = newValue }
    }
}

struct PackmonCard<Content: View>: View {
    @Environment(\.packmonTheme) private var theme
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(theme.spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                theme.colors.elevatedSurface,
                in: RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous)
                    .stroke(theme.colors.separator.opacity(0.45), lineWidth: 0.5)
            }
    }
}

/// 結構 C 中重複出現的輕量白卡列。
struct PackmonRowCard<Content: View>: View {
    @Environment(\.packmonTheme) private var theme
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, theme.spacing.medium)
            .padding(.vertical, theme.spacing.small + 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                theme.colors.elevatedSurface,
                in: RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous)
                    .stroke(theme.colors.separator, lineWidth: 0.75)
            }
    }
}

struct PackmonStatusPill: View {
    let title: String
    var tint: Color? = nil

    @Environment(\.packmonTheme) private var theme

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint ?? theme.colors.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background((tint ?? theme.colors.accent).opacity(0.12), in: Capsule())
    }
}

struct PackmonPrimaryButtonStyle: ButtonStyle {
    @Environment(\.packmonTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                theme.colors.accent.opacity(isEnabled ? 1 : 0.45),
                in: RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous)
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

    @Environment(\.packmonTheme) private var theme

    private var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            HStack {
                Text("步驟 \(currentStep)／\(totalSteps)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.accent)
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(theme.colors.accent)
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
