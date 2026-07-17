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
    @State private var showingAddItem = false
    @State private var showingReturnMode = false
    @State private var confirmReturnMode = false
    /// 進入回程模式前的已打包項目快照（誤觸時自動還原用）
    @State private var packedSnapshot: Set<UUID>?
    @State private var packToggle = false
    @State private var weather: WeatherSummary?

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
                        PackingListGenerator.sync(trip: trip, context: context, weatherTags: weather?.tags)
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
        .task(id: trip.id) {
            await refreshWeather()
        }
    }

    /// 抓目的地天氣，成功後以天氣標籤重新合併清單（離線自動退回月份規則），並讓小史萊姆播報
    private func refreshWeather() async {
        guard let summary = await WeatherService.fetch(for: trip) else { return }
        weather = summary
        PackingListGenerator.sync(trip: trip, context: context, weatherTags: summary.tags)
        WidgetSync.update(trip: trip)
        let contextual = MascotMessenger.message(
            for: trip,
            unpackedCount: (trip.packingItems ?? []).filter { !$0.isPacked }.count,
            weather: summary
        )
        if summary.rainDays > 0 {
            mascot.speak("查了\(summary.cityZh)天氣：\(summary.headline)。傘我加進清單了，記得帶", expression: .alert)
        } else {
            mascot.message = contextual.text
            mascot.expression = contextual.expression
        }
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
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "suitcase")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("產生專屬打包清單")
                        .font(.headline)
                    Text("每個項目都說明「因為是什麼」才建議帶。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("產生清單") {
                        PackingListGenerator.sync(trip: trip, context: context, weatherTags: weather?.tags)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
    }

    private var packingList: some View {
        List {
            if let weather {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: weather.rainDays > 0 ? "cloud.rain" : "sun.max")
                            .foregroundStyle(.tint)
                        Text("\(weather.cityZh) 旅行期間預報：\(weather.headline)")
                            .font(.footnote)
                        Spacer()
                        Text("Open-Meteo")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Section {
                PackingProgressHeader(items: items)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            ForEach(sections, id: \.reason) { section in
                Section(section.reason) {
                    ForEach(section.items) { item in
                        PackingItemRow(item: item) {
                            item.isPacked.toggle()
                            packToggle.toggle()
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            let item = section.items[index]
                            if !item.isCustom {
                                trip.excludePackingItem(named: item.name)
                            }
                            context.delete(item)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 進度

struct PackingProgressHeader: View {
    let items: [PackingItem]

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
            .tint(overall >= 1 ? .green : .blue)
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

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isPacked ? .green : .secondary)
                Text(item.name)
                    .strikethrough(item.isPacked)
                    .foregroundStyle(item.isPacked ? .secondary : .primary)
                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: item.category.symbolName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
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
