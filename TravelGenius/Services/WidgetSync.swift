//
//  WidgetSync.swift
//  TravelGenius
//
//  把目前行程寫進 App Group 共享儲存，供主畫面「出發倒數」小工具讀取。
//  欄位需與 TravelGeniusWidget/RunwayWidget.swift 的 DepartureSnapshot 保持一致。
//  倒數天數由 widget 端以 startDate/endDate 即時計算，跨日不會過期。
//

import Foundation
import WidgetKit

enum WidgetSync {
    static let appGroupID = "group.com.example.TravelGenius"
    static let defaultsKey = "departureSnapshot"

    struct Snapshot: Codable {
        var tripName: String
        var startDate: Date
        var endDate: Date
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

        let packing = trip.packingItems ?? []
        let snapshot = Snapshot(
            tripName: trip.name,
            startDate: trip.startDate,
            endDate: trip.endDate,
            packedCount: packing.filter(\.isPacked).count,
            packingTotal: packing.count,
            updatedAt: .now
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: defaultsKey)
        }
    }
}
