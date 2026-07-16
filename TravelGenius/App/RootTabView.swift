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

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @Query private var trips: [Trip]

    enum Tab {
        case trips
        case money
        case packing
        case medical
    }

    @State private var selection: Tab = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-openMoneyTab") { return .money }
        if arguments.contains("-openPackTab") { return .packing }
        if arguments.contains("-openMedTab") || arguments.contains("-showEmergency") || arguments.contains("-showLargePrint") { return .medical }
        // Onboarding 剛完成：直接落在行李分頁看清單
        if UserDefaults.standard.bool(forKey: "startOnPackingTab") {
            UserDefaults.standard.removeObject(forKey: "startOnPackingTab")
            return .packing
        }
        return .trips
    }()

    var body: some View {
        TabView(selection: $selection) {
            TripListView()
                .tabItem { Label("行程", systemImage: "airplane") }
                .tag(Tab.trips)

            MoneyRootView()
                .tabItem { Label("記帳", systemImage: "dollarsign.circle") }
                .tag(Tab.money)

            PackingRootView()
                .tabItem { Label("行李", systemImage: "suitcase") }
                .tag(Tab.packing)

            MedCardRootView()
                .tabItem { Label("醫療卡", systemImage: "cross.case") }
                .tag(Tab.medical)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 離開前景時更新主畫面小工具
            if newPhase != .active {
                WidgetSync.update(trip: appState.activeTrip(in: trips))
            }
        }
    }
}
