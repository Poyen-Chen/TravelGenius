import Testing
import Foundation
import SwiftData
@testable import TravelGenius

/// Seam C：把產生結果合併進行程的清單。
/// 這裡是 Codex 標為 high 的資料破壞所在：清單一旦改讀裝置當下偏好，
/// 第二台裝置開啟同一行程就會刪掉不符合它本機偏好的項目，再同步回去。
@Suite("打包清單合併")
@MainActor
struct PackingSyncTests {

    /// 每個測試各自一個 in-memory 容器，彼此不互相汙染
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Trip.self, Expense.self, PackingItem.self,
            MedicalProfile.self, Medication.self, AllergyRecord.self,
            VaccineRecord.self, EmergencyContact.self,
            PackingLibraryItem.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeTrip(in context: ModelContext, days: Int = 5) -> Trip {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 10
        let start = Calendar.current.date(from: components)!
        let end = Calendar.current.date(byAdding: .day, value: days - 1, to: start)!
        let trip = Trip(
            name: "測試行程",
            countryCode: "JP",
            startDate: start,
            endDate: end,
            homeCurrencyCode: "TWD",
            localCurrencyCode: "JPY",
            totalBudget: 0,
            tripType: .leisure
        )
        trip.originCountryCode = "TW"
        context.insert(trip)
        return trip
    }

    private func preferences(party: TravelParty) -> UserPreferences {
        UserPreferences(
            ageBand: .adult,
            gender: .undisclosed,
            party: party,
            experience: .some,
            packingStyle: .full
        )
    }

    /// 必須先存檔再查詢：context.delete 之後關聯陣列還留著已標記刪除的物件，
    /// 直接讀 trip.packingItems 會讓斷言永遠成立，測不出刪除行為。
    private func names(in context: ModelContext, tripID: UUID) throws -> Set<String> {
        try context.save()
        let items = try context.fetch(FetchDescriptor<PackingItem>())
        return Set(items.filter { $0.trip?.id == tripID }.map(\.name))
    }

    @Test("傳入偏好代表使用者剛改過，會寫回行程快照")
    func 傳入偏好會寫回快照() throws {
        let context = try makeContext()
        let trip = makeTrip(in: context)

        PackingListGenerator.sync(trip: trip, context: context, preferences: preferences(party: .family))

        #expect(trip.packingPreferences.party == .family)
    }

    @Test("不傳偏好時依行程快照重算，不受另一台裝置的偏好影響")
    func 不傳偏好時依行程快照重算() throws {
        let context = try makeContext()
        let trip = makeTrip(in: context)

        // 第一台裝置：家庭出遊，清單含兒童常備藥
        PackingListGenerator.sync(trip: trip, context: context, preferences: preferences(party: .family))
        #expect(try names(in: context, tripID: trip.id).contains("兒童常備藥"), "家庭出遊應帶入兒童用品")

        // 第二台裝置開啟同一行程：不帶偏好參數，只能用行程快照
        PackingListGenerator.sync(trip: trip, context: context)

        #expect(try names(in: context, tripID: trip.id).contains("兒童常備藥"), "重算不得刪掉依行程快照產生的項目")
        #expect(trip.packingPreferences.party == .family, "行程快照不應被裝置偏好覆寫")
    }

    @Test("已打包的項目即使不再被建議也不會被刪掉")
    func 已打包項目不會被刪() throws {
        let context = try makeContext()
        let trip = makeTrip(in: context)

        PackingListGenerator.sync(trip: trip, context: context, preferences: preferences(party: .family))
        try context.save()

        let kidsMeds = try #require(
            (trip.packingItems ?? []).first { $0.name == "兒童常備藥" },
            "前提不成立：家庭出遊應先產生兒童常備藥"
        )
        kidsMeds.isPacked = true

        // 改成獨旅，兒童常備藥不再被建議
        PackingListGenerator.sync(trip: trip, context: context, preferences: preferences(party: .solo))

        #expect(try names(in: context, tripID: trip.id).contains("兒童常備藥"),
                "已打包的東西已經在行李箱裡了，不能因為規則變了就從清單消失")
    }

    @Test("使用者自己加的項目不受重算影響")
    func 自訂項目不會被刪() throws {
        let context = try makeContext()
        let trip = makeTrip(in: context)

        PackingListGenerator.sync(trip: trip, context: context, preferences: preferences(party: .solo))
        let custom = PackingItem(
            name: "耳塞",
            category: .other,
            reasonKey: PackingListGenerator.customReason,
            quantity: 1,
            isCustom: true,
            sortIndex: PackingListGenerator.customSortIndex,
            trip: trip
        )
        context.insert(custom)

        PackingListGenerator.sync(trip: trip, context: context, preferences: preferences(party: .family))

        #expect(try names(in: context, tripID: trip.id).contains("耳塞"))
    }

    @Test("重算不會把既有項目重複加入一次")
    func 重算不產生重複項目() throws {
        let context = try makeContext()
        let trip = makeTrip(in: context)

        PackingListGenerator.sync(trip: trip, context: context, preferences: preferences(party: .solo))
        try context.save()
        let firstPass = try context.fetch(FetchDescriptor<PackingItem>()).count

        PackingListGenerator.sync(trip: trip, context: context, preferences: preferences(party: .solo))
        try context.save()
        let secondPass = try context.fetch(FetchDescriptor<PackingItem>()).count

        #expect(firstPass == secondPass, "同樣的偏好重算兩次，項目數不應改變")
    }

    /// 五天的行程：完整打包上限 7 件，所以拿 5 件；輕便上限 4 件，應降為 4 件。
    @Test("改成輕便打包時，既有項目的數量要跟著調整")
    func 改變打包風格會更新既有項目數量() throws {
        let context = try makeContext()
        let trip = makeTrip(in: context, days: 5)

        var full = preferences(party: .solo)
        full.packingStyle = .full
        PackingListGenerator.sync(trip: trip, context: context, preferences: full)
        try context.save()

        let before = try #require(
            (trip.packingItems ?? []).first { $0.name == "換洗衣物" },
            "前提不成立：基本規則應產生換洗衣物"
        )
        #expect(before.quantity == 5, "五天行程在完整打包下應帶 5 件")

        var light = preferences(party: .solo)
        light.packingStyle = .light
        PackingListGenerator.sync(trip: trip, context: context, preferences: light)
        try context.save()

        let after = try #require(
            try context.fetch(FetchDescriptor<PackingItem>())
                .first { $0.trip?.id == trip.id && $0.name == "換洗衣物" }
        )
        #expect(after.quantity == 4, "輕便打包上限為 4 件，既有項目的數量應一併下修")
    }
}
