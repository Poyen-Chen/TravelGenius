//
//  TripDetailView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var trips: [Trip]
    let trip: Trip

    @State private var showingEdit = false
    @State private var confirmClose = false
    @State private var showRetrospective = false

    private var country: Country? {
        StaticDataStore.shared.country(code: trip.countryCode)
    }

    private var isActive: Bool {
        appState.activeTrip(in: trips) === trip
    }

    var body: some View {
        List {
            Section("基本資料") {
                LabeledContent("目的地") {
                    Text("\(country?.flagEmoji ?? "") \(country?.nameZh ?? trip.countryCode)\(trip.city.isEmpty ? "" : "・\(trip.city)")")
                }
                LabeledContent("日期") {
                    Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                }
                LabeledContent("天數") {
                    Text("\(trip.totalDays) 天")
                }
                LabeledContent("型態") {
                    Text(trip.tripType.label)
                }
            }

            Section("預算與支出") {
                LabeledContent("總預算") {
                    MoneyText(amount: trip.totalBudget, currencyCode: trip.homeCurrencyCode)
                }
                LabeledContent("已花費") {
                    MoneyText(amount: trip.spentHome, currencyCode: trip.homeCurrencyCode)
                }
                LabeledContent("剩餘") {
                    MoneyText(amount: trip.totalBudget - trip.spentHome, currencyCode: trip.homeCurrencyCode)
                        .foregroundStyle(trip.totalBudget - trip.spentHome < 0 ? .red : .primary)
                }
                NavigationLink("全部支出") {
                    ExpenseListView(trip: trip)
                }
            }

            Section {
                if !trip.isClosed && !isActive {
                    Button("設為目前行程", systemImage: "checkmark.circle") {
                        appState.setActive(trip)
                    }
                }
                Button("編輯行程", systemImage: "pencil") { showingEdit = true }
                if trip.isClosed {
                    NavigationLink {
                        TripRetrospectiveView(trip: trip)
                    } label: {
                        Label("旅程回顧", systemImage: "chart.bar.doc.horizontal")
                    }
                    Button("重新開啟行程", systemImage: "arrow.uturn.backward") {
                        trip.isClosed = false
                    }
                } else {
                    Button("結束行程", systemImage: "flag.checkered", role: .destructive) {
                        confirmClose = true
                    }
                }
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEdit) { TripFormView(trip: trip) }
        .confirmationDialog(
            "結束行程後將產生旅程回顧，之後仍可重新開啟。",
            isPresented: $confirmClose,
            titleVisibility: .visible
        ) {
            Button("結束行程", role: .destructive) {
                trip.isClosed = true
                showRetrospective = true
            }
        }
        .navigationDestination(isPresented: $showRetrospective) {
            TripRetrospectiveView(trip: trip)
        }
    }
}
