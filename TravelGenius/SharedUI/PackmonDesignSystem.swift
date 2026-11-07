//
//  PackmonDesignSystem.swift
//  TravelGenius
//

import SwiftUI

/// App 只保留結構 C 一套設計；淺色（米色）與深色由「外觀設定」切換，顏色 token 會跟著變。
enum PackmonThemeID: String, CaseIterable, Identifiable {
    case structureC

    static let storageKey = "design.theme.structure-c"

    var id: String { rawValue }
    var theme: PackmonTheme { .structureC }
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

    /// Claude Design Artifact「結構 C」實際使用的語意 token。
    static let structureC = PackmonTheme(
        id: .structureC,
        spacing: Spacing(xSmall: 4.4, small: 8.8, medium: 17.6, large: 26.4, xLarge: 35.2),
        radius: Radius(small: 8, medium: 16, large: 28),
        colors: Colors(
            accent: Color(light: 0xC67139, dark: 0xDE8A52),
            accentSoft: Color(light: 0xFFF2EB, dark: 0x4A3222),
            secondaryAccent: Color(light: 0x7A8A5E, dark: 0xA3B386),
            warm: Color(light: 0xD67F48, dark: 0xE09A62),
            success: Color(light: 0x7A8A5E, dark: 0xA3B386),
            warning: Color(light: 0xD67F48, dark: 0xE09A62),
            danger: Color(light: 0xA64637, dark: 0xE07A6C),
            text: Color(light: 0x201E1D, dark: 0xF3E9DA),
            secondaryText: Color(light: 0x645C50, dark: 0xB9A890),
            canvas: Color(light: 0xF5EAD8, dark: 0x1E1914),
            surface: Color(light: 0xEBDDC5, dark: 0x2B231B),
            elevatedSurface: Color(light: 0xF9F4ED, dark: 0x352B21),
            separator: Color(light: 0x201E1D, dark: 0xF3E9DA).opacity(0.16)
        )
    )
}

extension Color {
    /// 淺色（米色）與深色各一個值；深色的數值和 PWA 的深色 token 相同。
    init(light: UInt32, dark: UInt32) {
        func color(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? color(dark) : color(light) })
    }
}

private struct PackmonThemeKey: EnvironmentKey {
    static let defaultValue = PackmonTheme.structureC
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
