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
    @State private var showingPackingImage = false
    @State private var showingSuitcaseLayout = false
    @State private var didAutoOpenPackingImage = false
    @State private var didAutoOpenSuitcase = false
    @State private var editingWeightItem: PackingItem?
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
                        Button("生成打包圖", systemImage: "photo.on.rectangle.angled") {
                            showingPackingImage = true
                        }
                        Button("行李箱擺位", systemImage: "camera.viewfinder") {
                            showingSuitcaseLayout = true
                        }
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
        .sheet(isPresented: $showingPackingImage) { PackingImageView(trip: trip) }
        .sheet(isPresented: $showingSuitcaseLayout) { SuitcaseLayoutView(trip: trip) }
        .sheet(item: $editingWeightItem) { WeightEditSheet(item: $0) }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if !didAutoOpenPackingImage, args.contains("-openPackingImage") {
                didAutoOpenPackingImage = true
                Task {
                    try? await Task.sleep(for: .seconds(15)) // 讓啟動時的天氣重算先完成
                    showingPackingImage = true
                }
            }
            if !didAutoOpenSuitcase, args.contains("-openSuitcaseLayout") {
                didAutoOpenSuitcase = true
                Task {
                    try? await Task.sleep(for: .seconds(8))
                    showingSuitcaseLayout = true
                }
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

            Section {
                WeightSummaryHeader(items: items, trip: trip)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            ForEach(sections, id: \.reason) { section in
                Section(section.reason) {
                    ForEach(section.items) { item in
                        PackingItemRow(item: item) {
                            item.isPacked.toggle()
                            packToggle.toggle()
                        }
                        .contextMenu {
                            Button("調整重量", systemImage: "scalemass") {
                                editingWeightItem = item
                            }
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
                Text(PackingWeight.format(grams: item.estimatedTotalGrams))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(item.weightGrams > 0 ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                Image(systemName: item.category.symbolName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name)\(item.isPacked ? "，已打包" : "，未打包")，約 \(PackingWeight.format(grams: item.estimatedTotalGrams))")
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

// MARK: - 行李重量摘要（估算總重、預警超重）

struct WeightSummaryHeader: View {
    let items: [PackingItem]
    @Bindable var trip: Trip

    private static let allowancePresets: [Double] = [7, 10, 20, 23, 30]

    private var totalGrams: Int { items.reduce(0) { $0 + $1.estimatedTotalGrams } }
    private var totalKg: Double { Double(totalGrams) / 1000 }
    private var allowance: Double { trip.baggageAllowanceKg }
    private var ratio: Double { allowance <= 0 ? 0 : totalKg / allowance }

    private var tint: Color {
        if ratio > 1 { return .red }
        if ratio > 0.85 { return .orange }
        return .green
    }

    private var statusText: String {
        if ratio > 1 { return String(format: "超重 %.1f kg，建議減量", totalKg - allowance) }
        if ratio > 0.85 { return "接近上限，別再加太多" }
        return "重量充裕"
    }

    private var heaviest: [PackingItem] {
        Array(items.sorted { $0.estimatedTotalGrams > $1.estimatedTotalGrams }.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("預估行李重量")
                        .font(.subheadline.weight(.semibold))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", totalKg))
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(tint)
                        Text("kg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Menu {
                            Picker("行李限重", selection: $trip.baggageAllowanceKg) {
                                ForEach(Self.allowancePresets, id: \.self) { kg in
                                    Text(kg == 7 ? "7 kg（隨身）" : "\(Int(kg)) kg").tag(kg)
                                }
                            }
                        } label: {
                            Text("/ \(Int(allowance)) kg 上限")
                                .font(.caption)
                                .foregroundStyle(.tint)
                        }
                    }
                }
                Spacer()
                Image(systemName: ratio > 1 ? "exclamationmark.triangle.fill" : "suitcase.rolling")
                    .font(.title3)
                    .foregroundStyle(tint)
            }

            ProgressView(value: min(ratio, 1))
                .tint(tint)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(tint)

            if ratio > 0.85, !heaviest.isEmpty {
                Text("最重：" + heaviest.map { "\($0.name) \(PackingWeight.format(grams: $0.estimatedTotalGrams))" }.joined(separator: "、"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("重量為估計值，長按項目可調整")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - 單件重量調整

struct WeightEditSheet: View {
    @Bindable var item: PackingItem

    @Environment(\.dismiss) private var dismiss
    @State private var grams: Int = 0

    private var estimate: Int { PackingWeight.grams(for: item) }
    private var effectiveUnit: Int { grams > 0 ? grams : estimate }

    var body: some View {
        NavigationStack {
            Form {
                Section("單件重量") {
                    Stepper(value: $grams, in: 0...5000, step: 10) {
                        if grams > 0 {
                            Text("\(grams) g").monospacedDigit()
                        } else {
                            Text("用估計值（約 \(estimate) g）")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if grams > 0 {
                        Button("改用估計值") { grams = 0 }
                    }
                }
                if item.quantity > 1 {
                    Section("總重") {
                        Text("×\(item.quantity) = 約 \(PackingWeight.format(grams: effectiveUnit * item.quantity))")
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        item.weightGrams = grams
                        dismiss()
                    }
                }
            }
            .onAppear { grams = item.weightGrams }
        }
        .presentationDetents([.medium])
    }
}
