//
//  PreferenceSettingsView.swift
//  TravelGenius
//
//  修改四項使用者偏好；儲存後重新合併目前行程的清單，個人化立即可見。
//

import SwiftUI
import SwiftData

struct PreferenceSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var trips: [Trip]

    @State private var preferences = UserPreferences.load()
    @State private var saveFeedback = false

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
                } header: {
                    Text("基本資料")
                } footer: {
                    Text("偏好會直接影響清單內容（例如家庭出遊會加入兒童用品），儲存後立即重新客製目前行程的清單。")
                }

                Section {
                    Button("儲存設定", systemImage: "checkmark.circle.fill") {
                        save()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.headline)
                }
            }
            .navigationTitle("設定")
            .sensoryFeedback(.success, trigger: saveFeedback)
        }
    }

    private func save() {
        preferences.save()
        if let trip = appState.activeTrip(in: trips),
           !(trip.packingItems ?? []).isEmpty {
            PackingListGenerator.sync(trip: trip, context: context, preferences: preferences)
        }
        saveFeedback.toggle()
    }
}
