//
//  PackingRootView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

struct PackingRootView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]

    var body: some View {
        NavigationStack {
            if let trip = appState.activeTrip(in: trips) {
                PackingListView(trip: trip)
                    .navigationTitle("清單・\(trip.name)")
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView("尚無行程", systemImage: "checklist", description: Text("建立行程後，這裡會出現你的專屬打包清單。"))
                    .navigationTitle("清單")
            }
        }
    }
}
