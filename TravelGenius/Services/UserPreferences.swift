//
//  UserPreferences.swift
//  TravelGenius
//
//  新版使用者偏好：設備、常備需求與打包風格。舊人口欄位僅供歷史快照解碼。
//

import Foundation
import SwiftUI

enum PersonalPackingOptions {
    struct Option: Identifiable {
        let id: String
        let label: String
        let itemIDs: [String]
    }
    static let devices: [Option] = [
        .init(id: "phone", label: "手機", itemIDs: ["phone"]),
        .init(id: "laptop", label: "筆電", itemIDs: ["laptop", "laptop-charger"]),
        .init(id: "tablet", label: "平板／電子閱讀器", itemIDs: ["tablet"]),
        .init(id: "camera", label: "相機", itemIDs: ["camera", "camera-charger", "memory-card"]),
        .init(id: "watch", label: "智慧手錶", itemIDs: ["smartwatch", "watch-charger"]),
        .init(id: "headphones", label: "耳機", itemIDs: ["headphones"])
    ]
    static let needs: [Option] = [
        .init(id: "glasses", label: "眼鏡", itemIDs: ["glasses"]),
        .init(id: "contacts", label: "隱形眼鏡", itemIDs: ["contact-lenses"]),
        .init(id: "skincare", label: "保養用品", itemIDs: ["skincare"]),
        .init(id: "period", label: "生理用品", itemIDs: ["sanitary-products"]),
        .init(id: "medicine", label: "自己的常備藥", itemIDs: ["regular-medicine"]),
        .init(id: "book", label: "紙本讀物", itemIDs: ["book"])
    ]
}

enum AgeBand: String, Codable, CaseIterable, Identifiable {
    case teen
    case young
    case adult
    case middle
    case senior

    var id: String { rawValue }

    var label: String {
        switch self {
        case .teen: "13–17"
        case .young: "18–25"
        case .adult: "26–35"
        case .middle: "36–49"
        case .senior: "50–65"
        }
    }
}

enum GenderPreference: String, Codable, CaseIterable, Identifiable {
    case male
    case female
    case undisclosed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .male: "男"
        case .female: "女"
        case .undisclosed: "略過"
        }
    }
}

enum TravelParty: String, Codable, CaseIterable, Identifiable {
    case solo
    case couple
    case friends
    case family
    case colleagues

    var id: String { rawValue }

    var label: String {
        switch self {
        case .solo: "獨旅"
        case .couple: "伴侶"
        case .friends: "朋友"
        case .family: "家庭"
        case .colleagues: "同事"
        }
    }

    var emoji: String {
        switch self {
        case .solo: "🎒"
        case .couple: "💑"
        case .friends: "👯"
        case .family: "👨‍👩‍👧"
        case .colleagues: "💼"
        }
    }
}

enum TravelExperience: String, Codable, CaseIterable, Identifiable {
    case first
    case some
    case frequent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .first: "第一次出國"
        case .some: "去過幾次"
        case .frequent: "常常出國"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    static let storageKey = "pref.appearance"

    var label: String {
        switch self {
        case .system: "跟隨系統"
        case .light: "淺色"
        case .dark: "深色"
        }
    }

    /// nil = 跟隨系統
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum PackingStyle: String, Codable, CaseIterable, Identifiable {
    case light
    case normal
    case full

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "輕便"
        case .normal: "一般"
        case .full: "完整"
        }
    }

    var detail: String {
        switch self {
        case .light: "只帶必需品，行李越輕越好"
        case .normal: "基本用品優先，依天數準備換洗"
        case .full: "寧可多帶，不想到了才缺東西"
        }
    }
}

struct UserPreferences: Codable, Equatable {
    var ageBand: AgeBand
    var gender: GenderPreference
    var party: TravelParty
    var experience: TravelExperience
    var packingStyle: PackingStyle
    /// nil marks historical snapshots; [] is an explicit choice to bring none.
    var devices: [String]? = nil
    var needs: [String]? = nil

    var usesExplicitNeeds: Bool { devices != nil && needs != nil }
    var isLegacySnapshot: Bool { !usesExplicitNeeds }
    var summary: String {
        usesExplicitNeeds ? "\(devices?.count ?? 0) 項設備・\(needs?.count ?? 0) 項需求・\(packingStyle.label)"
            : "\(party.label)・\(packingStyle.label)"
    }

    static func forNewTrips(defaults: UserDefaults = .standard) -> UserPreferences {
        UserPreferences(
            ageBand: .adult,
            gender: .undisclosed,
            party: .solo,
            experience: .some,
            packingStyle: PackingStyle(rawValue: defaults.string(forKey: packingStyleKey) ?? "") ?? .normal,
            devices: defaults.stringArray(forKey: "pref.devices") ?? ["phone"],
            needs: defaults.stringArray(forKey: "pref.needs") ?? []
        )
    }

    static let ageKey = "pref.ageBand"
    static let genderKey = "pref.gender"
    static let partyKey = "pref.party"
    static let experienceKey = "pref.experience"
    static let packingStyleKey = "pref.packingStyle"

    static func load() -> UserPreferences {
        let defaults = UserDefaults.standard
        return UserPreferences(
            ageBand: AgeBand(rawValue: defaults.string(forKey: ageKey) ?? "") ?? .adult,
            gender: GenderPreference(rawValue: defaults.string(forKey: genderKey) ?? "") ?? .undisclosed,
            party: TravelParty(rawValue: defaults.string(forKey: partyKey) ?? "") ?? .solo,
            experience: TravelExperience(rawValue: defaults.string(forKey: experienceKey) ?? "") ?? .some,
            packingStyle: PackingStyle(rawValue: defaults.string(forKey: packingStyleKey) ?? "") ?? .full,
            devices: defaults.stringArray(forKey: "pref.devices"),
            needs: defaults.stringArray(forKey: "pref.needs")
        )
    }

    func save(defaults: UserDefaults = .standard) {
        // Do not keep writing hidden demographic controls into the modern preference store.
        defaults.removeObject(forKey: Self.ageKey)
        defaults.removeObject(forKey: Self.genderKey)
        defaults.removeObject(forKey: Self.partyKey)
        defaults.removeObject(forKey: Self.experienceKey)
        defaults.set(packingStyle.rawValue, forKey: Self.packingStyleKey)
        defaults.set(devices ?? [], forKey: "pref.devices")
        defaults.set(needs ?? [], forKey: "pref.needs")
    }
}
