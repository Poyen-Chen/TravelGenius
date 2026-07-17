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
        do {
            // 聚焦版仍註冊全部模型，避免既有安裝的 schema migration 問題
            container = try ModelContainer(
                for: Trip.self, Expense.self, PackingItem.self,
                MedicalProfile.self, Medication.self, AllergyRecord.self,
                VaccineRecord.self, EmergencyContact.self
            )
        } catch {
            fatalError("無法建立資料庫：\(error)")
        }
        migrateLegacyTripLifecycleIfNeeded()
        if ProcessInfo.processInfo.arguments.contains("-seedDemo") {
            DemoSeeder.seedIfNeeded(into: container.mainContext)
        }
        configureOnboardingGate()
        logCheckerDebugQuery()
    }

    /// 將舊版由日期推導的狀態轉成使用者操作狀態，並移除舊草稿。
    private func migrateLegacyTripLifecycleIfNeeded() {
        let defaults = UserDefaults.standard
        let migrationKey = "migration.explicitTripLifecycle.v1"
        guard !defaults.bool(forKey: migrationKey) else { return }

        let context = container.mainContext
        let trips = (try? context.fetch(FetchDescriptor<Trip>())) ?? []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        for trip in trips {
            if trip.isDraft {
                context.delete(trip)
                continue
            }
            guard trip.startedAt == nil, trip.completedAt == nil else { continue }
            let start = calendar.startOfDay(for: trip.startDate)
            let end = calendar.startOfDay(for: trip.endDate)
            if trip.isClosed || today > end {
                trip.startedAt = trip.startDate
                trip.completedAt = trip.endDate
                trip.isClosed = true
            } else if today >= start {
                trip.startedAt = trip.startDate
            }
        }
        try? context.save()
        defaults.set(true, forKey: migrationKey)
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
