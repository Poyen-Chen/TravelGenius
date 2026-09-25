import Foundation

enum PackingActivity: String, Codable, CaseIterable, Identifiable {
    case water
    case outdoors
    case snow
    case spa
    case exercise
    case formal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .water: "玩水／游泳"
        case .outdoors: "健行／戶外"
        case .snow: "賞雪／滑雪"
        case .spa: "泡湯／溫泉"
        case .exercise: "運動／健身"
        case .formal: "工作／正式場合"
        }
    }
}

enum PackingStay: String, Codable, CaseIterable, Identifiable {
    case hotel
    case rental
    case hostel
    case friends

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hotel: "飯店"
        case .rental: "民宿／公寓"
        case .hostel: "青旅／背包客棧"
        case .friends: "親友家"
        }
    }
}

enum PackingLaundryPlan: String, Codable, CaseIterable, Identifiable {
    case unknown
    case yes
    case no

    var id: String { rawValue }

    var label: String {
        switch self {
        case .unknown: "還不確定"
        case .yes: "途中會洗衣"
        case .no: "不會洗衣"
        }
    }
}

enum PackingSnowPlan: String, Codable, CaseIterable, Identifiable {
    case unknown
    case view
    case rent
    case own

    var id: String { rawValue }

    var label: String {
        switch self {
        case .unknown: "還不確定"
        case .view: "只賞雪"
        case .rent: "到當地租裝備"
        case .own: "自備裝備"
        }
    }
}

/// Per-trip recommendation inputs. These describe the trip, not the user's global identity.
struct TripPackingContext: Codable, Equatable {
    static let currentVersion = 1

    var version = currentVersion
    var activities: [PackingActivity] = []
    var stays: [PackingStay] = []
    var laundry: PackingLaundryPlan = .unknown
    var snowPlan: PackingSnowPlan = .unknown

    static let empty = TripPackingContext()

    var valid: Bool {
        version == Self.currentVersion
            && Set(activities).count == activities.count
            && Set(stays).count == stays.count
            && (activities.contains(.snow) || snowPlan == .unknown)
    }

    var summary: String {
        var parts: [String] = []
        if !activities.isEmpty { parts.append("\(activities.count) 項活動") }
        if !stays.isEmpty { parts.append("\(stays.count) 種住宿") }
        if laundry == .yes { parts.append("途中洗衣") }
        return parts.isEmpty ? "尚未加入活動、住宿或洗衣條件" : parts.joined(separator: "・")
    }
}
