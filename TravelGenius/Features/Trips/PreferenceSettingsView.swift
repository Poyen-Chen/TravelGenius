import SwiftUI

struct PreferenceSettingsView: View {
    var onSaved: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.packmonTheme) private var theme
    @State private var preferences = UserPreferences.forNewTrips()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("只為你自己準備。選平常旅行會帶的用品，每趟不必重填。")
                        .foregroundStyle(theme.colors.secondaryText)
                    selectionGroup("我的常用設備", options: PersonalPackingOptions.devices, devices: true)
                    note("共用充電線不會按設備重複增加；產生清單後，再依接頭與功率調整數量。")
                    selectionGroup("我的常備需求", options: PersonalPackingOptions.needs, devices: false)
                    note("藥品由你自行決定品項，不會依年齡推測用藥。其他用品可到「常備清單」加入。")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("你習慣怎麼打包？").font(.headline)
                        ForEach(PackingStyle.allCases) { style in
                            Button { preferences.packingStyle = style } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: preferences.packingStyle == style ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(theme.colors.accent)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(style == .full ? "準備齊全" : style.label).font(.headline)
                                        Text(style.detail).font(.footnote).foregroundStyle(theme.colors.secondaryText)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(16)
                                .background(theme.colors.elevatedSurface, in: RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain)
                             .accessibilityAddTraits(preferences.packingStyle == style ? .isSelected : [])
                        }
                    }
                    Text("輕便最多四套換洗；一般依天數準備；準備齊全另加入備用品。只影響新行程，已建立的清單不會改變。")
                        .font(.footnote).foregroundStyle(theme.colors.secondaryText)
                }.padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                Button("儲存個人需求") { preferences.save(); dismiss(); onSaved?() }
                    .buttonStyle(PackmonPrimaryButtonStyle())
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(theme.colors.canvas)
            }
            .background(theme.colors.canvas)
            .foregroundStyle(theme.colors.text)
            .navigationTitle("個人打包需求")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(theme.colors.secondaryText)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors.elevatedSurface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func selectionGroup(_ title: String, options: [PersonalPackingOptions.Option], devices: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                ForEach(options) { option in
                    let selected = (devices ? preferences.devices : preferences.needs)?.contains(option.id) == true
                    Button {
                        var values = (devices ? preferences.devices : preferences.needs) ?? []
                        if selected { values.removeAll { $0 == option.id } } else { values.append(option.id) }
                        if devices { preferences.devices = values } else { preferences.needs = values }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selected ? "checkmark.square.fill" : "square")
                                .foregroundStyle(theme.colors.accent)
                            Text(option.label).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(14).frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                        .background(selected ? theme.colors.accentSoft : theme.colors.elevatedSurface,
                                    in: RoundedRectangle(cornerRadius: 14))
                        .overlay { RoundedRectangle(cornerRadius: 14).stroke(selected ? theme.colors.accent : theme.colors.separator, lineWidth: 1) }
                    }.buttonStyle(.plain)
                     .accessibilityLabel(option.label)
                     .accessibilityValue(selected ? "已選取" : "未選取")
                     .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}

struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.packmonTheme) private var theme
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(PackmonThemeID.storageKey) private var designThemeRaw = PackmonThemeID.structureC.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section("外觀") {
                    Picker("外觀", selection: $appearanceRaw) {
                        ForEach(AppAppearance.allCases) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .listRowBackground(theme.colors.elevatedSurface)

                Section {
                    ForEach(PackmonThemeID.allCases) { themeID in
                        Button {
                            designThemeRaw = themeID.rawValue
                        } label: {
                            DesignThemeOptionRow(
                                themeID: themeID,
                                isSelected: designThemeRaw == themeID.rawValue
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("設計驗證")
                } footer: {
                    Text("切換後會立即套用。兩個品牌提案都是測試選項，不代表已定案；導航、內容與資料不會跟著改變。")
                }
                .listRowBackground(theme.colors.elevatedSurface)


            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.canvas)
            .navigationTitle("外觀設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

private struct DesignThemeOptionRow: View {
    let themeID: PackmonThemeID
    let isSelected: Bool

    private var colors: PackmonTheme.Colors { themeID.theme.colors }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: -5) {
                Circle().fill(colors.accent)
                Circle().fill(colors.secondaryAccent)
                Circle().fill(colors.canvas)
                    .overlay { Circle().stroke(.secondary.opacity(0.28), lineWidth: 0.5) }
            }
            .frame(width: 54, height: 24)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(themeID.label)
                        .font(.subheadline.weight(.semibold))
                    if themeID.isExperimental {
                        Text("實驗")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(colors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colors.accentSoft, in: Capsule())
                    }
                }
                Text(themeID.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? colors.accent : Color.secondary)
                .imageScale(.large)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
