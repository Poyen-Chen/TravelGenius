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

/// 階段式分頁：建行程前 =「行程＋偏好設定」；有進行中行程後 =「清單＋Tips」。
/// 旅行階段仍可從清單頁工具列回到行程管理與偏好設定（sheet）。
struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @Environment(MascotState.self) private var mascot
    @Query private var trips: [Trip]

    /// Onboarding 剛完成：先停留在行程階段，直到明確建立／選定行程（setActive 時解除）
    @AppStorage("needsTripStageAfterOnboarding") private var needsTripStage = false

    @State private var selection: AppTab = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-openPackTab") { return .checklist }
        if arguments.contains("-openTipsTab") || arguments.contains("-showProhibited") || arguments.contains("-showEtiquette") { return .tips }
        if UserDefaults.standard.bool(forKey: "needsTripStageAfterOnboarding") { return .trips }
        if UserDefaults.standard.bool(forKey: "startOnPackingTab") {
            UserDefaults.standard.removeObject(forKey: "startOnPackingTab")
            return .checklist
        }
        return .trips
    }()

    private var activeTrip: Trip? {
        appState.activeTrip(in: trips)
    }

    private var hasActiveTrip: Bool { activeTrip != nil && !needsTripStage }

    var body: some View {
        Group {
            if hasActiveTrip {
                TabView(selection: $selection) {
                    PackingRootView()
                        .tabItem { Label("清單", systemImage: "checklist") }
                        .tag(AppTab.checklist)

                    TipsRootView()
                        .tabItem { Label("Tips", systemImage: "lightbulb") }
                        .tag(AppTab.tips)
                }
            } else {
                TabView(selection: $selection) {
                    TripListView()
                        .tabItem { Label("行程", systemImage: "airplane") }
                        .tag(AppTab.trips)

                    PreferenceSettingsView(embedded: true)
                        .tabItem { Label("偏好設定", systemImage: "person.crop.circle") }
                        .tag(AppTab.preferences)
                }
            }
        }
        .overlay {
            FloatingMascotDock()
        }
        .onAppear {
            clampSelectionToStage()
            refreshMascotMessage()
        }
        .onChange(of: selection) { _, _ in refreshMascotMessage() }
        .onChange(of: appState.requestedTab) { _, requested in
            guard let requested else { return }
            selection = requested
            appState.requestedTab = nil
        }
        .onChange(of: activeTrip?.id) { _, _ in
            clampSelectionToStage()
            refreshMascotMessage()
        }
        .onChange(of: needsTripStage) { _, _ in
            clampSelectionToStage()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 離開前景時更新主畫面小工具
            if newPhase != .active {
                WidgetSync.update(trip: activeTrip)
            }
        }
    }

    /// 階段切換時把選中分頁夾到該階段可見的分頁
    private func clampSelectionToStage() {
        if hasActiveTrip {
            if selection == .trips || selection == .preferences {
                selection = .checklist
            }
        } else {
            if selection == .checklist || selection == .tips {
                selection = .trips
            }
        }
    }

    /// 依目前行程狀態更新小史萊姆的預設情境訊息（不強制展開）
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
