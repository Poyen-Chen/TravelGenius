//
//  MoneyRootView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

struct MoneyRootView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var showingTripForm = false

    private var openTrips: [Trip] {
        trips.filter { !$0.isClosed }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let trip = appState.activeTrip(in: trips) {
                    RunwayDashboardView(trip: trip)
                        .navigationTitle(trip.name)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            if openTrips.count > 1 {
                                ToolbarItem(placement: .primaryAction) {
                                    tripSwitcher(current: trip)
                                }
                            }
                        }
                } else {
                    EmptyTripView { showingTripForm = true }
                        .navigationTitle("記帳")
                }
            }
            .sheet(isPresented: $showingTripForm) { TripFormView() }
        }
    }

    private func tripSwitcher(current: Trip) -> some View {
        Menu {
            ForEach(openTrips) { trip in
                Button {
                    appState.setActive(trip)
                } label: {
                    if trip === current {
                        Label(trip.name, systemImage: "checkmark")
                    } else {
                        Text(trip.name)
                    }
                }
            }
        } label: {
            Label("切換行程", systemImage: "arrow.left.arrow.right")
        }
    }
}
