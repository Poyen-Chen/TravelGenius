//
//  PackingRootView.swift
//  TravelGenius
//
//  清單分頁：旅行階段的主頁。行程管理與偏好設定以 sheet 形式從工具列進入
//  （階段式分頁下，底部只有「清單」與「Tips」）。
//

import SwiftUI
import SwiftData

struct PackingRootView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var showingTrips = false
    @State private var showingPreferences = false

    var body: some View {
        NavigationStack {
            if let trip = appState.activeTrip(in: trips) {
                PackingListView(trip: trip)
                    .navigationTitle("清單・\(trip.name)")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarLeading) {
                            Button("行程", systemImage: "airplane") { showingTrips = true }
                            Button("偏好設定", systemImage: "person.crop.circle") { showingPreferences = true }
                        }
                    }
                    .sheet(isPresented: $showingTrips) {
                        TripListView()
                    }
                    .sheet(isPresented: $showingPreferences) {
                        PreferenceSettingsView()
                    }
            } else {
                ContentUnavailableView("尚無行程", systemImage: "checklist", description: Text("建立行程後，這裡會出現你的專屬打包清單。"))
                    .navigationTitle("清單")
            }
        }
    }
}
