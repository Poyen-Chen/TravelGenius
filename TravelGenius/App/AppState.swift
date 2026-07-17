//
//  AppState.swift
//  TravelGenius
//

import Foundation
import Observation

enum AppTab: Hashable {
    case trips
    case preferences
    case checklist
    case tips
}

@Observable
final class AppState {
    private static let activeTripKey = "activeTripID"
    private var hasPendingCreateTripLaunchRequest = ProcessInfo.processInfo.arguments.contains("-openCreateTrip")

    var activeTripID: String? {
        didSet {
            if let activeTripID {
                UserDefaults.standard.set(activeTripID, forKey: Self.activeTripKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.activeTripKey)
            }
        }
    }

    /// 詳細頁可請求切換頂層分頁；RootTabView 消費後會清空。
    var requestedTab: AppTab?

    /// 本次 session 是否已進入旅行模式（清單＋Tips）。
    /// 不跨啟動保存 — 每次冷啟動都從「行程」頁開始；開發引數可直接跳轉。
    var hasEnteredTrip: Bool = {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-openPackTab")
            || arguments.contains("-openTipsTab")
            || arguments.contains("-showProhibited")
            || arguments.contains("-showEtiquette")
    }()

    init() {
        activeTripID = UserDefaults.standard.string(forKey: Self.activeTripKey)
    }

    /// 解析目前行程：指定 ID 優先；否則取進行中；再取最近即將出發的行程。
    func activeTrip(in trips: [Trip]) -> Trip? {
        let open = trips.filter { trip in
            let status = trip.lifecycleStatus
            return status == .inProgress || status == .upcoming
        }
        if let activeTripID,
           let match = open.first(where: { $0.id.uuidString == activeTripID }) {
            return match
        }
        let now = Date()
        return open.first { $0.contains(now) }
            ?? open.filter { $0.startDate > now }.min { $0.startDate < $1.startDate }
    }

    func setActive(_ trip: Trip?) {
        activeTripID = trip?.id.uuidString
        // 明確選定／建立行程 → 本次 session 進入旅行模式
        if trip != nil {
            hasEnteredTrip = true
        }
    }

    func consumeCreateTripLaunchRequest() -> Bool {
        guard hasPendingCreateTripLaunchRequest else { return false }
        hasPendingCreateTripLaunchRequest = false
        return true
    }

    func open(_ tab: AppTab, for trip: Trip? = nil) {
        if let trip { setActive(trip) }
        requestedTab = tab
    }
}
