//
//  WeatherService.swift
//  TravelGenius
//
//  Apple WeatherKit 抓目的地城市在旅行日期的每日預報，
//  轉成天氣標籤（rain / hot / cold / mild）調整清單；離線、未開通或超出預報範圍時退回月份規則。
//  WeatherKit 隨 Apple Developer Program 提供且可商用（Open-Meteo 免費方案禁止商業用途）。
//  需在 App ID 開啟 WeatherKit capability，並依規定顯示 Apple Weather 標誌與法律聲明（WeatherAttributionView）。
//

import Foundation
import CoreLocation
import WeatherKit

struct WeatherSummary: Codable {
    let cityZh: String
    let rainDays: Int
    let tempMin: Double
    let tempMax: Double
    let fetchedAt: Date

    var tags: Set<String> {
        var result = Set<String>()
        if rainDays > 0 { result.insert("rain") }
        if tempMax >= 30 { result.insert("hot") }
        if tempMin <= 10 { result.insert("cold") }
        if !result.contains("hot") && !result.contains("cold") { result.insert("mild") }
        return result
    }

    var headline: String {
        var parts: [String] = []
        parts.append("\(Int(tempMin.rounded()))–\(Int(tempMax.rounded()))°C")
        if rainDays > 0 { parts.append("約 \(rainDays) 天有雨") }
        return parts.joined(separator: "、")
    }
}

enum WeatherService {
    /// WeatherKit 每日預報約涵蓋今天起 10 天
    private static let forecastDays = 10

    private static func cacheKey(for trip: Trip) -> String {
        "weather.\(trip.id.uuidString)"
    }

    /// 抓取行程期間預報；快取 6 小時。回傳 nil = 無座標／超出預報範圍／離線／WeatherKit 未開通
    static func fetch(for trip: Trip) async -> WeatherSummary? {
        let store = StaticDataStore.shared
        guard let city = store.city(countryCode: trip.countryCode, name: trip.city)
            ?? store.defaultCity(countryCode: trip.countryCode) else { return nil }

        if let cached = loadCache(for: trip),
           Date.now.timeIntervalSince(cached.fetchedAt) < 6 * 3600,
           cached.cityZh == city.cityZh {
            return cached
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = max(calendar.startOfDay(for: trip.startDate), today)
        let end = calendar.startOfDay(for: trip.endDate)
        guard end >= start,
              let horizon = calendar.date(byAdding: .day, value: forecastDays - 1, to: today),
              start <= horizon,
              // WeatherKit 的日期區間不含 endDate，因此多加一天
              let queryEnd = calendar.date(byAdding: .day, value: 1, to: min(end, horizon)) else { return nil }

        let location = CLLocation(latitude: city.lat, longitude: city.lon)
        do {
            let days = try await WeatherKit.WeatherService.shared.weather(
                for: location,
                including: .daily(startDate: start, endDate: queryEnd)
            ).forecast
            guard !days.isEmpty else { return nil }
            let summary = WeatherSummary(
                cityZh: city.cityZh,
                rainDays: days.filter { $0.precipitationChance >= 0.5 }.count,
                tempMin: days.map { $0.lowTemperature.converted(to: .celsius).value }.min() ?? 0,
                tempMax: days.map { $0.highTemperature.converted(to: .celsius).value }.max() ?? 0,
                fetchedAt: .now
            )
            saveCache(summary, for: trip)
            return summary
        } catch {
            return loadCache(for: trip)
        }
    }

    private static func loadCache(for trip: Trip) -> WeatherSummary? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: trip)) else { return nil }
        return try? JSONDecoder().decode(WeatherSummary.self, from: data)
    }

    private static func saveCache(_ summary: WeatherSummary, for trip: Trip) {
        if let data = try? JSONEncoder().encode(summary) {
            UserDefaults.standard.set(data, forKey: cacheKey(for: trip))
        }
    }
}
