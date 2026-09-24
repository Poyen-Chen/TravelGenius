//
//  PreferenceSettingsView.swift
//  TravelGenius
//
//  五項使用者偏好（含行李偏好）；僅供新行程使用，既有行程保留建立時設定。
//  embedded = true 時作為分頁使用（即時儲存、無取消/儲存鈕）。
//

import SwiftUI
import SwiftData

struct PreferenceSettingsView: View {
    var embedded = false

    @Environment(\.dismiss) private var dismiss

    @State private var preferences = UserPreferences.load()
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

                Section {
                    Picker("年齡層", selection: $preferences.ageBand) {
                        ForEach(AgeBand.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("性別", selection: $preferences.gender) {
                        ForEach(GenderPreference.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("同行組成", selection: $preferences.party) {
                        ForEach(TravelParty.allCases) { Text("\($0.emoji) \($0.label)").tag($0) }
                    }
                    Picker("旅行經驗", selection: $preferences.experience) {
                        ForEach(TravelExperience.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section {
                    Picker("行李偏好", selection: $preferences.packingStyle) {
                        ForEach(PackingStyle.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(preferences.packingStyle.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("行李偏好")
                } footer: {
                    Text("這些設定只套用到之後建立的新行程。已建立的行程不因這裡的變更重新計算。舊版行程沒有歷史設定時，會以升級當下的設定補存一次。")
                }
            }
            .navigationTitle("偏好設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("儲存", action: saveAndSync)
                    }
                }
            }
            .onChange(of: preferences.ageBand) { autoSaveIfEmbedded() }
            .onChange(of: preferences.gender) { autoSaveIfEmbedded() }
            .onChange(of: preferences.party) { autoSaveIfEmbedded() }
            .onChange(of: preferences.experience) { autoSaveIfEmbedded() }
            .onChange(of: preferences.packingStyle) { autoSaveIfEmbedded() }
        }
    }

    private func autoSaveIfEmbedded() {
        guard embedded else { return }
        applyPreferences()
    }

    private func saveAndSync() {
        applyPreferences()
        dismiss()
    }

    private func applyPreferences() {
        preferences.save()
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
