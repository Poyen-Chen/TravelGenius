//
//  RootTabView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

/// 首次啟動顯示 onboarding，完成後進入主畫面；
/// 外觀設定以 UIWindow 層級套用（sheet／fullScreenCover 不繼承 preferredColorScheme，
/// 視窗覆蓋才能讓所有呈現層一致變色）
struct RootGateView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue

    var body: some View {
        Group {
            if hasOnboarded {
                RootTabView()
            } else {
                OnboardingView {
                    hasOnboarded = true
                }
            }
        }
        .onAppear { applyAppearance() }
        .onChange(of: appearanceRaw) { _, _ in applyAppearance() }
    }

    private func applyAppearance() {
        let appearance = AppAppearance(rawValue: appearanceRaw) ?? .system
        let style: UIUserInterfaceStyle = switch appearance {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
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

    @State private var selection: AppTab = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-openPackTab") { return .checklist }
        if arguments.contains("-openTipsTab") || arguments.contains("-showProhibited") || arguments.contains("-showEtiquette") { return .tips }
        return .trips
    }()

    private var activeTrip: Trip? {
        appState.activeTrip(in: trips)
    }

    /// 旅行模式（清單＋Tips）＝有進行中行程「且」本次 session 已明確選定行程；
    /// 冷啟動一律從「行程」階段開始
    private var hasActiveTrip: Bool { activeTrip != nil && appState.hasEnteredTrip }

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
            FloatingMascotDock(onExpand: speakTrivia)
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
        .onChange(of: appState.hasEnteredTrip) { _, _ in
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

    /// 依目前行程狀態更新小史萊姆訊息：
    /// 警戒類提醒（出發日、回程日、D-1 充電）照常顯示，其餘時候講旅遊冷知識
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

        if contextual.expression != .alert {
            Task {
                let fact = await TriviaService.nextFact(for: trip)
                // 期間若有更重要的話（天氣警報、查詢結果）就不蓋掉
                if mascot.expression != .alert {
                    mascot.message = "冷知識：\(fact)"
                    mascot.expression = .happy
                }
            }
        }
    }

    /// 點開小史萊姆 → 換下一則冷知識
    private func speakTrivia() {
        guard let trip = activeTrip else { return }
        Task {
            let fact = await TriviaService.nextFact(for: trip)
            mascot.message = "冷知識：\(fact)"
            mascot.expression = .happy
        }
    }
}
