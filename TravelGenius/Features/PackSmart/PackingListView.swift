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
    @State private var reviewingSuggestions = false
    @State private var suggestionWeather = WeatherDraft()
    @State private var candidates: [PackingListGenerator.GeneratedItem] = []
    @State private var selectedSuggestions: Set<String> = []
    @State private var suggestionError: String?
    @State private var suggestionMessage: String?

    private var suggestionRequest: WeatherRequest? {
        StaticDataStore.shared.cities.first { $0.countryCode == trip.countryCode && $0.cityZh == trip.city }
            .flatMap { WeatherService.request(city: $0, start: trip.startDate, end: trip.endDate) }
    }

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
            if items.isEmpty && !reviewingSuggestions {
                emptyGenerateView
            } else {
                packingList
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button("新增物品", systemImage: "plus") { showingAddItem = true }
                    Button("更新打包建議", systemImage: "arrow.clockwise", action: beginSuggestions)
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
        .onChange(of: suggestionWeather.result) { _, value in
            guard reviewingSuggestions, value != nil else { return }
            prepareSuggestions()
        }
        .onDisappear { cancelSuggestions() }
        .onChange(of: suggestionRequest) { _, _ in cancelSuggestions() }
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
            Button("查看打包建議", action: beginSuggestions)
                .buttonStyle(PackmonPrimaryButtonStyle()).padding(.horizontal, 32)
            Spacer()
        }
        .background(theme.colors.canvas)
    }

    private var packingList: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
            if reviewingSuggestions {
                suggestionPanel.id("suggestions")
                Text("原有清單").font(.headline)
            } else {
                Button("更新打包建議", systemImage: "arrow.clockwise", action: beginSuggestions)
                    .buttonStyle(.bordered).tint(theme.colors.accent)
                if let suggestionMessage {
                    Text(suggestionMessage).font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            if !reviewingSuggestions {
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
        .onChange(of: reviewingSuggestions) { _, open in
            if open { withAnimation { proxy.scrollTo("suggestions", anchor: .top) } }
        }
        }
    }

    private var suggestionPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("建議補入").font(.title3.bold())
                Spacer()
                Button("取消", action: cancelSuggestions).foregroundStyle(theme.colors.accent)
            }
            Text("只加入勾選項目，原有清單不變。")
                .font(.subheadline).foregroundStyle(theme.colors.secondaryText)
            if suggestionWeather.loading {
                ProgressView("正在確認天氣與建議…")
                Button("先用季節參考") {
                    if let query = suggestionRequest {
                        suggestionWeather.useFallback(WeatherService.fallback(query, failure: .skipped))
                    }
                }.foregroundStyle(theme.colors.accent)
            } else if let suggestionError {
                Text(suggestionError).font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                Button("重試", action: beginSuggestions).buttonStyle(.bordered)
            } else {
                Text(suggestionWeather.result.map { "本次參考：\($0.coverageLabel)" }
                     ?? "本次依保存的行程資料建議，未取得新的天氣預報。")
                    .font(.caption).foregroundStyle(theme.colors.secondaryText)
                if let reference = suggestionWeather.result {
                    DisclosureGroup("本次天氣依據") {
                        PackingWeatherCard(weather: reference)
                    }.font(.subheadline).tint(theme.colors.accent)
                }
                if candidates.isEmpty {
                    Label("目前沒有需要補入的物品", systemImage: "checkmark.circle")
                    Text("既有物品與先前排除的選擇都已保留。")
                        .font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                }
                ForEach(candidates) { item in
                    Button {
                        if selectedSuggestions.contains(item.id) { selectedSuggestions.remove(item.id) }
                        else { selectedSuggestions.insert(item.id) }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: selectedSuggestions.contains(item.id) ? "checkmark.square.fill" : "square")
                                .font(.title2).foregroundStyle(theme.colors.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.name).font(.body.weight(.semibold)).foregroundStyle(theme.colors.text)
                                Text(item.reason).font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                            }
                            Spacer(minLength: 4)
                            Text("×\(item.quantity)").foregroundStyle(theme.colors.secondaryText)
                        }.frame(minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain)
                        .accessibilityLabel("\(item.name)，\(item.quantity) 件，\(selectedSuggestions.contains(item.id) ? "已選擇" : "未選擇")")
                    Divider().overlay(theme.colors.separator)
                }
                if !candidates.isEmpty {
                    Button("加入 \(selectedSuggestions.count) 項物品", action: applySuggestions)
                        .buttonStyle(PackmonPrimaryButtonStyle())
                        .disabled(selectedSuggestions.isEmpty)
                }
            }
        }
        .padding(theme.spacing.medium)
        .background(theme.colors.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: theme.radius.large))
    }

    private func beginSuggestions() {
        cancelSuggestions()
        reviewingSuggestions = true; suggestionMessage = nil; suggestionError = nil
        guard trip.packingPreferencesRaw.isEmpty || trip.packingPreferences != nil,
              trip.packingWeatherRaw.isEmpty || trip.packingWeather != nil else {
            suggestionError = "行程推薦紀錄無法讀取，原有清單未變更。"; return
        }
        if let query = suggestionRequest {
            suggestionWeather = WeatherDraft()
            suggestionWeather.begin(query, debounce: .zero, fetch: WeatherService.fetch,
                fallback: { WeatherService.fallback($0, failure: $1) })
        } else { prepareSuggestions() }
    }

    private func prepareSuggestions() {
        candidates = PackingListGenerator.missingItems(for: trip, weather: suggestionWeather.result)
        selectedSuggestions = Set(candidates.map(\.id))
    }

    private func cancelSuggestions() {
        suggestionWeather.cancel(); suggestionWeather = WeatherDraft()
        reviewingSuggestions = false; candidates = []; selectedSuggestions = []
    }

    private func applySuggestions() {
        do {
            let count = try PackingListGenerator.addMissing(trip: trip, selectedIDs: selectedSuggestions,
                weather: suggestionWeather.result, context: context)
            cancelSuggestions()
            suggestionMessage = count == 0 ? "沒有新增物品，原有清單保持不變。" : "已加入 \(count) 項物品，原有清單已保留。"
        } catch { suggestionError = "儲存失敗，尚未加入物品。請重試。" }
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
