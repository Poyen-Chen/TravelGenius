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
    @AppStorage("hasSeenFirstLaunchGuide") private var hasSeenFirstLaunchGuide = false
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(PackmonThemeID.storageKey) private var designThemeRaw = PackmonThemeID.structureC.rawValue

    private var designTheme: PackmonThemeID {
        PackmonThemeID(rawValue: designThemeRaw) ?? .structureC
    }

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
        .fullScreenCover(
            isPresented: Binding(
                get: { hasOnboarded && !hasSeenFirstLaunchGuide },
                set: { isPresented in
                    if !isPresented { hasSeenFirstLaunchGuide = true }
                }
            )
        ) {
            FirstLaunchGuideView {
                hasSeenFirstLaunchGuide = true
            }
        }
        .onAppear { applyAppearance() }
        .onChange(of: appearanceRaw) { _, _ in applyAppearance() }
        .environment(\.packmonTheme, designTheme.theme)
        .tint(designTheme.theme.colors.accent)
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

/// 結構 C：頂層導航固定為行程／查詢／知識／我的；
/// 行程內再切換總覽／打包／違禁品／知識。
struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @Environment(MascotState.self) private var mascot
    @Query private var trips: [Trip]

    @State private var selection: AppTab = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-openTipsTab") || arguments.contains("-showProhibited") { return .checker }
        if arguments.contains("-showEtiquette") { return .knowledge }
        return .trips
    }()

    private var activeTrip: Trip? {
        appState.activeTrip(in: trips)
    }

    var body: some View {
        TabView(selection: $selection) {
            TripListView()
                .tabItem { Label("行程", systemImage: "suitcase.rolling") }
                .tag(AppTab.trips)

            StandaloneBringCheckerView()
                .tabItem { Label("查詢", systemImage: "magnifyingglass") }
                .tag(AppTab.checker)

            KnowledgeLibraryView()
                .tabItem { Label("知識", systemImage: "book.pages") }
                .tag(AppTab.knowledge)

            ProfileHubView()
                .tabItem { Label("我的", systemImage: "person") }
                .tag(AppTab.profile)
        }
        .overlay {
            FloatingMascotDock(onExpand: speakTrivia)
        }
        .onAppear {
            refreshMascotMessage()
        }
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
