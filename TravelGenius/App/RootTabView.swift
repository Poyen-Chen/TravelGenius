//
//  RootTabView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

/// 首次啟動顯示 onboarding，完成後進入主畫面
struct RootGateView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage("hasSeenFirstLaunchGuide") private var hasSeenFirstLaunchGuide = false

    var body: some View {
        if hasOnboarded {
            RootTabView()
                .fullScreenCover(
                    isPresented: Binding(
                        get: { !hasSeenFirstLaunchGuide },
                        set: { isPresented in
                            if !isPresented { hasSeenFirstLaunchGuide = true }
                        }
                    )
                ) {
                    FirstLaunchGuideView {
                        hasSeenFirstLaunchGuide = true
                    }
                }
        } else {
            OnboardingView {
                hasOnboarded = true
            }
        }
    }
}

/// 主畫面固定為「行程」「設定」兩個頂層分頁。
struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @Environment(MascotState.self) private var mascot
    @Query private var trips: [Trip]

    @State private var selection: AppTab = ProcessInfo.processInfo.arguments.contains("-openSettingsTab") ? .settings : .trips

    private var activeTrip: Trip? {
        appState.activeTrip(in: trips)
    }

    var body: some View {
        TabView(selection: $selection) {
            TripListView()
                .tabItem { Label("行程", systemImage: "airplane") }
                .tag(AppTab.trips)

            PreferenceSettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .overlay {
            FloatingMascotDock()
        }
        .onAppear(perform: refreshMascotMessage)
        .onChange(of: selection) { _, _ in refreshMascotMessage() }
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
