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
        case completed = "已完成"

        var id: String { rawValue }

        var status: TripLifecycleStatus {
            switch self {
            case .upcoming: .upcoming
            case .active: .inProgress
            case .completed: .completed
            }
        }
    }

    private enum SheetDestination: Identifiable {
        case create

        var id: String {
            switch self {
            case .create: "create"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var navigationPath: [Trip] = []
    @State private var scope: Scope = .upcoming
    @State private var presentedSheet: SheetDestination?
    @State private var pendingDeletion: Trip?
    @State private var pendingCompletion: Trip?
    @State private var lifecycleFeedback = false
    @State private var handledDebugDestination = false

    private var scopedTrips: [Trip] {
        trips
            .filter { $0.lifecycleStatus == scope.status }
            .sorted { lhs, rhs in
                scope == .completed ? lhs.endDate > rhs.endDate : lhs.startDate < rhs.startDate
            }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if trips.isEmpty {
                    EmptyTripView { presentedSheet = .create }
                } else {
                    tripList
                }
            }
            .navigationTitle("行程")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("新增行程", systemImage: "plus") {
                        presentedSheet = .create
                    }
                }
            }
            .sheet(item: $presentedSheet) { destination in
                switch destination {
                case .create:
                    TripCreationFlowView()
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
            .confirmationDialog(
                "要將「\(pendingCompletion?.name ?? "這趟行程")」標記為已完成嗎？",
                isPresented: Binding(
                    get: { pendingCompletion != nil },
                    set: { if !$0 { pendingCompletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("完成行程") { completePendingTrip() }
                Button("取消", role: .cancel) { pendingCompletion = nil }
            }
            .sensoryFeedback(.success, trigger: lifecycleFeedback)
            .onAppear {
                if appState.consumeCreateTripLaunchRequest() {
                    presentedSheet = .create
                }
                openDebugDestinationIfNeeded()
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
                        VStack(spacing: 10) {
                            NavigationLink(value: trip) {
                                TripRow(trip: trip)
                            }
                            lifecyclePrompt(for: trip)
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
        case .completed: "還沒有已完成的行程"
        }
    }

    private var emptyDescription: String {
        switch scope {
        case .upcoming: "點右上角＋建立下一趟旅程。"
        case .active: "到達出發日後，從提示按下「開始行程」。"
        case .completed: "完成行程後會保留在這裡。"
        }
    }

    @ViewBuilder
    private func lifecyclePrompt(for trip: Trip) -> some View {
        if trip.shouldPromptToStart() {
            promptRow(
                title: "今天出發了嗎？",
                detail: "按下後移到「進行中」",
                symbol: "airplane.departure",
                actionTitle: "開始行程"
            ) {
                trip.start()
                appState.setActive(trip)
                WidgetSync.update(trip: trip)
                lifecycleFeedback.toggle()
            }
        } else if trip.shouldPromptToComplete() {
            promptRow(
                title: "旅程結束了嗎？",
                detail: "確認後移到「已完成」",
                symbol: "flag.checkered",
                actionTitle: "完成行程"
            ) {
                pendingCompletion = trip
            }
        }
    }

    private func promptRow(
        title: String,
        detail: String,
        symbol: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func deletePendingTrip() {
        guard let trip = pendingDeletion else { return }
        if appState.activeTripID == trip.id.uuidString {
            appState.setActive(nil)
        }
        context.delete(trip)
        pendingDeletion = nil
    }

    private func completePendingTrip() {
        guard let trip = pendingCompletion else { return }
        trip.complete()
        if appState.activeTripID == trip.id.uuidString {
            appState.setActive(nil)
        }
        WidgetSync.update(trip: appState.activeTrip(in: trips))
        pendingCompletion = nil
        lifecycleFeedback.toggle()
    }

    private func openDebugDestinationIfNeeded() {
        guard !handledDebugDestination else { return }
        handledDebugDestination = true
        let arguments = ProcessInfo.processInfo.arguments
        let shouldOpenDetail = arguments.contains("-openPackTab")
            || arguments.contains("-openTipsTab")
            || arguments.contains("-showProhibited")
            || arguments.contains("-showEtiquette")
        guard shouldOpenDetail,
              let trip = appState.activeTrip(in: trips) ?? trips.first else { return }
        navigationPath = [trip]
    }
}

private struct TripRow: View {
    let trip: Trip

    private var packedSummary: String {
        let items = trip.packingItems ?? []
        guard !items.isEmpty else { return "尚未產生清單" }
        return "行李 \(items.filter(\.isPacked).count)/\(items.count)"
    }

    private var statusTint: Color {
        switch trip.lifecycleStatus {
        case .upcoming: .blue
        case .inProgress: .green
        case .completed: .secondary
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
                Text(trip.name)
                    .font(.headline)
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
