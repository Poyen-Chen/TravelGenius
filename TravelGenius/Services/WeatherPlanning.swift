import Foundation

enum WeatherProvider: String, Codable, Sendable {
    case weatherKit = "weatherkit"
    case openMeteo = "openmeteo"
    var forecastDays: Int { self == .weatherKit ? 10 : 16 }
    var name: String { self == .weatherKit ? "Apple Weather" : "Open-Meteo" }
}

/// Calendar-day strings are captured from the date picker's calendar, then interpreted in the destination zone.
struct WeatherRequest: Codable, Hashable, Sendable {
    let cityID: String
    let cityName: String
    let latitude: Double
    let longitude: Double
    let timeZoneID: String
    let start: String
    let end: String
    /// nil decodes the early stage-4 WeatherKit-only snapshot without rewriting stored trips.
    var provider: WeatherProvider? = nil
    var source: WeatherProvider { provider ?? .weatherKit }

    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
        return value
    }
    func date(_ day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let value = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        return value.flatMap { Self.day($0, calendar: calendar) == day ? $0 : nil }
    }
    static func day(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    var dates: [String] {
        guard var cursor = date(start), let finish = date(end), cursor <= finish else { return [] }
        var result: [String] = []
        // Bound malformed imported data; the UI handles unsupported ranges explicitly.
        while cursor <= finish && result.count <= 3660 {
            result.append(Self.day(cursor, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { return [] }
            cursor = next
        }
        return result.count <= 3660 ? result : []
    }
    func forecastDates(now: Date) -> [String] {
        let today = calendar.startOfDay(for: now)
        let horizon = calendar.date(byAdding: .day, value: source.forecastDays - 1, to: today)!
        return dates.filter { day in date(day).map { $0 >= today && $0 <= horizon } ?? false }
    }
    var cacheKey: String {
        "\(source.rawValue).v1|\(cityID)|\(latitude)|\(longitude)|\(timeZoneID)|\(start)|\(end)"
    }
}

struct WeatherDay: Codable, Equatable, Sendable {
    let date: String
    let low: Double
    let high: Double
    let rainChance: Double
    var valid: Bool { low.isFinite && high.isFinite && low <= high && (-100...70).contains(low) && (-100...70).contains(high) && rainChance.isFinite && (0...1).contains(rainChance) }
    var tags: Set<String> {
        var result = Set<String>()
        if high >= 30 { result.insert("hot") }
        if low <= 10 { result.insert("cold") }
        if high < 30 && low > 10 { result.insert("mild") }
        if rainChance >= 0.5 { result.insert("rain") }
        return result
    }
}

struct WeatherCredit: Codable, Equatable, Sendable {
    let lightMark: URL
    let darkMark: URL
    let legalURL: URL
}

enum WeatherFailure: String, Codable, Sendable {
    case outsideRange, unavailable, offline, timeout, incomplete, invalidDates, skipped
    var message: String {
        switch self {
        case .outsideRange: "旅行日期不在目前可取得的預報範圍。"
        case .unavailable: "暫時無法取得天氣預報，可能是服務或授權設定尚未就緒。"
        case .offline: "目前無法連線取得預報。"
        case .timeout: "天氣查詢逾時，先使用季節參考。"
        case .incomplete: "部分日期缺少有效預報。"
        case .invalidDates: "日期或城市時區無法用於天氣查詢。"
        case .skipped: "已選擇使用季節參考繼續。"
        }
    }
}

struct SeasonalProfile: Codable, Equatable, Sendable {
    let version: Int
    let cityID: String
    let timeZoneID: String
    let hot: [Int]
    let cold: [Int]
    let rain: [Int]
    let sourceName: String
    let sourceURL: URL
    let checkedOn: String
    func tags(month: Int) -> Set<String> {
        var result: Set<String> = []
        if hot.contains(month) { result.insert("hot") }
        if cold.contains(month) { result.insert("cold") }
        if !hot.contains(month) && !cold.contains(month) { result.insert("mild") }
        if rain.contains(month) { result.insert("rain") }
        return result
    }
}

/// An immutable creation reference, not a claim of currently fresh weather.
struct PackingWeather: Codable, Equatable, Sendable {
    var version = 1
    let request: WeatherRequest
    let days: [WeatherDay]
    let fetchedAt: Date
    let seasonal: SeasonalProfile?
    let failure: WeatherFailure?
    let credit: WeatherCredit?

    var missingDates: [String] { request.dates.filter { date in !days.contains { $0.date == date } } }
    var title: String { days.isEmpty ? "季節參考・非實際預報" : missingDates.isEmpty ? "完整旅行日期預報" : "部分日期預報＋季節參考" }
    var tags: Set<String> {
        days.reduce(into: Set<String>()) { $0.formUnion($1.tags) }.union(seasonalTags)
    }
    var forecastTags: Set<String> { days.reduce(into: Set<String>()) { $0.formUnion($1.tags) } }
    /// A reminder, never a claim that an item was added or that rain is certain.
    var packingReminder: String {
        var items: [String] = []
        if tags.contains("cold") { items.append("保暖衣物") }
        if tags.contains("hot") { items.append("防曬用品") }
        if tags.contains("rain") { items.append("雨具") }
        return items.isEmpty ? "出發前再確認天氣" : items.joined(separator: "、") + "記得確認"
    }
    var coverageLabel: String {
        if days.isEmpty { return seasonal == nil ? "暫無天氣資料" : "季節參考・非預報" }
        return missingDates.isEmpty ? "完整 \(days.count) 天預報" : "僅 \(days.count)/\(request.dates.count) 天有預報"
    }
    var seasonalTags: Set<String> {
        guard let seasonal else { return [] }
        let months = Set(missingDates.compactMap { request.date($0).map { request.calendar.component(.month, from: $0) } })
        return months.reduce(into: Set<String>()) { $0.formUnion(seasonal.tags(month: $1)) }
    }
    func reason(for tags: [String]) -> String {
        let forecast = !forecastTags.isDisjoint(with: tags)
        let estimated = !seasonalTags.isDisjoint(with: tags)
        return forecast && estimated ? "依部分日期預報與當地季節參考" : forecast ? "依旅行日期預報" : "依當地季節參考（非預報）"
    }
    var valid: Bool {
        version == 1 && !request.dates.isEmpty && TimeZone(identifier: request.timeZoneID) != nil
        && request.latitude.isFinite && (-90...90).contains(request.latitude)
        && request.longitude.isFinite && (-180...180).contains(request.longitude)
        && days.allSatisfy { $0.valid && request.dates.contains($0.date) }
        && Set(days.map(\.date)).count == days.count && (days.isEmpty || request.source == .openMeteo || credit != nil)
        && (seasonal == nil || (seasonal?.cityID == request.cityID && seasonal?.version == 1))
    }
    var summary: WeatherSummary? {
        guard let low = days.map(\.low).min(), let high = days.map(\.high).max() else { return nil }
        return .init(cityZh: request.cityName, rainDays: days.filter { $0.rainChance >= 0.5 }.count, tempMin: low, tempMax: high, fetchedAt: fetchedAt)
    }
    static func resolve(request: WeatherRequest, days: [WeatherDay], now: Date, profile: SeasonalProfile?, failure: WeatherFailure? = nil, credit: WeatherCredit? = nil) -> Self {
        let allowed = Set(request.forecastDates(now: now))
        let counts = Dictionary(grouping: days, by: \.date)
        let valid = credit == nil && request.source == .weatherKit ? [] : days.filter { $0.valid && allowed.contains($0.date) && counts[$0.date]?.count == 1 }.sorted { $0.date < $1.date }
        return .init(request: request, days: valid, fetchedAt: now, seasonal: profile,
                     failure: failure ?? (valid.count < request.dates.count ? .incomplete : nil), credit: valid.isEmpty ? nil : credit)
    }
    func isFresh(for query: WeatherRequest, now: Date) -> Bool {
        valid && request == query && !days.isEmpty && now >= fetchedAt && now.timeIntervalSince(fetchedAt) < 6 * 3600
        && WeatherRequest.day(now, calendar: request.calendar) == WeatherRequest.day(fetchedAt, calendar: request.calendar)
    }
}

struct WeatherSummary: Codable {
    let cityZh: String
    let rainDays: Int
    let tempMin: Double
    let tempMax: Double
    let fetchedAt: Date
    var headline: String { "\(Int(tempMin.rounded()))–\(Int(tempMax.rounded()))°C；\(rainDays) 天降雨機率較高" }
}
