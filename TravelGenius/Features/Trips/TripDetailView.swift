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

    private var country: Country? {
        StaticDataStore.shared.country(code: trip.countryCode)
    }

    private var originCountry: Country? {
        StaticDataStore.shared.country(code: trip.originCountryCode)
    }

    private var isActive: Bool {
        appState.activeTrip(in: trips) === trip
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: trip.lifecycleStatus.symbolName)
                        .font(.title2)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(trip.lifecycleStatus.label)
                            .font(.headline)
                        Text(isActive ? "目前 App 使用這趟行程的清單與 Tips" : "可設為目前行程後從底部分頁快速查看")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            Section("基本資料") {
                LabeledContent("出發地") {
                    Text("\(originCountry?.flagEmoji ?? "") \(originCountry?.nameZh ?? trip.originCountryCode)\(trip.originCity.isEmpty ? "" : "・\(trip.originCity)")")
                }
                LabeledContent("目的地") {
                    Text("\(country?.flagEmoji ?? "") \(country?.nameZh ?? trip.countryCode)\(trip.city.isEmpty ? "" : "・\(trip.city)")")
                }
                LabeledContent("日期") {
                    Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                }
                LabeledContent("天數") {
                    Text("\(trip.totalDays) 天")
                }
            }

            Section("行前準備") {
                NavigationLink {
                    PackingListView(trip: trip)
                        .navigationTitle("清單・\(trip.name)")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    DetailDestinationRow(
                        title: "行李 Checklist",
                        subtitle: packingProgressText,
                        symbol: "checklist",
                        tint: .blue
                    )
                }

                NavigationLink {
                    TipsRootView(trip: trip, embedded: true)
                } label: {
                    DetailDestinationRow(
                        title: "海關 Tips",
                        subtitle: "查物品、看海關與城市文化提醒",
                        symbol: "lightbulb.fill",
                        tint: .orange
                    )
                }

                NavigationLink {
                    TripRegulationsView(trip: trip)
                } label: {
                    DetailDestinationRow(
                        title: "出入境管制物品",
                        subtitle: trip.hasReviewedTravelRules ? "建立行程時已閱讀" : "尚未確認閱讀",
                        symbol: "checkmark.shield.fill",
                        tint: .red
                    )
                }
            }

            Section {
                if !trip.isClosed {
                    if isActive {
                        Button("開始打包這趟行程", systemImage: "checklist") {
                            appState.open(.checklist, for: trip)
                        }
                    } else {
                        Button("設為目前行程", systemImage: "checkmark.circle") {
                            appState.setActive(trip)
                        }
                    }
                }
                Button("編輯行程", systemImage: "pencil") { showingEdit = true }
                if trip.isClosed {
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
            "結束行程後會從「目前行程」移除，之後仍可重新開啟。",
            isPresented: $confirmClose,
            titleVisibility: .visible
        ) {
            Button("結束行程", role: .destructive) {
                trip.isClosed = true
            }
        }
    }

    private var packingProgressText: String {
        let items = trip.packingItems ?? []
        guard !items.isEmpty else { return "尚未產生清單" }
        return "已打包 \(items.filter(\.isPacked).count)／\(items.count) 項"
    }
}

private struct DetailDestinationRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

private struct TripRegulationsView: View {
    let trip: Trip

    var body: some View {
        List {
            ProhibitedSections(trip: trip, mode: .customs)
            ProhibitedSections(trip: trip, mode: .aviation)
        }
        .navigationTitle("管制物品")
        .navigationBarTitleDisplayMode(.inline)
    }
}
