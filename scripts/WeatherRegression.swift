import Foundation

@main
struct WeatherRegression {
    static func query(_ city: String = "US-紐約", _ zone: String = "America/New_York", _ start: String = "2026-03-07", _ end: String = "2026-03-18") -> WeatherRequest {
        .init(cityID: city, cityName: city, latitude: 40, longitude: -74, timeZoneID: zone, start: start, end: end)
    }
    static let credit = WeatherCredit(lightMark: URL(string: "https://weatherkit.apple.com/light.png")!, darkMark: URL(string: "https://weatherkit.apple.com/dark.png")!, legalURL: URL(string: "https://weatherkit.apple.com/legal")!)
    @MainActor
    static func main() async throws {
        let profiles = try JSONDecoder().decode([SeasonalProfile].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        precondition(profiles.count == 11 && Set(profiles.map(\.cityID)).count == 11)
        for p in profiles {
            precondition(p.version == 1 && TimeZone(identifier: p.timeZoneID) != nil)
            precondition((p.hot + p.cold + p.rain).allSatisfy { (1...12).contains($0) })
            precondition(p.sourceURL.scheme == "https" && !p.sourceName.isEmpty)
        }
        let q = query()
        let now = q.date("2026-03-07")!.addingTimeInterval(3600)
        precondition(q.dates.count == 12 && q.forecastDates(now: now).count == 10)
        precondition(q.date("2026-03-09")!.timeIntervalSince(q.date("2026-03-08")!) == 23 * 3600)
        let fall = query("US-紐約", "America/New_York", "2026-10-31", "2026-11-02")
        precondition(fall.dates.count == 3)
        precondition(fall.date("2026-11-02")!.timeIntervalSince(fall.date("2026-11-01")!) == 25 * 3600)
        precondition(query("x", "Asia/Tokyo", "2026-02-30", "2026-03-04").dates.isEmpty)
        precondition(query("x", "Asia/Tokyo", "2026-04-03", "2026-04-02").dates.isEmpty)
        let tokyo = query("JP-東京", "Asia/Tokyo", "2026-03-07", "2026-03-18")
        precondition(tokyo.cacheKey != q.cacheKey)
        let ny = profiles.first { $0.cityID == "US-紐約" }!
        let la = profiles.first { $0.cityID == "US-洛杉磯" }!
        precondition(ny.tags(month: 1).contains("cold") && !la.tags(month: 1).contains("cold"))
        precondition(la.tags(month: 1).contains("rain") && !la.tags(month: 7).contains("rain"))
        let days = q.forecastDates(now: now).map { WeatherDay(date: $0, low: 15, high: 31, rainChance: 0.5) }
        let partial = PackingWeather.resolve(request: q, days: days, now: now, profile: ny, credit: credit)
        precondition(partial.valid && partial.days.count == 10 && partial.missingDates.count == 2)
        precondition(partial.tags.isSuperset(of: ["hot", "rain", "cold"]))
        precondition(partial.summary?.rainDays == 10)
        precondition(partial.packingReminder == "保暖衣物、防曬用品、雨具記得確認")
        precondition(partial.coverageLabel == "僅 10/12 天有預報")
        let noData = PackingWeather(request: q, days: [], fetchedAt: now, seasonal: nil, failure: .offline, credit: nil)
        precondition(noData.coverageLabel == "暫無天氣資料" && noData.summary == nil)
        precondition(noData.packingReminder == "出發前再確認天氣")
        let seasonalOnly = PackingWeather(request: q, days: [], fetchedAt: now, seasonal: ny, failure: .outsideRange, credit: nil)
        precondition(seasonalOnly.coverageLabel == "季節參考・非預報" && seasonalOnly.summary == nil)
        let rainyFull = PackingWeather(request: q, days: q.dates.map { .init(date: $0, low: 19, high: 26, rainChance: 0.6) }, fetchedAt: now, seasonal: nil, failure: nil, credit: credit)
        precondition(rainyFull.coverageLabel == "完整 12 天預報" && rainyFull.packingReminder == "雨具記得確認")
        precondition(partial.isFresh(for: q, now: now.addingTimeInterval(3599)))
        precondition(!partial.isFresh(for: q, now: now.addingTimeInterval(6 * 3600)))
        precondition(!partial.isFresh(for: tokyo, now: now))
        precondition(!partial.isFresh(for: q, now: now.addingTimeInterval(-1)))
        let malformed = PackingWeather.resolve(request: q, days: [days[0], days[0], .init(date: days[1].date, low: 5, high: 3, rainChance: 0), .init(date: days[2].date, low: 5, high: 30, rainChance: .nan)], now: now, profile: ny, credit: credit)
        precondition(malformed.days.isEmpty && malformed.missingDates.count == q.dates.count)
        let noCredit = PackingWeather.resolve(request: q, days: days, now: now, profile: ny)
        precondition(noCredit.days.isEmpty)
        var open = query("US-紐約", "America/New_York", "2026-03-07", "2026-03-25")
        open.provider = .openMeteo
        precondition(open.forecastDates(now: now).count == 16)
        var apple = open; apple.provider = .weatherKit
        precondition(apple.forecastDates(now: now).count == 10 && apple.cacheKey != open.cacheKey)
        let openResult = PackingWeather.resolve(request: open, days: days, now: now, profile: ny)
        precondition(openResult.valid && openResult.days.count == 10 && !openResult.isFresh(for: apple, now: now))
        let apiJSON = #"{"daily":{"time":["2026-03-07","2026-03-08"],"temperature_2m_max":[31,null],"temperature_2m_min":[20,19],"precipitation_probability_max":[50,null]}}"#
        let apiDays = try OpenMeteoDailyResponse.decodeDays(Data(apiJSON.utf8))
        precondition(apiDays.count == 1 && apiDays[0].rainChance == 0.5)
        let badJSON = #"{"daily":{"time":["2026-03-07"],"temperature_2m_max":[],"temperature_2m_min":[20],"precipitation_probability_max":[50]}}"#
        do { _ = try OpenMeteoDailyResponse.decodeDays(Data(badJSON.utf8)); fatalError("misaligned response accepted") }
        catch WeatherResponseError.malformed { }
        print("Open-Meteo 16-day horizon, provider-separated cache, null/misaligned response validation: PASS")
        let decoded = try JSONDecoder().decode(PackingWeather.self, from: JSONEncoder().encode(partial))
        precondition(decoded == partial)
        let fullQuery = query("US-紐約", "America/New_York", "2026-03-07", "2026-03-16")
        let full = PackingWeather.resolve(request: fullQuery, days: days, now: now, profile: ny, credit: credit)
        precondition(full.missingDates.isEmpty && full.seasonalTags.isEmpty && !full.tags.contains("cold"))
        let across = query("JP-東京", "Asia/Tokyo", "2026-11-30", "2026-12-02")
        let fallback: @MainActor (WeatherRequest, WeatherFailure) -> PackingWeather = { request, reason in
            .resolve(request: request, days: [], now: now, profile: profiles.first { $0.cityID == request.cityID }, failure: reason)
        }
        let seasonal = fallback(across, .outsideRange)
        precondition(seasonal.tags.contains("mild") && seasonal.tags.contains("cold"))
        precondition(fallback(query("unknown"), .unavailable).tags.isEmpty)
        print("forecast coverage, malformed/missing data, thresholds, attribution, 11 profiles, cross-month, DST, cache freshness, serialization: PASS")

        let draft = WeatherDraft()
        var first: CheckedContinuation<PackingWeather, Error>?
        var second: CheckedContinuation<PackingWeather, Error>?
        draft.begin(q, debounce: .zero, fetch: { _ in try await withCheckedThrowingContinuation { first = $0 } }, fallback: fallback)
        while first == nil { await Task.yield() }
        draft.begin(tokyo, debounce: .zero, fetch: { _ in try await withCheckedThrowingContinuation { second = $0 } }, fallback: fallback)
        while second == nil { await Task.yield() }
        second!.resume(returning: fallback(tokyo, .offline))
        for _ in 0..<20 { await Task.yield() }
        first!.resume(returning: partial)
        for _ in 0..<20 { await Task.yield() }
        precondition(draft.result?.request == tokyo)
        var late: CheckedContinuation<PackingWeather, Error>?
        draft.begin(q, debounce: .zero, timeout: .milliseconds(20), fetch: { _ in try await withCheckedThrowingContinuation { late = $0 } }, fallback: fallback)
        while late == nil { await Task.yield() }
        try await Task.sleep(for: .milliseconds(50))
        precondition(!draft.loading && draft.result?.failure == .timeout)
        let frozen = draft.result
        late!.resume(returning: partial)
        for _ in 0..<20 { await Task.yield() }
        precondition(draft.result == frozen)
        var calls = 0
        draft.begin(tokyo, debounce: .milliseconds(30), fetch: { request in calls += 1; return fallback(request, .offline) }, fallback: fallback)
        draft.useFallback(fallback(tokyo, .skipped))
        try await Task.sleep(for: .milliseconds(50))
        precondition(calls == 0 && draft.result?.failure == .skipped)
        draft.cancel()
        print("old response rejection, uncooperative-provider timeout, frozen fallback, canceled debounce: PASS")
    }
}
