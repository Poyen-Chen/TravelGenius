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
            RootTabView()
                .environment(appState)
        }
        .modelContainer(container)
    }
}
