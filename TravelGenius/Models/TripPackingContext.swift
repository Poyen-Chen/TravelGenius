import Foundation

enum PackingActivity: String, Codable, CaseIterable, Identifiable {
    case water
    case outdoors
    case snow
    case skiing
    case exercise
    case business
    case formal
    case driving

    static let recommendationOptions = allCases

    var id: String { rawValue }

    var label: String {
        switch self {
        case .water: "玩水／游泳"
        case .outdoors: "健行／登山"
        case .snow: "賞雪"
        case .skiing: "滑雪／單板"
        case .exercise: "運動／健身"
        case .business: "工作／商務"
        case .formal: "正式場合"
        case .driving: "自駕"
        }
    }
}

enum PackingStay: String, Codable, CaseIterable, Identifiable {
    case hostel

    static let recommendationOptions = allCases

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hostel: "青旅／背包客棧"
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

/// Per-trip recommendation inputs. These describe the trip, not the user's global identity.
struct TripPackingContext: Codable, Equatable {
    var activities: [PackingActivity] = []
    var stays: [PackingStay] = []
    var laundry: PackingLaundryPlan = .unknown

    static let empty = TripPackingContext()

    var valid: Bool {
        Set(activities).count == activities.count
            && Set(stays).count == stays.count
    }

    var summary: String {
        var parts: [String] = []
        if !activities.isEmpty { parts.append("\(activities.count) 項活動") }
        if !stays.isEmpty { parts.append("\(stays.count) 種住宿") }
        if laundry == .yes { parts.append("途中洗衣") }
        return parts.isEmpty ? "尚未加入活動、住宿或洗衣條件" : parts.joined(separator: "・")
    }
}
