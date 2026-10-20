//
//  TravelGeniusApp.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

@main
struct TravelGeniusApp: App {
    @State private var appState = AppState()
    @State private var mascotState = MascotState()
    private let container: ModelContainer

    init() {
        _ = ReferenceDataCache.shared // Promote a complete staged generation before any data access.
        Task { await ReferenceDataUpdater.shared.refresh() }
        do {
            PackingStaples.library = try PackingLibraryStore.open()
            // 聚焦版仍註冊全部模型，避免既有安裝的 schema migration 問題
            container = try ModelContainer(
                for: Trip.self, Expense.self, PackingItem.self,
                MedicalProfile.self, Medication.self, AllergyRecord.self,
                VaccineRecord.self, EmergencyContact.self,
                configurations: ModelConfiguration(cloudKitDatabase: .none)
            )
        } catch {
            fatalError("無法建立資料庫：\(error)")
        }
        configurePackingImageDefault() // 在 demo 種資料前判斷，demo 行程不算既有安裝
        if ProcessInfo.processInfo.arguments.contains("-seedDemo") {
            DemoSeeder.seedIfNeeded(into: container.mainContext)
        }
        configureOnboardingGate()
        logCheckerDebugQuery()
    }

    /// 圖片模式只是新安裝的預設（PD-061）；升級用戶沒選過時維持原本的文字模式。
    /// 必須在 onboarding gate 與 demo 種資料之前判斷，才分得出是否為既有安裝。
    private func configurePackingImageDefault() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "packmon.packing.images") == nil else { return }
        let tripCount = (try? container.mainContext.fetchCount(FetchDescriptor<Trip>())) ?? 0
        let existingInstall = defaults.bool(forKey: "hasOnboarded") || tripCount > 0
        defaults.set(!existingInstall, forKey: "packmon.packing.images")
    }

    /// 開發驗證用：`-checkItem 肉鬆` 直接在 log 印出「能帶嗎」判定
    private func logCheckerDebugQuery() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-checkItem"), index + 1 < arguments.count else { return }
        let query = arguments[index + 1]
        for verdict in CanIBringService.check(query, destination: "JP", origin: "TW") {
            NSLog("CHECK-ITEM [%@] %@ — %@（%@）", query, verdict.kind.label, verdict.matchedName, verdict.context ?? "-")
        }
    }

    /// 首次啟動顯示 onboarding；已有行程（升級用戶）或帶開發引數時自動略過
    private func configureOnboardingGate() {
        let defaults = UserDefaults.standard
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-resetOnboarding") {
            defaults.set(false, forKey: "hasOnboarded")
            return
        }
        guard !defaults.bool(forKey: "hasOnboarded") else { return }
        let hasDebugArgs = arguments.contains { $0.hasPrefix("-seedDemo") || $0.hasPrefix("-open") || $0.hasPrefix("-show") }
        let tripCount = (try? container.mainContext.fetchCount(FetchDescriptor<Trip>())) ?? 0
        if hasDebugArgs || tripCount > 0 {
            defaults.set(true, forKey: "hasOnboarded")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootGateView()
                .environment(appState)
                .environment(mascotState)
        }
        .modelContainer(container)
    }
}
