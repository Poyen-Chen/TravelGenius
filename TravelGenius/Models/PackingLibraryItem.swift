//
//  PackingLibraryItem.swift
//  TravelGenius
//
//  個人行李庫：跨行程累積的物品。自訂項目只活在單一行程裡，累積不出個人特色，
//  所以每次新增自訂項目都收進這裡，記住名稱、分類、重量與使用次數。
//  標記「每趟必帶」的項目，建立新行程時會自動帶入。
//
//  CloudKit 相容性：所有屬性都有預設值、沒有 @Attribute(.unique)、關聯為 optional。
//  去重靠 normalizedName 比對，不靠資料庫唯一性約束。
//

import Foundation
import SwiftData

@Model
final class PackingLibraryItem {
    var id: UUID = UUID()
    var name: String = ""
    /// 比對用的正規化名稱（去空白、小寫）。CloudKit 不支援唯一性約束，改在寫入前自行比對。
    var normalizedName: String = ""
    var categoryRaw: String = PackingCategory.other.rawValue
    /// 單件重量，0 代表沿用分類預設值
    var weightGrams: Int = 0
    /// 每趟必帶：建立新行程時自動加入清單
    var isEssential: Bool = false
    /// 被帶上幾趟旅程，用於排序「常用」
    var useCount: Int = 1
    var lastUsedAt: Date = Date()
    var createdAt: Date = Date()

    init(
        name: String,
        category: PackingCategory,
        weightGrams: Int = 0,
        isEssential: Bool = false
    ) {
        self.name = name
        self.normalizedName = Self.normalize(name)
        self.categoryRaw = category.rawValue
        self.weightGrams = weightGrams
        self.isEssential = isEssential
    }

    var category: PackingCategory {
        get { PackingCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// 改名時要一併更新比對用名稱，否則去重會失效
    func rename(to newName: String) {
        name = newName
        normalizedName = Self.normalize(newName)
    }

    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
