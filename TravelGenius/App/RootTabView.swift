//
//  RootTabView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

/// 首次啟動顯示 onboarding，完成後進入主畫面
struct RootGateView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        if hasOnboarded {
            RootTabView()
        } else {
            OnboardingView {
                hasOnboarded = true
            }
        }
    }
}

/// 設定行程後才出現「清單」「Tips」分頁；沒有進行中行程時只有行程頁
struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @Environment(MascotState.self) private var mascot
    @Query private var trips: [Trip]

    @State private var selection: AppTab = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-openPackTab") { return .checklist }
        if arguments.contains("-openTipsTab") || arguments.contains("-showProhibited") || arguments.contains("-showEtiquette") { return .tips }
        if UserDefaults.standard.bool(forKey: "startOnPackingTab") {
            UserDefaults.standard.removeObject(forKey: "startOnPackingTab")
            return .checklist
        }
        return .trips
    }()

    private var activeTrip: Trip? {
        appState.activeTrip(in: trips)
    }

    var body: some View {
        Group {
            if activeTrip != nil {
                TabView(selection: $selection) {
                    TripListView()
                        .tabItem { Label("行程", systemImage: "airplane") }
                        .tag(AppTab.trips)

                    PackingRootView()
                        .tabItem { Label("清單", systemImage: "checklist") }
                        .tag(AppTab.checklist)

                    TipsRootView()
                        .tabItem { Label("Tips", systemImage: "lightbulb") }
                        .tag(AppTab.tips)
                }
            } else {
                TripListView()
            }
        }
        .overlay {
            FloatingMascotDock()
        }
        .onAppear(perform: refreshMascotMessage)
        .onChange(of: selection) { _, _ in refreshMascotMessage() }
        .onChange(of: appState.requestedTab) { _, requested in
            guard let requested else { return }
            selection = requested
            appState.requestedTab = nil
        }
        .onChange(of: activeTrip?.id) { _, _ in refreshMascotMessage() }
        .onChange(of: scenePhase) { _, newPhase in
            // 離開前景時更新主畫面小工具
            if newPhase != .active {
                WidgetSync.update(trip: activeTrip)
            }
        }
    }

    /// 依目前行程狀態更新小旅犬的預設情境訊息（不強制展開）
    private func refreshMascotMessage() {
        guard let trip = activeTrip else {
            mascot.message = "先建立一個行程，我就開始幫你倒數、盯行李！"
            mascot.expression = .normal
            return
        }
        let unpacked = (trip.packingItems ?? []).filter { !$0.isPacked }.count
        let contextual = MascotMessenger.message(for: trip, unpackedCount: unpacked, weather: nil)
        mascot.message = contextual.text
        mascot.expression = contextual.expression
    }
}
