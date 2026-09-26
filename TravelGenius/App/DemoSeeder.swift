//
//  DemoSeeder.swift
//  TravelGenius
//
//  以 -seedDemo 啟動引數載入示範資料，供開發與截圖驗證使用。
//

import Foundation
import SwiftData

enum DemoSeeder {
    @MainActor
    static func seedIfNeeded(into context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Trip>())) ?? 0
        guard count == 0 else { return }

        let preferences = UserPreferences.load()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let startsToday = ProcessInfo.processInfo.arguments.contains("-seedDemoDueToday")
        guard let start = calendar.date(byAdding: .day, value: startsToday ? 0 : 3, to: today),
              let end = calendar.date(byAdding: .day, value: startsToday ? 4 : 7, to: today) else { return }

        let trip = Trip(
            name: "日本・東京 5 天",
            countryCode: "JP",
            startDate: start,
            endDate: end,
            homeCurrencyCode: "TWD",
            localCurrencyCode: "JPY",
            totalBudget: 0,
            tripType: .leisure
        )
        trip.city = "東京"
        trip.originCountryCode = "TW"
        trip.originCity = "台北"
        trip.capturePackingPreferencesIfNeeded(preferences)
        trip.capturePackingContextIfNeeded(.empty)
        context.insert(trip)

        let recommendations = PackingListGenerator.generate(for: trip)
        _ = try? PackingListGenerator.addMissing(
            trip: trip,
            selectedIDs: Set(recommendations.map(\.id)),
            weather: nil,
            context: context
        )
        for item in (trip.packingItems ?? []).prefix(5) {
            item.isPacked = true
        }
        try? context.save()
    }
}
