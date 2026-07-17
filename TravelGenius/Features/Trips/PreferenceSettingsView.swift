//
//  PreferenceSettingsView.swift
//  TravelGenius
//
//  五項使用者偏好（含行李偏好）；變更後重新合併目前行程的清單，個人化立即可見。
//  embedded = true 時作為分頁使用（即時儲存、無取消/儲存鈕）。
//

import SwiftUI
import SwiftData

struct PreferenceSettingsView: View {
    var embedded = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Query private var trips: [Trip]

    @State private var preferences = UserPreferences.load()

    var body: some View {
        NavigationStack {
            Form {
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
                    Text("偏好會直接影響清單內容（例如輕便會略過加分項目、家庭出遊會加入兒童用品）\(embedded ? "，變更立即生效。" : "，儲存後立即重新客製目前行程的清單。")")
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
        if let trip = appState.activeTrip(in: trips),
           !(trip.packingItems ?? []).isEmpty {
            PackingListGenerator.sync(trip: trip, context: context, preferences: preferences)
        }
    }
}
