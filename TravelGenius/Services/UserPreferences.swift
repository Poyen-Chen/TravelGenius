//
//  UserPreferences.swift
//  TravelGenius
//
//  使用者偏好：五項打包相關偏好（影響清單生成）＋外觀設定。
//

import Foundation
import SwiftUI

enum AgeBand: String, CaseIterable, Identifiable {
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

enum GenderPreference: String, CaseIterable, Identifiable {
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

enum TravelParty: String, CaseIterable, Identifiable {
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

enum TravelExperience: String, CaseIterable, Identifiable {
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

enum PackingStyle: String, CaseIterable, Identifiable {
    case light
    case full

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "輕便"
        case .full: "完整"
        }
    }

    var detail: String {
        switch self {
        case .light: "只帶必需品，行李越輕越好"
        case .full: "寧可多帶，不想到了才缺東西"
        }
    }
}

struct UserPreferences {
    var ageBand: AgeBand
    var gender: GenderPreference
    var party: TravelParty
    var experience: TravelExperience
    var packingStyle: PackingStyle

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
            packingStyle: PackingStyle(rawValue: defaults.string(forKey: packingStyleKey) ?? "") ?? .full
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(ageBand.rawValue, forKey: Self.ageKey)
        defaults.set(gender.rawValue, forKey: Self.genderKey)
        defaults.set(party.rawValue, forKey: Self.partyKey)
        defaults.set(experience.rawValue, forKey: Self.experienceKey)
        defaults.set(packingStyle.rawValue, forKey: Self.packingStyleKey)
    }
}
