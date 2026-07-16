//
//  PackingRootView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

struct PackingRootView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var showingTripForm = false

    var body: some View {
        NavigationStack {
            Group {
                if let trip = appState.activeTrip(in: trips) {
                    PackingListView(trip: trip)
                        .navigationTitle("行李")
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    EmptyTripView { showingTripForm = true }
                        .navigationTitle("行李")
                }
            }
            .sheet(isPresented: $showingTripForm) { TripFormView() }
        }
    }
}
