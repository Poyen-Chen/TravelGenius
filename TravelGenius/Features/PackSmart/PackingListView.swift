//
//  PackingListView.swift
//  TravelGenius
//
//  物品 checklist：吉祥物情境提醒、偏好＋天氣客製清單、
//  回程模式防遺留。海關與文化內容在 Tips 分頁。
//

import SwiftUI
import SwiftData

struct PackingListView: View {
    let trip: Trip

    @Environment(\.modelContext) private var context
    @Environment(MascotState.self) private var mascot
    @Environment(\.packmonTheme) private var theme
    @State private var showingAddItem = false
    @State private var showingReturnMode = false
    @State private var confirmReturnMode = false
    /// 進入回程模式前的已打包項目快照（誤觸時自動還原用）
    @State private var packedSnapshot: Set<UUID>?
    @State private var packToggle = false
    private var weather: PackingWeather? { trip.packingWeather }
    @State private var pendingRemoval: PackingItem?
    @State private var staples: [PackingStaples.Item] = []
    @State private var stapleEditor: PackingStaples.Item?
    @State private var stapleRemoval: PackingStaples.Item?
    @State private var stapleError: String?

    private var items: [PackingItem] {
        (trip.packingItems ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    /// 依「因為是…」分組，段落順序 = 規則檔順序，自訂固定最後
    private var sections: [(reason: String, items: [PackingItem])] {
        let grouped = Dictionary(grouping: items) { $0.reasonKey }
        return grouped
            .map { (reason: $0.key, items: $0.value) }
            .sorted { ($0.items.first?.sortIndex ?? 0) < ($1.items.first?.sortIndex ?? 0) }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyGenerateView
            } else {
                packingList
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button("新增物品", systemImage: "plus") { showingAddItem = true }
                    Button("重新產生清單", systemImage: "arrow.clockwise") {
                        PackingListGenerator.sync(trip: trip, context: context)
                    }
                    Button("回程模式", systemImage: "arrow.uturn.left.circle") {
                        confirmReturnMode = true
                    }
                    if !items.isEmpty {
                        ShareLink(item: PackingShareText.make(for: trip)) {
                            Label("分享清單", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddItem) { AddPackingItemView(trip: trip) }
        .sheet(item: $stapleEditor) { item in PackingStapleEditor(draft: item, items: $staples) }
        .sheet(item: $stapleRemoval) { item in
            PackmonRemovalSheet(title: "移除常備用品？", name: item.name,
                message: "之後的新行程不再自動帶入；這趟與其他行程中的物品會保留。",
                actionTitle: "移除常備用品") {
                do {
                    let updated = try PackingStaples.load().filter { $0.id != item.id }
                    try PackingStaples.save(updated); staples = updated
                } catch { stapleError = error.localizedDescription }
            }
        }
        .alert("無法更新常備用品", isPresented: Binding(get: { stapleError != nil }, set: { if !$0 { stapleError = nil } })) {
            Button("好", role: .cancel) { stapleError = nil }
        } message: { Text(stapleError ?? "") }
        .onAppear {
            do { staples = try PackingStaples.load() }
            catch { stapleError = error.localizedDescription }
        }
        .sheet(item: $pendingRemoval) { item in
            PackmonRemovalSheet(title: "從這趟行程移除？", name: item.name,
                message: "只移除這趟行程的物品，不會更改你的常備用品或其他行程。",
                actionTitle: "移除物品") {
                if !item.isCustom || item.catalogItemID != nil { trip.excludePackingItem(item) }
                context.delete(item)
            }
        }
        .fullScreenCover(isPresented: $showingReturnMode, onDismiss: restoreIfUntouched) {
            ReturnModeView(trip: trip)
        }
        .confirmationDialog(
            "回程模式會將全部項目重設為未打包，用同一份清單反向檢查，避免把東西留在住宿處。",
            isPresented: $confirmReturnMode,
            titleVisibility: .visible
        ) {
            Button("重設並開始回程打包", role: .destructive) {
                packedSnapshot = Set((trip.packingItems ?? []).filter(\.isPacked).map(\.id))
                for item in (trip.packingItems ?? []) {
                    item.isPacked = false
                }
                showingReturnMode = true
            }
        }
        .sensoryFeedback(.impact, trigger: packToggle)
    }

    /// 回程模式關閉時，若完全沒有勾任何項目（視為誤觸），還原出發時的打包狀態
    private func restoreIfUntouched() {
        defer { packedSnapshot = nil }
        guard let snapshot = packedSnapshot, !snapshot.isEmpty else { return }
        let allItems = trip.packingItems ?? []
        guard allItems.allSatisfy({ !$0.isPacked }) else { return }
        for item in allItems where snapshot.contains(item.id) {
            item.isPacked = true
        }
    }

    private var emptyGenerateView: some View {
        VStack(spacing: 14) {
            Spacer()
            MascotView(size: 100)
            Text("產生專屬打包清單").font(.title3.weight(.black))
            Text("每個項目都會告訴你為什麼建議帶。")
                .font(.footnote).foregroundStyle(theme.colors.secondaryText)
            Button("產生清單") { PackingListGenerator.sync(trip: trip, context: context) }
                .buttonStyle(PackmonPrimaryButtonStyle()).padding(.horizontal, 32)
            Spacer()
        }
        .background(theme.colors.canvas)
    }

    private var packingList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
            if let weather {
                PackingWeatherCard(weather: weather, saved: true)
            } else {
                Text(trip.packingWeatherRaw.isEmpty
                     ? "這趟舊行程沒有建立時的天氣紀錄；開啟頁面不會自動更動清單。"
                     : "天氣紀錄無法讀取；原有清單保留，暫不重新產生。")
                    .font(.caption).foregroundStyle(theme.colors.secondaryText)
            }

            PackmonCard {
                PackingProgressHeader(items: items)
            }

            ForEach(sections, id: \.reason) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.reason)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.colors.secondaryText)
                    ForEach(section.items) { item in
                        HStack(spacing: 8) {
                            PackingItemRow(item: item) {
                                item.isPacked.toggle()
                                packToggle.toggle()
                            }
                            Button {
                                do {
                                    staples = try PackingStaples.load()
                                    if let existing = PackingStaples.matchingItem(item, in: staples) {
                                        stapleRemoval = existing
                                    } else {
                                        stapleEditor = .init(name: item.name, category: item.category,
                                            quantity: item.quantity, unitWeightKg: item.unitWeightKg)
                                    }
                                } catch { stapleError = error.localizedDescription }
                            } label: {
                                Image(systemName: PackingStaples.matchingItem(item, in: staples) == nil ? "star" : "star.fill")
                                    .foregroundStyle(theme.colors.accent).frame(width: 44, height: 44)
                            }.buttonStyle(.plain)
                             .accessibilityLabel("\(PackingStaples.matchingItem(item, in: staples) == nil ? "加入常備" : "移除常備")：\(item.name)")
                        }
                        .contextMenu {
                            Button("刪除", systemImage: "trash", role: .destructive) {
                                pendingRemoval = item
                            }
                        }
                    }
                }
            }
            }
            .padding(.horizontal, theme.spacing.medium)
            .padding(.bottom, 30)
        }
        .background(theme.colors.canvas)
    }
}

// MARK: - 進度

struct PackingProgressHeader: View {
    let items: [PackingItem]
    @Environment(\.packmonTheme) private var theme

    private var packedCount: Int { items.filter(\.isPacked).count }

    private var overall: Double {
        items.isEmpty ? 0 : Double(packedCount) / Double(items.count)
    }

    private var categories: [(category: PackingCategory, packed: Int, total: Int)] {
        PackingCategory.allCases.compactMap { category in
            let categoryItems = items.filter { $0.category == category }
            guard !categoryItems.isEmpty else { return nil }
            return (category, categoryItems.filter(\.isPacked).count, categoryItems.count)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Gauge(value: overall) {
                EmptyView()
            } currentValueLabel: {
                Text(overall, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(overall >= 1 ? theme.colors.success : theme.colors.secondaryAccent)
            .scaleEffect(1.15)
            .accessibilityLabel("打包進度 \(Int(overall * 100))%")

            VStack(alignment: .leading, spacing: 6) {
                Text(overall >= 1 ? "打包完成！" : "打包中・還剩 \(items.count - packedCount) 項")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 12) {
                    ForEach(categories, id: \.category) { entry in
                        VStack(spacing: 2) {
                            Image(systemName: entry.category.symbolName)
                                .font(.caption)
                                .foregroundStyle(entry.packed == entry.total ? .green : .secondary)
                            Text("\(entry.packed)/\(entry.total)")
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.category.label) \(entry.packed) / \(entry.total)")
                    }
                }
            }
            Spacer()
        }
    }
}

// MARK: - 清單列

struct PackingItemRow: View {
    let item: PackingItem
    var onToggle: () -> Void
    @Environment(\.packmonTheme) private var theme

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isPacked ? theme.colors.success : theme.colors.secondaryText)
                Text(item.name)
                    .strikethrough(item.isPacked)
                    .foregroundStyle(item.isPacked ? .secondary : .primary)
                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let weight = item.unitWeightKg {
                    Text("\(weight.formatted()) kg／件").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: item.category.symbolName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .background(theme.colors.elevatedSurface, in: RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: theme.radius.medium).stroke(theme.colors.separator, lineWidth: 0.75) }
        .accessibilityLabel("\(item.name)\(item.isPacked ? "，已打包" : "，未打包")")
    }
}

// MARK: - 新增物品

struct AddPackingItemView: View {
    let trip: Trip

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: PackingCategory = .other
    @State private var quantity = 1

    var body: some View {
        NavigationStack {
            Form {
                TextField("物品名稱", text: $name)
                Picker("分類", selection: $category) {
                    ForEach(PackingCategory.allCases) { category in
                        Label(category.label, systemImage: category.symbolName).tag(category)
                    }
                }
                Stepper("數量：\(quantity)", value: $quantity, in: 1...99)
            }
            .navigationTitle("新增物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入") {
                        let item = PackingItem(
                            name: name.trimmingCharacters(in: .whitespaces),
                            category: category,
                            reasonKey: PackingListGenerator.customReason,
                            quantity: quantity,
                            isCustom: true,
                            sortIndex: PackingListGenerator.customSortIndex,
                            trip: trip
                        )
                        context.insert(item)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
