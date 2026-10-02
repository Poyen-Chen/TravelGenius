//
//  UserPreferences.swift
//  TravelGenius
//
//  使用者偏好：設備、常備需求與打包風格。
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
        .init(id: "skincare", label: "保養用品", itemIDs: ["skincare"]),
        .init(id: "period", label: "生理用品", itemIDs: ["sanitary-products"]),
        .init(id: "document-backup", label: "旅行文件備份", itemIDs: ["travel-document-backup"])
    ]

    static func validDevices(_ values: [String]) -> [String] { filtered(values, options: devices) }
    static func validNeeds(_ values: [String]) -> [String] { filtered(values, options: needs) }

    private static func filtered(_ values: [String], options: [Option]) -> [String] {
        let allowed = Set(options.map(\.id))
        var seen = Set<String>()
        return values.filter { allowed.contains($0) && seen.insert($0).inserted }
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
    var packingStyle: PackingStyle
    var devices: [String]
    var needs: [String]

    var summary: String {
        "\(devices.count) 項設備・\(needs.count) 項需求・\(packingStyle.label)"
    }

    static func forNewTrips(defaults: UserDefaults = .standard) -> UserPreferences {
        UserPreferences(
            packingStyle: PackingStyle(rawValue: defaults.string(forKey: packingStyleKey) ?? "") ?? .normal,
            devices: PersonalPackingOptions.validDevices(defaults.stringArray(forKey: "pref.devices") ?? ["phone"]),
            needs: PersonalPackingOptions.validNeeds(defaults.stringArray(forKey: "pref.needs") ?? [])
        )
    }

    static let packingStyleKey = "pref.packingStyle"

    static func load() -> UserPreferences {
        let defaults = UserDefaults.standard
        return UserPreferences(
            packingStyle: PackingStyle(rawValue: defaults.string(forKey: packingStyleKey) ?? "") ?? .normal,
            devices: PersonalPackingOptions.validDevices(defaults.stringArray(forKey: "pref.devices") ?? ["phone"]),
            needs: PersonalPackingOptions.validNeeds(defaults.stringArray(forKey: "pref.needs") ?? [])
        )
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(packingStyle.rawValue, forKey: Self.packingStyleKey)
        defaults.set(PersonalPackingOptions.validDevices(devices), forKey: "pref.devices")
        defaults.set(PersonalPackingOptions.validNeeds(needs), forKey: "pref.needs")
    }
}
