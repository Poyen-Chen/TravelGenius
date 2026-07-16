//
//  WidgetSync.swift
//  TravelGenius
//
//  把目前行程的跑道數字寫進 App Group 共享儲存，供主畫面小工具讀取。
//  欄位需與 TravelGeniusWidget/RunwayWidget.swift 的 RunwaySnapshot 保持一致。
//

import Foundation
import WidgetKit

enum WidgetSync {
    static let appGroupID = "group.com.example.TravelGenius"
    static let defaultsKey = "runwaySnapshot"

    struct Snapshot: Codable {
        var tripName: String
        var runwayDays: Double?
        var burnRatePerDay: Double
        var remainingTripDays: Int
        var statusRaw: String
        var todaySpent: Double
        var todayCap: Double
        var currencyCode: String
        var packedCount: Int
        var packingTotal: Int
        var updatedAt: Date
    }

    /// 以目前行程更新小工具；傳入 nil 表示沒有進行中的行程
    static func update(trip: Trip?) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defer { WidgetCenter.shared.reloadAllTimelines() }

        guard let trip else {
            defaults.removeObject(forKey: defaultsKey)
            return
        }

        let calc = RunwayCalculator(trip: trip)
        let packing = trip.packingItems ?? []
        let snapshot = Snapshot(
            tripName: trip.name,
            runwayDays: calc.runwayDays,
            burnRatePerDay: calc.burnRatePerDay,
            remainingTripDays: calc.remainingTripDays,
            statusRaw: calc.status.rawValue,
            todaySpent: calc.todaySpent,
            todayCap: calc.todayCap,
            currencyCode: trip.homeCurrencyCode,
            packedCount: packing.filter(\.isPacked).count,
            packingTotal: packing.count,
            updatedAt: .now
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: defaultsKey)
        }
    }
}
