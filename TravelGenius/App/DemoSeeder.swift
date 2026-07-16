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

        // 示範偏好：家庭出遊、第一次出國 — 清單個人化分組看得見
        var preferences = UserPreferences.load()
        preferences.party = .family
        preferences.experience = .first
        preferences.save()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: 3, to: today),
              let end = calendar.date(byAdding: .day, value: 7, to: today) else { return }

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
        context.insert(trip)

        PackingListGenerator.sync(trip: trip, context: context, preferences: preferences)
        for item in (trip.packingItems ?? []).prefix(5) {
            item.isPacked = true
        }
        try? context.save()
    }
}
