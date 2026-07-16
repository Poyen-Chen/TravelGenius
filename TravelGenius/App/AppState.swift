//
//  AppState.swift
//  TravelGenius
//

import Foundation
import Observation

@Observable
final class AppState {
    private static let activeTripKey = "activeTripID"

    var activeTripID: String? {
        didSet {
            if let activeTripID {
                UserDefaults.standard.set(activeTripID, forKey: Self.activeTripKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.activeTripKey)
            }
        }
    }

    init() {
        activeTripID = UserDefaults.standard.string(forKey: Self.activeTripKey)
    }

    /// 解析目前行程：指定 ID 優先；否則取日期涵蓋今天者；再否則取最近建立者（已結束行程一律排除）
    func activeTrip(in trips: [Trip]) -> Trip? {
        let open = trips.filter { !$0.isClosed }
        if let activeTripID,
           let match = open.first(where: { $0.id.uuidString == activeTripID }) {
            return match
        }
        let now = Date()
        return open.first { $0.contains(now) } ?? open.max { $0.createdAt < $1.createdAt }
    }

    func setActive(_ trip: Trip?) {
        activeTripID = trip?.id.uuidString
    }
}
