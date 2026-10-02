import Foundation
import CoreLocation
import WeatherKit
import OSLog

/// No API keys are embedded. Requires a provisioned App ID and Developer Team.
@MainActor
enum WeatherService {
    /// Non-commercial evaluation for now (PD-035). No silent fallback between providers.
    static let activeProvider: WeatherProvider = .openMeteo
    private static let log = Logger(subsystem: "com.example.TravelGenius", category: "Weather")

    static func request(city: City, start: Date, end: Date, inputCalendar: Calendar = .current) -> WeatherRequest? {
        guard let profile = StaticDataStore.shared.seasonalProfiles.first(where: { $0.cityID == city.id }),
              TimeZone(identifier: profile.timeZoneID) != nil else { return nil }
        return WeatherRequest(cityID: city.id, cityName: city.cityZh, latitude: city.lat, longitude: city.lon,
                              timeZoneID: profile.timeZoneID,
                              start: WeatherRequest.day(start, calendar: inputCalendar), end: WeatherRequest.day(end, calendar: inputCalendar), provider: activeProvider)
    }

    static func fallback(_ query: WeatherRequest, failure: WeatherFailure, now: Date = .now) -> PackingWeather {
        .resolve(request: query, days: [], now: now,
                 profile: StaticDataStore.shared.seasonalProfiles.first { $0.cityID == query.cityID }, failure: failure)
    }

    static func fetch(_ query: WeatherRequest) async throws -> PackingWeather {
        let now = Date.now
        guard !query.dates.isEmpty else { return fallback(query, failure: .invalidDates, now: now) }
        guard let first = query.forecastDates(now: now).first,
              let last = query.forecastDates(now: now).last,
              let start = query.date(first), let end = query.date(last),
              let exclusiveEnd = query.calendar.date(byAdding: .day, value: 1, to: end) else {
            return fallback(query, failure: .outsideRange, now: now)
        }
        let cache = UserDefaults.standard
        if let data = cache.data(forKey: query.cacheKey),
           let saved = try? JSONDecoder().decode(PackingWeather.self, from: data), saved.isFresh(for: query, now: now) {
            return saved
        }
        do {
            try Task.checkCancellation()
            let days: [WeatherDay]
            let credit: WeatherCredit?
            switch query.source {
            case .weatherKit:
                let forecast = try await WeatherKit.WeatherService.shared.weather(
                    for: CLLocation(latitude: query.latitude, longitude: query.longitude),
                    including: .daily(startDate: start, endDate: exclusiveEnd))
                let attribution = try await WeatherKit.WeatherService.shared.attribution
                days = forecast.forecast.map {
                    WeatherDay(date: WeatherRequest.day($0.date, calendar: query.calendar),
                               low: $0.lowTemperature.converted(to: .celsius).value,
                               high: $0.highTemperature.converted(to: .celsius).value, rainChance: $0.precipitationChance)
                }
                credit = .init(lightMark: attribution.combinedMarkLightURL, darkMark: attribution.combinedMarkDarkURL, legalURL: attribution.legalPageURL)
            case .openMeteo:
                days = try await fetchOpenMeteo(query, start: first, end: last)
                credit = nil
            }
            try Task.checkCancellation()
            let result = PackingWeather.resolve(request: query, days: days, now: now,
                profile: StaticDataStore.shared.seasonalProfiles.first { $0.cityID == query.cityID },
                credit: credit)
            if !result.days.isEmpty, let data = try? JSONEncoder().encode(result) {
                for key in cache.dictionaryRepresentation().keys where key.hasPrefix("\(query.source.rawValue).v1|") {
                    guard let previous = cache.data(forKey: key),
                          let decoded = try? JSONDecoder().decode(PackingWeather.self, from: previous),
                          now.timeIntervalSince(decoded.fetchedAt) < 6 * 3600 else {
                        cache.removeObject(forKey: key); continue
                    }
                }
                cache.set(data, forKey: query.cacheKey)
            }
            return result
        } catch {
            if Task.isCancelled || error is CancellationError { throw CancellationError() }
            let ns = error as NSError
            log.error("\(query.source.rawValue, privacy: .public) request failed: domain=\(ns.domain, privacy: .public) code=\(ns.code)")
            let failure: WeatherFailure = (error as? URLError)?.code == .timedOut ? .timeout
                : ns.domain == NSURLErrorDomain ? .offline : .unavailable
            return fallback(query, failure: failure, now: now)
        }
    }

    private static func fetchOpenMeteo(_ query: WeatherRequest, start: String, end: String) async throws -> [WeatherDay] {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(query.latitude)),
            .init(name: "longitude", value: String(query.longitude)),
            .init(name: "timezone", value: query.timeZoneID),
            .init(name: "start_date", value: start), .init(name: "end_date", value: end),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max")
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 8
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw WeatherResponseError.unavailable }
        return try OpenMeteoDailyResponse.decodeDays(data)
    }
}
