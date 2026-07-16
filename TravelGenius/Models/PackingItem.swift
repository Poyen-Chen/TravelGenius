//
//  PackingItem.swift
//  TravelGenius
//

import Foundation
import SwiftData

enum PackingCategory: String, Codable, CaseIterable, Identifiable {
    case clothing
    case electronics
    case documents
    case toiletries
    case health
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clothing: "衣物"
        case .electronics: "電子"
        case .documents: "證件"
        case .toiletries: "盥洗"
        case .health: "健康"
        case .other: "其他"
        }
    }

    var symbolName: String {
        switch self {
        case .clothing: "tshirt"
        case .electronics: "powerplug"
        case .documents: "person.text.rectangle"
        case .toiletries: "shower"
        case .health: "cross.case"
        case .other: "shippingbox"
        }
    }
}

@Model
final class PackingItem {
    var id: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = PackingCategory.other.rawValue
    /// 「因為是…」分組（例如：因為是日本、基本必備、自訂）
    var reasonKey: String = ""
    var quantity: Int = 1
    var isPacked: Bool = false
    /// 使用者自行新增（重新產生清單時永不移除）
    var isCustom: Bool = false
    /// 顯示排序（規則檔順序；自訂項目固定最後）
    var sortIndex: Int = 0
    var trip: Trip?

    init(
        name: String,
        category: PackingCategory,
        reasonKey: String,
        quantity: Int = 1,
        isCustom: Bool = false,
        sortIndex: Int = 0,
        trip: Trip? = nil
    ) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.reasonKey = reasonKey
        self.quantity = quantity
        self.isCustom = isCustom
        self.sortIndex = sortIndex
        self.trip = trip
    }

    var category: PackingCategory {
        get { PackingCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}
