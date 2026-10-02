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
    @State private var increases: [PackingListGenerator.QuantityIncrease] = []
    @State private var reductions: [PackingListGenerator.QuantityReduction] = []
    @State private var removals: [PackingListGenerator.RemovalSuggestion] = []
    @State private var selectedReductions: Set<UUID> = []
    @State private var selectedIncreases: Set<UUID> = []
    @State private var selectedRemovals: Set<UUID> = []
    @State private var suggestionError: String?
    @State private var suggestionMessage: String?
    @AppStorage("packmon.packing.images") private var showImages = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var quantityEditor: PackingItem?

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
        .sheet(item: $quantityEditor) { PackingQuantityEditor(item: $0) }
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
                if trip.packingReviewPending {
                    Button(action: beginSuggestions) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                            VStack(alignment: .leading, spacing: 3) {
                                Text("行程設定已變更").font(.subheadline.weight(.bold))
                                Text("有打包建議尚未確認，點此檢視。")
                                    .font(.caption).foregroundStyle(theme.colors.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold))
                        }
                        .foregroundStyle(theme.colors.accent)
                        .padding(12)
                        .background(theme.colors.accentSoft, in: RoundedRectangle(cornerRadius: theme.radius.medium))
                    }.buttonStyle(.plain)
                }
                Button("更新打包建議", systemImage: "arrow.clockwise", action: beginSuggestions)
                    .buttonStyle(.bordered).tint(theme.colors.accent)
                if let suggestionMessage {
                    Text(suggestionMessage).font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            if !reviewingSuggestions {
            if showImages {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(items.filter(\.isPacked).count) / \(items.count) 項已打包").font(.subheadline.bold())
                    ProgressView(value: Double(items.filter(\.isPacked).count), total: Double(max(1, items.count)))
                        .tint(theme.colors.accent).accessibilityLabel("打包進度")
                }
                if let weather {
                    DisclosureGroup("建立時天氣") { PackingWeatherCard(weather: weather, saved: true) }
                        .font(.subheadline).tint(theme.colors.accent)
                }
            } else {
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
            }

            if !reviewingSuggestions {
                HStack(spacing: 12) {
                    HStack(spacing: 0) {
                        ForEach([false, true], id: \.self) { images in
                            Button { showImages = images } label: {
                                Text(images ? "圖片" : "文字").font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(showImages == images ? Color.white : theme.colors.secondaryText)
                                    .background(showImages == images ? theme.colors.accent : .clear, in: Capsule())
                            }.buttonStyle(.plain)
                                .accessibilityAddTraits(showImages == images ? .isSelected : [])
                        }
                    }.background(theme.colors.surface, in: Capsule())
                        .accessibilityElement(children: .contain).accessibilityLabel("打包呈現方式")
                    Button("新增物品", systemImage: "plus") { showingAddItem = true }
                        .font(.subheadline).fixedSize().tint(theme.colors.accent)
                }
            }
            if showImages && !reviewingSuggestions {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                        count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                    ForEach(items) { item in
                        PackingItemCard(item: item,
                            isStaple: PackingStaples.matchingItem(item, in: staples) != nil,
                            onToggle: { item.isPacked.toggle(); packToggle.toggle() },
                            onQuantity: { quantityEditor = item },
                            onStaple: { editStaple(item) },
                            onRemove: { pendingRemoval = item })
                    }
                }
            } else {
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
                            Button("修改數量", systemImage: "number") { quantityEditor = item }
                            Button("刪除", systemImage: "trash", role: .destructive) {
                                pendingRemoval = item
                            }
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
                Text("建議調整").font(.title3.bold())
                Spacer()
                Button("取消", action: cancelSuggestions).foregroundStyle(theme.colors.accent)
            }
            Text("新增與增加數量預設勾選；減量與移除預設不勾選。所有變更都只套用你確認的項目。")
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
                if candidates.isEmpty && increases.isEmpty && reductions.isEmpty && removals.isEmpty {
                    Label("目前沒有需要調整的物品", systemImage: "checkmark.circle")
                    Text("既有物品與先前排除的選擇都已保留。")
                        .font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                }
                if !candidates.isEmpty { Text("建議新增").font(.headline) }
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
                if !increases.isEmpty { Text("建議增加數量").font(.headline) }
                ForEach(increases) { item in
                    Button {
                        if selectedIncreases.contains(item.id) { selectedIncreases.remove(item.id) }
                        else { selectedIncreases.insert(item.id) }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: selectedIncreases.contains(item.id) ? "checkmark.square.fill" : "square")
                                .font(.title2).foregroundStyle(theme.colors.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.name).font(.body.weight(.semibold)).foregroundStyle(theme.colors.text)
                                Text("\(item.currentQuantity) → \(item.suggestedQuantity)・\(item.reason)")
                                    .font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                                if item.isPacked { Text("已打包，套用前請再次確認").font(.caption).foregroundStyle(.orange) }
                            }
                            Spacer(minLength: 0)
                        }.frame(minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain)
                    Divider().overlay(theme.colors.separator)
                }
                if !reductions.isEmpty { Text("可以減少數量").font(.headline) }
                ForEach(reductions) { item in
                    Button {
                        if selectedReductions.contains(item.id) { selectedReductions.remove(item.id) }
                        else { selectedReductions.insert(item.id) }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: selectedReductions.contains(item.id) ? "checkmark.square.fill" : "square")
                                .font(.title2).foregroundStyle(theme.colors.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.name).font(.body.weight(.semibold)).foregroundStyle(theme.colors.text)
                                Text("\(item.currentQuantity) → \(item.suggestedQuantity)・\(item.reason)")
                                    .font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                                if item.isPacked { Text("已打包，套用前請再次確認").font(.caption).foregroundStyle(.orange) }
                            }
                            Spacer(minLength: 0)
                        }.frame(minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain)
                    Divider().overlay(theme.colors.separator)
                }
                if !removals.isEmpty { Text("可能不需要").font(.headline) }
                ForEach(removals) { item in
                    Button {
                        if selectedRemovals.contains(item.id) { selectedRemovals.remove(item.id) }
                        else { selectedRemovals.insert(item.id) }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: selectedRemovals.contains(item.id) ? "checkmark.square.fill" : "square")
                                .font(.title2).foregroundStyle(theme.colors.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.name).font(.body.weight(.semibold)).foregroundStyle(theme.colors.text)
                                Text(item.reason).font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                                if item.isPacked { Text("已打包，套用後會從這趟清單移除").font(.caption).foregroundStyle(.orange) }
                            }
                            Spacer(minLength: 0)
                        }.frame(minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain)
                    Divider().overlay(theme.colors.separator)
                }
                if !candidates.isEmpty || !increases.isEmpty || !reductions.isEmpty || !removals.isEmpty {
                    Button("套用已選調整", action: applySuggestions)
                        .buttonStyle(PackmonPrimaryButtonStyle())
                        .disabled(selectedSuggestions.isEmpty && selectedIncreases.isEmpty && selectedReductions.isEmpty
                                  && selectedRemovals.isEmpty)
                }
            }
        }
        .padding(theme.spacing.medium)
        .background(theme.colors.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: theme.radius.large))
    }

    private func editStaple(_ item: PackingItem) {
        do {
            staples = try PackingStaples.load()
            if let existing = PackingStaples.matchingItem(item, in: staples) { stapleRemoval = existing }
            else { stapleEditor = .init(name: item.name, category: item.category,
                                      quantity: item.quantity, unitWeightKg: item.unitWeightKg) }
        } catch { stapleError = error.localizedDescription }
    }

    private func beginSuggestions() {
        cancelSuggestions()
        suggestionMessage = nil
        suggestionError = nil
        startSuggestionFetch()
    }

    private func startSuggestionFetch() {
        reviewingSuggestions = true
        guard trip.packingPreferencesRaw.isEmpty || trip.packingPreferences != nil,
              trip.packingWeatherRaw.isEmpty || trip.packingWeather != nil,
              trip.packingContextRaw.isEmpty || trip.packingContext != nil else {
            suggestionError = "行程推薦紀錄無法讀取，原有清單未變更。"; return
        }
        if let query = suggestionRequest {
            suggestionWeather = WeatherDraft()
            suggestionWeather.begin(query, debounce: .zero, fetch: WeatherService.fetch,
                fallback: { WeatherService.fallback($0, failure: $1) })
        } else { prepareSuggestions() }
    }

    private func prepareSuggestions() {
        let review = PackingListGenerator.review(for: trip,
            packingContext: trip.packingContext, weather: suggestionWeather.result)
        candidates = review.additions
        increases = review.increases
        reductions = review.reductions
        removals = review.removals
        selectedSuggestions = Set(candidates.map(\.id))
        selectedIncreases = Set(increases.map(\.id))
        selectedReductions = []
        selectedRemovals = []
    }

    private func cancelSuggestions() {
        suggestionWeather.cancel(); suggestionWeather = WeatherDraft()
        reviewingSuggestions = false
        candidates = []
        increases = []
        reductions = []
        removals = []
        selectedSuggestions = []
        selectedIncreases = []
        selectedReductions = []
        selectedRemovals = []
    }

    private func applySuggestions() {
        do {
            let result = try PackingListGenerator.applyReview(trip: trip,
                selectedAdditionIDs: selectedSuggestions,
                selectedIncreaseIDs: selectedIncreases,
                selectedReductionIDs: selectedReductions,
                selectedRemovalIDs: selectedRemovals,
                packingContext: trip.packingContext,
                weather: suggestionWeather.result,
                context: context)
            cancelSuggestions()
            let total = result.additions + result.increases + result.reductions + result.removals
            suggestionMessage = total == 0
                ? "已確認推薦設定，原有清單保持不變。"
                : "已新增 \(result.additions) 項、增量 \(result.increases) 項、減量 \(result.reductions) 項、移除 \(result.removals) 項。"
        } catch { suggestionError = "儲存失敗，尚未套用調整。請重試。" }
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
    @State private var duplicateName: String?

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
                    Button("加入", action: attemptAdd)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .alert("可能已經在清單中", isPresented: Binding(
            get: { duplicateName != nil },
            set: { if !$0 { duplicateName = nil } }
        )) {
            Button("仍然加入") { addAndDismiss() }
            Button("返回修改", role: .cancel) { duplicateName = nil }
        } message: {
            Text("「\(duplicateName ?? "這項物品")」和清單中的用品可能重複，請確認是否真的需要兩筆。")
        }
        .presentationDetents([.medium])
    }

    private func attemptAdd() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = PackingStaples.normalized(trimmed)
        let catalogID = PackingStaples.catalogID(for: trimmed)
        if let match = (trip.packingItems ?? []).first(where: {
            PackingStaples.normalized($0.name) == normalized
                || (catalogID != nil && ($0.catalogItemID == catalogID || PackingStaples.catalogID(for: $0.name) == catalogID))
        }) {
            duplicateName = match.name
        } else {
            addAndDismiss()
        }
    }

    private func addAndDismiss() {
        let item = PackingItem(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category, reasonKey: PackingListGenerator.customReason,
            quantity: quantity, isCustom: true, sortIndex: PackingListGenerator.customSortIndex, trip: trip)
        context.insert(item)
        dismiss()
    }
}
