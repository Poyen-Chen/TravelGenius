import Foundation

enum WeatherResponseError: Error { case unavailable, malformed }

struct OpenMeteoDailyResponse: Decodable {
    struct Daily: Decodable {
        let time: [String]
        let temperature_2m_max: [Double?]
        let temperature_2m_min: [Double?]
        let precipitation_probability_max: [Double?]
    }
    let daily: Daily

    static func decodeDays(_ data: Data) throws -> [WeatherDay] {
        let values = try JSONDecoder().decode(Self.self, from: data).daily
        let count = values.time.count
        guard values.temperature_2m_max.count == count, values.temperature_2m_min.count == count,
              values.precipitation_probability_max.count == count else { throw WeatherResponseError.malformed }
        return values.time.indices.compactMap { index in
            guard let low = values.temperature_2m_min[index], let high = values.temperature_2m_max[index],
                  let rain = values.precipitation_probability_max[index] else { return nil }
            return WeatherDay(date: values.time[index], low: low, high: high, rainChance: rain / 100)
        }
    }
}
