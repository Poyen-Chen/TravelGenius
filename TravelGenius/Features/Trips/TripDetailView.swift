//
//  TripDetailView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

struct TripDetailView: View {
    private enum DetailTab: String, CaseIterable, Identifiable {
        case information = "行程資訊"
        case checklist = "Checklist"
        case tips = "Tips"

        var id: String { rawValue }
    }

    @Environment(AppState.self) private var appState
    @Query private var trips: [Trip]
    let trip: Trip

    @State private var selectedTab: DetailTab
    @State private var showingEdit = false
    @State private var confirmComplete = false
    @State private var lifecycleFeedback = false

    init(trip: Trip) {
        self.trip = trip
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-openPackTab") {
            _selectedTab = State(initialValue: .checklist)
        } else if arguments.contains("-openTipsTab") || arguments.contains("-showProhibited") || arguments.contains("-showEtiquette") {
            _selectedTab = State(initialValue: .tips)
        } else {
            _selectedTab = State(initialValue: .information)
        }
    }

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
        VStack(spacing: 0) {
            Picker("行程內容", selection: $selectedTab) {
                ForEach(DetailTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)

            Group {
                switch selectedTab {
                case .information:
                    informationList
                case .checklist:
                    PackingListView(trip: trip)
                case .tips:
                    TipsRootView(trip: trip, embedded: true)
                }
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEdit) { TripFormView(trip: trip) }
        .confirmationDialog(
            "要將「\(trip.name)」標記為已完成嗎？",
            isPresented: $confirmComplete,
            titleVisibility: .visible
        ) {
            Button("完成行程") { completeTrip() }
            Button("取消", role: .cancel) {}
        }
        .sensoryFeedback(.success, trigger: lifecycleFeedback)
    }

    private var informationList: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: trip.lifecycleStatus.symbolName)
                        .font(.title2)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(trip.lifecycleStatus.label)
                            .font(.headline)
                        Text(statusDescription)
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
                LabeledContent("打包進度") {
                    Text(packingProgressText)
                }
            }

            Section("行程操作") {
                switch trip.lifecycleStatus {
                case .upcoming:
                    Button("開始行程", systemImage: "airplane.departure") {
                        trip.start()
                        appState.setActive(trip)
                        WidgetSync.update(trip: trip)
                        lifecycleFeedback.toggle()
                    }
                case .inProgress:
                    Button("完成行程", systemImage: "flag.checkered") {
                        confirmComplete = true
                    }
                case .completed:
                    Button("重新開啟行程", systemImage: "arrow.uturn.backward") {
                        trip.reopen()
                        appState.setActive(trip)
                        WidgetSync.update(trip: trip)
                        lifecycleFeedback.toggle()
                    }
                }
                Button("編輯行程", systemImage: "pencil") { showingEdit = true }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var statusDescription: String {
        switch trip.lifecycleStatus {
        case .upcoming:
            trip.shouldPromptToStart() ? "已到出發日，可以開始行程。" : "等待出發；到出發日會在列表顯示快捷提示。"
        case .inProgress:
            trip.shouldPromptToComplete() ? "已到回程日，可以完成行程。" : "行程進行中。"
        case .completed:
            "行程已完成，清單與 Tips 仍可查看。"
        }
    }

    private var packingProgressText: String {
        let items = trip.packingItems ?? []
        guard !items.isEmpty else { return "尚未產生清單" }
        return "已打包 \(items.filter(\.isPacked).count)／\(items.count) 項"
    }

    private func completeTrip() {
        trip.complete()
        if isActive { appState.setActive(nil) }
        WidgetSync.update(trip: appState.activeTrip(in: trips))
        lifecycleFeedback.toggle()
    }
}
