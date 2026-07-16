//
//  TravelGeniusApp.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

@main
struct TravelGeniusApp: App {
    @State private var appState = AppState()
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Trip.self, Expense.self, PackingItem.self,
                MedicalProfile.self, Medication.self, AllergyRecord.self,
                VaccineRecord.self, EmergencyContact.self
            )
        } catch {
            fatalError("無法建立資料庫：\(error)")
        }
        if ProcessInfo.processInfo.arguments.contains("-seedDemo") {
            DemoSeeder.seedIfNeeded(into: container.mainContext)
        }
        if ProcessInfo.processInfo.arguments.contains("-exportDemo") {
            exportDemoReport()
        }
        configureOnboardingGate()
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
        let hasDebugArgs = arguments.contains { $0.hasPrefix("-seedDemo") || $0.hasPrefix("-open") || $0.hasPrefix("-show") || $0.hasPrefix("-exportDemo") }
        let tripCount = (try? container.mainContext.fetchCount(FetchDescriptor<Trip>())) ?? 0
        if hasDebugArgs || tripCount > 0 {
            defaults.set(true, forKey: "hasOnboarded")
        }
    }

    /// 開發驗證用：啟動時直接產出報帳文件並印出路徑
    private func exportDemoReport() {
        let context = container.mainContext
        guard let trip = try? context.fetch(FetchDescriptor<Trip>()).first else {
            NSLog("EXPORT-DEMO: no trip")
            return
        }
        let expenses = (trip.expenses ?? []).sorted { $0.date < $1.date }
        do {
            let csv = try ReportExporter.exportCSV(trip: trip, expenses: expenses)
            let pdf = try ReportExporter.exportPDF(trip: trip, expenses: expenses, includeReceipts: true)
            NSLog("EXPORT-DEMO CSV: %@", csv.path)
            NSLog("EXPORT-DEMO PDF: %@", pdf.path)
        } catch {
            NSLog("EXPORT-DEMO FAILED: %@", "\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootGateView()
                .environment(appState)
        }
        .modelContainer(container)
    }
}
