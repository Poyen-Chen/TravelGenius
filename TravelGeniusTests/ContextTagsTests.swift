import Testing
import Foundation
@testable import TravelGenius

/// Seam A：把一趟行程攤平成 tag 集合。規則只認得這些 tag，
/// 所以這裡錯了，底下每一條打包規則都會跟著錯。
@Suite("行程 context tags")
struct ContextTagsTests {

    /// 九月的東京行，用來固定「夏季、台灣出發、五天」這組條件
    private func makeTrip(
        countryCode: String = "JP",
        originCountryCode: String = "TW",
        startMonth: Int = 9,
        days: Int = 5
    ) -> Trip {
        var components = DateComponents()
        components.year = 2026
        components.month = startMonth
        components.day = 10
        let start = Calendar.current.date(from: components)!
        let end = Calendar.current.date(byAdding: .day, value: days - 1, to: start)!
        let trip = Trip(
            name: "測試行程",
            countryCode: countryCode,
            startDate: start,
            endDate: end,
            homeCurrencyCode: "TWD",
            localCurrencyCode: "JPY",
            totalBudget: 0,
            tripType: .leisure
        )
        trip.originCountryCode = originCountryCode
        return trip
    }

    private var defaultPreferences: UserPreferences {
        UserPreferences(
            ageBand: .adult,
            gender: .undisclosed,
            party: .solo,
            experience: .some,
            packingStyle: .full
        )
    }

    @Test("沒有天氣預報時，改用出發月份推估季節")
    func 無預報時以月份推估() {
        let tags = PackingListGenerator.contextTags(
            for: makeTrip(startMonth: 9),
            preferences: defaultPreferences,
            weatherTags: nil
        )

        #expect(tags.contains("forecast:estimated"))
        #expect(tags.contains("weather:hot"))
        #expect(!tags.contains("forecast:live"))
    }

    @Test("有天氣預報時以預報為準，不再用月份推估")
    func 有預報時以預報為準() {
        // 十二月本來會推估成 cold，但預報說下雨且溫和
        let tags = PackingListGenerator.contextTags(
            for: makeTrip(startMonth: 12),
            preferences: defaultPreferences,
            weatherTags: ["rain", "mild"]
        )

        #expect(tags.contains("forecast:live"))
        #expect(tags.contains("weather:rain"))
        #expect(tags.contains("weather:mild"))
        #expect(!tags.contains("weather:cold"), "有預報時不應混入月份推估的結果")
    }

    @Test("插座相容性由兩國的插座規格推導，不靠逐一列舉")
    func 插座相容性由國家資料推導() {
        // 台灣與日本同為 Type A/B
        let compatible = PackingListGenerator.contextTags(
            for: makeTrip(countryCode: "JP", originCountryCode: "TW"),
            preferences: defaultPreferences,
            weatherTags: nil
        )
        #expect(compatible.contains("plug:compatible"))
        #expect(!compatible.contains("plug:incompatible"))
    }

    @Test("天數會分桶，讓規則能針對行程長度給建議")
    func 天數分桶() {
        func bucket(days: Int) -> Set<String> {
            PackingListGenerator.contextTags(
                for: makeTrip(days: days),
                preferences: defaultPreferences,
                weatherTags: nil
            )
        }

        #expect(bucket(days: 2).contains("duration:short"))
        #expect(bucket(days: 5).contains("duration:medium"))
        #expect(bucket(days: 12).contains("duration:long"))
        #expect(bucket(days: 5).contains("days:5"))
    }
}
