//
//  TripListView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var showingForm = false

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    EmptyTripView { showingForm = true }
                } else {
                    tripList
                }
            }
            .navigationTitle("行程")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("新增行程", systemImage: "plus") { showingForm = true }
                }
            }
            .sheet(isPresented: $showingForm) { TripFormView() }
            .navigationDestination(for: Trip.self) { TripDetailView(trip: $0) }
        }
    }

    private var tripList: some View {
        List {
            ForEach(trips) { trip in
                NavigationLink(value: trip) {
                    TripRow(trip: trip, isActive: appState.activeTrip(in: trips) === trip)
                }
            }
            .onDelete(perform: delete)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let trip = trips[index]
            if appState.activeTripID == trip.id.uuidString {
                appState.setActive(nil)
            }
            context.delete(trip)
        }
    }
}

private struct TripRow: View {
    let trip: Trip
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(StaticDataStore.shared.country(code: trip.countryCode)?.flagEmoji ?? "🌍")
                .font(.title)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(trip.name)
                        .font(.headline)
                    if trip.isClosed {
                        Text("已結束")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                MoneyText(amount: trip.totalBudget, currencyCode: trip.homeCurrencyCode)
                    .font(.subheadline)
                if isActive {
                    Label("目前行程", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
