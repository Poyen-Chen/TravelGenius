//
//  PackingLibrary.swift
//  TravelGenius
//
//  個人行李庫的讀寫。所有自訂項目都經由 record 收錄，重複名稱只累加使用次數。
//

import Foundation
import SwiftData

enum PackingLibrary {
    /// 收錄一個自訂項目。同名（正規化後）視為同一件，只累加使用次數與更新時間。
    /// - Returns: 對應的庫存項目，呼叫端不需要時可忽略。
    @discardableResult
    @MainActor
    static func record(
        name: String,
        category: PackingCategory,
        weightGrams: Int = 0,
        in context: ModelContext
    ) -> PackingLibraryItem? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let existing = find(normalizedName: PackingLibraryItem.normalize(trimmed), in: context) {
            existing.useCount += 1
            existing.lastUsedAt = .now
            // 使用者這次填了重量就更新，沒填不要把既有值蓋成 0
            if weightGrams > 0 { existing.weightGrams = weightGrams }
            return existing
        }

        let item = PackingLibraryItem(name: trimmed, category: category, weightGrams: weightGrams)
        context.insert(item)
        return item
    }

    /// 標記為「每趟必帶」的項目，依常用度排序。
    @MainActor
    static func essentials(in context: ModelContext) -> [PackingLibraryItem] {
        let descriptor = FetchDescriptor<PackingLibraryItem>(
            predicate: #Predicate { $0.isEssential },
            sortBy: [SortDescriptor(\.useCount, order: .reverse), SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 全部項目，常用的排前面。
    @MainActor
    static func all(in context: ModelContext) -> [PackingLibraryItem] {
        let descriptor = FetchDescriptor<PackingLibraryItem>(
            sortBy: [SortDescriptor(\.useCount, order: .reverse), SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    static func find(normalizedName: String, in context: ModelContext) -> PackingLibraryItem? {
        var descriptor = FetchDescriptor<PackingLibraryItem>(
            predicate: #Predicate { $0.normalizedName == normalizedName }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// 把「每趟必帶」的項目加進行程清單。已存在同名項目就跳過，不覆蓋使用者的調整。
    @MainActor
    static func applyEssentials(to trip: Trip, in context: ModelContext) {
        let existing = Set((trip.packingItems ?? []).map { PackingLibraryItem.normalize($0.name) })
        var sortIndex = PackingListGenerator.customSortIndex
        for libraryItem in essentials(in: context) where !existing.contains(libraryItem.normalizedName) {
            let item = PackingItem(
                name: libraryItem.name,
                category: libraryItem.category,
                reasonKey: PackingListGenerator.libraryEssentialReason,
                quantity: 1,
                isCustom: true,
                sortIndex: sortIndex,
                trip: trip
            )
            if libraryItem.weightGrams > 0 { item.weightGrams = libraryItem.weightGrams }
            context.insert(item)
            libraryItem.useCount += 1
            libraryItem.lastUsedAt = .now
            sortIndex += 1
        }
    }
}
