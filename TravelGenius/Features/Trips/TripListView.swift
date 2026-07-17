//
//  TripListView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

struct TripListView: View {
    private enum Scope: String, CaseIterable, Identifiable {
        case upcoming = "未開始"
        case active = "進行中"
        case history = "歷史"

        var id: String { rawValue }

        var status: TripLifecycleStatus {
            switch self {
            case .upcoming: .upcoming
            case .active: .inProgress
            case .history: .history
            }
        }
    }

    private enum SheetDestination: Identifiable {
        case create
        case resume(Trip)
        case preferences

        var id: String {
            switch self {
            case .create: "create"
            case .resume(let trip): "resume-\(trip.id.uuidString)"
            case .preferences: "preferences"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var scope: Scope = .upcoming
    @State private var presentedSheet: SheetDestination?
    @State private var pendingDeletion: Trip?

    private var drafts: [Trip] {
        trips.filter { $0.lifecycleStatus == .draft }
    }

    private var scopedTrips: [Trip] {
        trips
            .filter { $0.lifecycleStatus == scope.status }
            .sorted { lhs, rhs in
                scope == .history ? lhs.endDate > rhs.endDate : lhs.startDate < rhs.startDate
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    EmptyTripView { presentedSheet = .create }
                } else {
                    tripList
                }
            }
            .navigationTitle("行程")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("基本設定", systemImage: "person.crop.circle") {
                        presentedSheet = .preferences
                    }
                    Button("新增行程", systemImage: "plus") {
                        presentedSheet = .create
                    }
                }
            }
            .sheet(item: $presentedSheet) { destination in
                switch destination {
                case .create:
                    TripCreationFlowView()
                case .resume(let trip):
                    TripCreationFlowView(trip: trip)
                case .preferences:
                    PreferenceSettingsView()
                }
            }
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
            .confirmationDialog(
                "確定刪除「\(pendingDeletion?.name ?? "這個行程")」？清單資料也會一起刪除。",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("刪除行程", role: .destructive, action: deletePendingTrip)
                Button("取消", role: .cancel) { pendingDeletion = nil }
            }
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-openCreateTrip") {
                    presentedSheet = .create
                }
            }
        }
    }

    private var tripList: some View {
        List {
            Section {
                Picker("行程狀態", selection: $scope) {
                    ForEach(Scope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            if !drafts.isEmpty {
                Section("草稿") {
                    ForEach(drafts) { trip in
                        Button {
                            presentedSheet = .resume(trip)
                        } label: {
                            TripRow(trip: trip, isActive: false)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("刪除", role: .destructive) { pendingDeletion = trip }
                        }
                        .accessibilityHint("繼續建立這個行程")
                    }
                }
            }

            Section(scope.rawValue) {
                if scopedTrips.isEmpty {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: scope.status.symbolName,
                        description: Text(emptyDescription)
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(scopedTrips) { trip in
                        NavigationLink(value: trip) {
                            TripRow(trip: trip, isActive: appState.activeTrip(in: trips) === trip)
                        }
                        .swipeActions {
                            Button("刪除", role: .destructive) { pendingDeletion = trip }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyTitle: String {
        switch scope {
        case .upcoming: "沒有未開始的行程"
        case .active: "目前沒有進行中的行程"
        case .history: "還沒有歷史行程"
        }
    }

    private var emptyDescription: String {
        switch scope {
        case .upcoming: "點右上角＋建立下一趟旅程。"
        case .active: "到達出發日後，行程會自動移到這裡。"
        case .history: "回程日期結束後，行程會保留在這裡。"
        }
    }

    private func deletePendingTrip() {
        guard let trip = pendingDeletion else { return }
        if appState.activeTripID == trip.id.uuidString {
            appState.setActive(nil)
        }
        context.delete(trip)
        pendingDeletion = nil
    }
}

private struct TripRow: View {
    let trip: Trip
    let isActive: Bool

    private var packedSummary: String {
        let items = trip.packingItems ?? []
        guard !items.isEmpty else { return trip.isDraft ? "步驟 \(trip.draftCreationStep)／3" : "尚未產生清單" }
        return "行李 \(items.filter(\.isPacked).count)/\(items.count)"
    }

    private var statusTint: Color {
        switch trip.lifecycleStatus {
        case .draft: .orange
        case .upcoming: .blue
        case .inProgress: .green
        case .history: .secondary
        }
    }

    var body: some View {
        HStack(spacing: PackSmartDesign.Spacing.medium) {
            Image(systemName: trip.lifecycleStatus.symbolName)
                .font(.title3)
                .foregroundStyle(statusTint)
                .frame(width: 36, height: 36)
                .background(statusTint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(trip.name)
                        .font(.headline)
                    if isActive {
                        Text("目前")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                }
                Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(packedSummary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trip.name)，\(trip.lifecycleStatus.label)，\(packedSummary)")
    }
}
