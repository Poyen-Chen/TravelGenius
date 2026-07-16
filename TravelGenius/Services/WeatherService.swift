//
//  WeatherService.swift
//  TravelGenius
//
//  Open-Meteo（免費、免金鑰）抓目的地城市在旅行日期的預報，
//  轉成天氣標籤（rain / hot / cold / mild）調整清單；離線或超出預報範圍時退回月份規則。
//

import Foundation

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
    private struct OpenMeteoResponse: Decodable {
        struct Daily: Decodable {
            let time: [String]
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let precipitation_probability_max: [Int?]
        }
        let daily: Daily
    }

    private static func cacheKey(for trip: Trip) -> String {
        "weather.\(trip.id.uuidString)"
    }

    /// 抓取行程期間預報；快取 6 小時。回傳 nil = 無座標／超出 16 天預報範圍／離線
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
              let horizon = calendar.date(byAdding: .day, value: 15, to: today),
              start <= horizon else { return nil }
        let cappedEnd = min(end, horizon)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(city.lat)),
            URLQueryItem(name: "longitude", value: String(city.lon)),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            URLQueryItem(name: "start_date", value: formatter.string(from: start)),
            URLQueryItem(name: "end_date", value: formatter.string(from: cappedEnd)),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let daily = decoded.daily
            guard !daily.temperature_2m_max.isEmpty else { return nil }
            let summary = WeatherSummary(
                cityZh: city.cityZh,
                rainDays: daily.precipitation_probability_max.filter { ($0 ?? 0) >= 50 }.count,
                tempMin: daily.temperature_2m_min.min() ?? 0,
                tempMax: daily.temperature_2m_max.max() ?? 0,
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
