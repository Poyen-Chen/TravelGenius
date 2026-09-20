//
//  PackingLibraryView.swift
//  TravelGenius
//
//  「我的行李庫」：跨行程累積的個人物品。可標記每趟必帶、調整單件重量、刪除。
//

import SwiftUI
import SwiftData

struct PackingLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\PackingLibraryItem.useCount, order: .reverse),
                  SortDescriptor(\PackingLibraryItem.name)])
    private var items: [PackingLibraryItem]

    private var essentials: [PackingLibraryItem] { items.filter(\.isEssential) }
    private var others: [PackingLibraryItem] { items.filter { !$0.isEssential } }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                List {
                    if !essentials.isEmpty {
                        Section {
                            ForEach(essentials) { row($0) }
                                .onDelete { delete($0, from: essentials) }
                        } header: {
                            Text("每趟必帶")
                        } footer: {
                            Text("建立新行程時會自動加入清單。")
                        }
                    }
                    Section {
                        ForEach(others) { row($0) }
                            .onDelete { delete($0, from: others) }
                    } header: {
                        Text(essentials.isEmpty ? "我的物品" : "其他物品")
                    } footer: {
                        Text("你每次新增的自訂項目都會收進這裡，帶得越多次排越前面。")
                    }
                }
            }
        }
        .navigationTitle("我的行李庫")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("行李庫是空的", systemImage: "bag")
        } description: {
            Text("在打包清單裡新增自訂項目，就會自動收進這裡，下次旅行不用重打一次。")
        }
    }

    private func row(_ item: PackingLibraryItem) -> some View {
        HStack {
            Image(systemName: item.category.symbolName)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                Text(subtitle(for: item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                item.isEssential.toggle()
            } label: {
                Image(systemName: item.isEssential ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.isEssential ? "取消每趟必帶：\(item.name)" : "設為每趟必帶：\(item.name)")
        }
    }

    private func subtitle(for item: PackingLibraryItem) -> String {
        var parts = [item.category.label]
        parts.append("帶過 \(item.useCount) 次")
        if item.weightGrams > 0 { parts.append("\(item.weightGrams) g") }
        return parts.joined(separator: "・")
    }

    private func delete(_ offsets: IndexSet, from source: [PackingLibraryItem]) {
        for index in offsets { context.delete(source[index]) }
    }
}
