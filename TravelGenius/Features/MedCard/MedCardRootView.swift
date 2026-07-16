//
//  MedCardRootView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

struct MedCardRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var profiles: [MedicalProfile]
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]

    private var activeCountryCode: String? {
        appState.activeTrip(in: trips)?.countryCode
    }

    var body: some View {
        NavigationStack {
            if let profile = profiles.first {
                MedicalProfileView(profile: profile, activeCountryCode: activeCountryCode)
            } else {
                ContentUnavailableView {
                    Label("尚未建立醫療卡", systemImage: "cross.case")
                } description: {
                    Text("記錄血型、過敏與用藥，抵達國外自動翻譯成當地語言，緊急時一頁出示。")
                } actions: {
                    Button("建立醫療卡") {
                        context.insert(MedicalProfile())
                    }
                    .buttonStyle(.borderedProminent)
                }
                .navigationTitle("醫療卡")
            }
        }
    }
}
