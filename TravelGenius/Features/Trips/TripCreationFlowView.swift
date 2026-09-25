import SwiftUI
import SwiftData

struct TripCreationFlowView: View {
    @Binding var createdTrip: Trip?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.packmonTheme) private var theme
    @Environment(AppState.self) private var appState

    @State private var countryCode = ""
    @State private var cityName = ""
    @State private var startDate = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var step = 1
    @State private var name = ""
    @State private var workingTrip: Trip?
    @State private var recommendations: [PackingListGenerator.GeneratedItem] = []
    @State private var excludedIDs: Set<String> = []
    @State private var customItems: [CreationCustomItem] = []
    @State private var showingAddItem = false
    @State private var confirmDiscard = false
    @State private var saveFailed = false
    @State private var isSaving = false
    @State private var didSave = false
    @State private var creationPreferences = UserPreferences.forNewTrips()
    @State private var packingContext = TripPackingContext.empty
    @State private var showingPackingOptions = true
    @State private var loadedStaples = false
    @State private var stapleLoadError = false
    @State private var weatherDraft = WeatherDraft()
    @State private var previewWeather: PackingWeather?

    private var weatherRequest: WeatherRequest? {
        selectedCity.flatMap { WeatherService.request(city: $0, start: startDate, end: endDate) }
    }
    private var readyWeather: PackingWeather? {
        guard let query = weatherRequest, weatherDraft.request == query,
              let result = weatherDraft.result, result.request == query, result.valid else { return nil }
        return result
    }

    private var selectedCity: City? {
        StaticDataStore.shared.cities(countryCode: countryCode).first { $0.cityZh == cityName }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("步驟 \(step)／3・\(["基本資訊", "確認推薦清單", "海關與航空提醒"][step - 1])")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ProgressView(value: Double(step), total: 3).tint(theme.colors.accent)
                }.padding(theme.spacing.medium)
                if step == 3, let workingTrip {
                    List {
                        Section {
                            Text("以下為已收錄的參考提醒，不是完整通關檢查；未收錄不代表可攜帶，請以官方最新公告為準。")
                        }
                        ProhibitedSections(trip: workingTrip, mode: .customs)
                        ProhibitedSections(trip: workingTrip, mode: .aviation)
                    }.scrollContentBackground(.hidden)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: theme.spacing.large) {
                            if step == 1 {
                                destinationSection
                                dateSection
                                weatherSection
                                packingOptionsSection
                            } else {
                                if let previewWeather { PackingWeatherCard(weather: previewWeather) }
                                recommendationSection
                            }
                        }.padding(theme.spacing.medium)
                    }.id(step)
                }
            }
            .safeAreaInset(edge: .bottom) { actionBar }
            .background(theme.colors.canvas.ignoresSafeArea())
            .navigationTitle("新行程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { confirmDiscard = true }.disabled(isSaving)
                }
            }
            .onChange(of: startDate) { _, value in if endDate < value { endDate = value } }
            .task(id: weatherRequest) {
                guard step == 1 else { return }
                weatherDraft.begin(weatherRequest, fetch: WeatherService.fetch,
                    fallback: { WeatherService.fallback($0, failure: $1) })
            }
            .onDisappear { weatherDraft.cancel() }
            .onAppear {
                guard !loadedStaples else { return }
                do {
                    customItems = try PackingStaples.load().map {
                        CreationCustomItem(name: $0.name, category: $0.category, quantity: $0.quantity, isStaple: true, unitWeightKg: $0.unitWeightKg)
                    }
                    loadedStaples = true
                } catch { stapleLoadError = true }
            }
            .alert("無法讀取常備用品", isPresented: $stapleLoadError) {
                Button("好", role: .cancel) {}
            } message: { Text("請關閉後重試。原有資料未被覆寫，也不會略過你的常備用品建立行程。") }
            .interactiveDismissDisabled()
            .confirmationDialog("放棄建立這趟行程？", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("放棄建立", role: .destructive) { dismiss() }
                Button("繼續編輯", role: .cancel) {}
            } message: { Text("尚未建立行程，離開後不會保留目前輸入。") }
            .sheet(isPresented: $showingAddItem) {
                CreationCustomItemForm(items: $customItems, recommendationNames: Set(recommendations.map(\.name)))
            }
            .alert("未能儲存行程", isPresented: $saveFailed) {
                Button("好", role: .cancel) {}
            } message: { Text("目前輸入仍保留，請稍後再試。") }
        }
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("想去哪裡？", subtitle: "先選國家／地區，再選一個城市")
            Text("1. 國家／地區").font(.subheadline.weight(.semibold))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(StaticDataStore.shared.destinationCountries) { country in
                    selectionChip("\(country.flagEmoji) \(country.nameZh)", isSelected: countryCode == country.code) {
                        if countryCode != country.code {
                            countryCode = country.code
                            cityName = ""
                        }
                    }
                }
            }
            if !countryCode.isEmpty {
                Text("2. 城市").font(.subheadline.weight(.semibold))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                    ForEach(StaticDataStore.shared.cities(countryCode: countryCode)) { city in
                        selectionChip(city.cityZh, isSelected: cityName == city.cityZh) {
                            cityName = city.cityZh
                        }
                    }
                }
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("什麼時候出發？", subtitle: "共 \(tripDays) 天")
            PackmonCard {
                VStack(spacing: 12) {
                    DatePicker("出發", selection: $startDate, displayedComponents: .date)
                    Divider().overlay(theme.colors.separator)
                    DatePicker("回程", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }
        }
    }

    private var packingOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("這趟怎麼準備？", subtitle: "先沿用全域設定；這裡的調整只影響這趟行程")
            PackmonCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("出發地：台灣").font(.subheadline.weight(.semibold))
                    TextField("行程名稱（留空使用城市名）", text: $name)
                    DisclosureGroup(isExpanded: $showingPackingOptions) {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("打包風格").font(.subheadline.weight(.semibold))
                            Picker("打包風格", selection: $creationPreferences.packingStyle) {
                                ForEach(PackingStyle.allCases) { Text($0 == .full ? "準備齊全" : $0.label).tag($0) }
                            }.pickerStyle(.segmented).labelsHidden()

                            packingOptionGrid("這趟會帶的設備", options: PersonalPackingOptions.devices,
                                selected: creationPreferences.devices ?? []) { togglePersonalOption($0, devices: true) }
                            packingOptionGrid("這趟常備需求", options: PersonalPackingOptions.needs,
                                selected: creationPreferences.needs ?? []) { togglePersonalOption($0, devices: false) }

                            Text("活動（可複選）").font(.subheadline.weight(.semibold))
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 8)], spacing: 8) {
                                ForEach(PackingActivity.allCases) { activity in
                                    selectionChip(activity.label, isSelected: packingContext.activities.contains(activity)) {
                                        toggle(activity, in: &packingContext.activities)
                                        if !packingContext.activities.contains(.snow) { packingContext.snowPlan = .unknown }
                                    }
                                }
                            }
                            if packingContext.activities.contains(.snow) {
                                Picker("雪地安排", selection: $packingContext.snowPlan) {
                                    ForEach(PackingSnowPlan.allCases) { Text($0.label).tag($0) }
                                }
                            }

                            Text("住宿（可複選）").font(.subheadline.weight(.semibold))
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 8)], spacing: 8) {
                                ForEach(PackingStay.allCases) { stay in
                                    selectionChip(stay.label, isSelected: packingContext.stays.contains(stay)) {
                                        toggle(stay, in: &packingContext.stays)
                                    }
                                }
                            }

                            Picker("途中洗衣", selection: $packingContext.laundry) {
                                ForEach(PackingLaundryPlan.allCases) { Text($0.label).tag($0) }
                            }
                            Text("住宿用品只會以『請確認是否提供』方式建議；不會因住宿類型自動刪除用品。")
                                .font(.caption).foregroundStyle(theme.colors.secondaryText)
                        }.padding(.top, 12)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("本次打包設定").font(.subheadline.weight(.semibold))
                            Text("\(creationPreferences.summary)・\(packingContext.summary)")
                                .font(.caption).foregroundStyle(theme.colors.secondaryText)
                        }
                    }.tint(theme.colors.accent)
                }
            }
        }
    }

    private func packingOptionGrid(
        _ title: String,
        options: [PersonalPackingOptions.Option],
        selected: [String],
        toggle: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 8)], spacing: 8) {
                ForEach(options) { option in
                    selectionChip(option.label, isSelected: selected.contains(option.id)) { toggle(option.id) }
                }
            }
        }
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("決定要帶哪些物品", subtitle: "勾選代表加入清單，不代表已經打包。")
            Text("採納 \(recommendations.filter { !excludedIDs.contains($0.id) }.count)／\(recommendations.count) 項推薦")
            ForEach(recommendations) { item in
                PackmonCard {
                    Toggle(isOn: Binding(get: { !excludedIDs.contains(item.id) }, set: { included in
                        if included { excludedIDs.remove(item.id) } else { excludedIDs.insert(item.id) }
                    })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(item.name) ×\(item.quantity)")
                            Text(item.reason).font(.caption).foregroundStyle(theme.colors.secondaryText)
                        }
                    }
                    .tint(theme.colors.accent)
                    .accessibilityLabel("加入清單：\(item.name)，\(item.quantity) 件")
                }
            }
            Text("常備與自訂用品").font(.headline)
            Text("常備用品只複製到這趟行程；在這裡移除不會更改常備清單。")
                .font(.caption).foregroundStyle(theme.colors.secondaryText)
            ForEach(customItems) { item in
                HStack {
                    Text("\(item.isStaple ? "常備・" : "")\(item.name) ×\(item.quantity)")
                    Spacer()
                    Button {
                        if item.isStaple, let catalogID = PackingStaples.catalogID(for: item.name) {
                            excludedIDs.insert(catalogID)
                        }
                        customItems.removeAll { $0.id == item.id }
                    } label: {
                        Label("移除", systemImage: "minus.circle")
                    }.accessibilityLabel("移除自訂用品：\(item.name)")
                }
            }
            Button("新增自訂用品", systemImage: "plus.circle") { showingAddItem = true }
                .frame(minHeight: 44)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if step > 1 {
                Button("上一步") { step -= 1 }.frame(minWidth: 64, minHeight: 48)
            }
            Button(step == 1 ? "下一步：確認清單" : step == 2 ? "下一步：旅行提醒" : "完成建立，開始打包") {
                if step == 1 {
                    guard let weather = readyWeather else { return }
                    weatherDraft.cancel()
                    previewWeather = weather
                    let trip = makeTrip()
                    trip.packingWeather = weather
                    workingTrip = trip
                    recommendations = PackingListGenerator.generate(for: trip).filter { recommendation in
                        !customItems.contains { item in
                            item.isStaple && PackingStaples.matches(
                                .init(name: item.name, category: item.category, quantity: item.quantity),
                                recommendation: recommendation)
                        }
                    }
                    step = 2
                } else if step == 2 {
                    step = 3
                } else { createTrip() }
            }
            .buttonStyle(PackmonPrimaryButtonStyle())
            .disabled(selectedCity == nil || isSaving || !loadedStaples || (step == 1 && readyWeather == nil))
        }
        .disabled(isSaving || didSave)
        .padding(theme.spacing.medium)
        .background(theme.colors.canvas)
    }

    @ViewBuilder
    private var weatherSection: some View {
        if let result = readyWeather {
            PackingWeatherCard(weather: result)
            Text("若返回修改城市或日期，推薦將依新條件更新；已排除項目與自訂用品會保留。")
                .font(.caption).foregroundStyle(theme.colors.secondaryText)
        } else if let query = weatherRequest, !query.dates.isEmpty {
            PackmonCard {
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView("正在查詢目的地天氣…")
                    Text("最多等待 10 秒；也可以先用季節參考建立清單。")
                        .font(.caption).foregroundStyle(theme.colors.secondaryText)
                    Button("使用季節參考繼續") {
                        weatherDraft.useFallback(WeatherService.fallback(query, failure: .skipped))
                    }.frame(minHeight: 44)
                }
            }
        } else if selectedCity != nil {
            Text("日期範圍或城市時區無法辨識，請調整日期後再試。")
                .font(.caption).foregroundStyle(theme.colors.secondaryText)
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.weight(.black)).foregroundStyle(theme.colors.text)
            Text(subtitle).font(.caption).foregroundStyle(theme.colors.secondaryText)
        }
    }

    private func selectionChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected { Image(systemName: "checkmark") }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : theme.colors.text)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(isSelected ? theme.colors.accent : theme.colors.elevatedSurface, in: Capsule())
            .overlay { if !isSelected { Capsule().stroke(theme.colors.separator, lineWidth: 0.75) } }
        }.buttonStyle(.plain)
    }

    private func togglePersonalOption(_ id: String, devices: Bool) {
        var values = devices ? (creationPreferences.devices ?? []) : (creationPreferences.needs ?? [])
        if let index = values.firstIndex(of: id) { values.remove(at: index) }
        else { values.append(id) }
        if devices { creationPreferences.devices = values }
        else { creationPreferences.needs = values }
    }

    private func toggle<Value: Equatable>(_ value: Value, in values: inout [Value]) {
        if let index = values.firstIndex(of: value) { values.remove(at: index) }
        else { values.append(value) }
    }

    private var tripDays: Int {
        max((Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: Calendar.current.startOfDay(for: endDate)).day ?? 0) + 1, 1)
    }

    private func makeTrip() -> Trip {
        let country = StaticDataStore.shared.country(code: countryCode)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trip = Trip(
            name: trimmedName.isEmpty ? cityName : trimmedName,
            countryCode: countryCode,
            startDate: startDate,
            endDate: endDate,
            homeCurrencyCode: "TWD",
            localCurrencyCode: country?.currencyCode ?? "TWD",
            totalBudget: 0,
            tripType: .leisure
        )
        trip.city = cityName
        trip.originCountryCode = "TW"
        trip.originCity = ""
        trip.capturePackingPreferencesIfNeeded(creationPreferences)
        trip.capturePackingContextIfNeeded(packingContext)
        return trip
    }

    private func createTrip() {
        guard selectedCity != nil, !isSaving, !didSave,
              let previewWeather, previewWeather.request == weatherRequest else { return }
        isSaving = true
        defer { isSaving = false }
        // Isolated save context: failure rollback must not discard other screens' edits.
        let saveContext = ModelContext(context.container)
        saveContext.autosaveEnabled = false
        let trip = makeTrip()
        trip.packingWeather = previewWeather
        trip.hasReviewedTravelRules = true
        trip.excludedPackingIDs = excludedIDs
        trip.excludedPackingNames = Set(recommendations.filter { excludedIDs.contains($0.id) }.map(\.name))
        saveContext.insert(trip)
        for item in recommendations where !excludedIDs.contains(item.id) {
            let saved = PackingItem(name: item.name, category: item.category, reasonKey: item.reason,
                                    quantity: item.quantity, sortIndex: item.sortIndex, trip: trip)
            saved.catalogItemID = item.id
            saveContext.insert(saved)
        }
        for item in customItems {
            let saved = PackingItem(name: item.name, category: item.category,
                reasonKey: item.isStaple ? "我的常備用品" : PackingListGenerator.customReason, quantity: item.quantity, isCustom: true,
                sortIndex: PackingListGenerator.customSortIndex, trip: trip)
            if item.isStaple { saved.catalogItemID = PackingStaples.catalogID(for: item.name) }
            saved.unitWeightKg = item.unitWeightKg
            saveContext.insert(saved)
        }
        do {
            try saveContext.save()
            didSave = true
            // Resolve in the UI's context before passing the trip into its navigation stack.
            let saved = context.model(for: trip.persistentModelID) as! Trip
            appState.setActive(saved)
            WidgetSync.update(trip: saved)
            createdTrip = saved
            dismiss()
        } catch {
            saveContext.rollback()
            saveFailed = true
        }
    }
}

private struct CreationCustomItem: Identifiable {
    let id = UUID()
    let name: String
    let category: PackingCategory
    let quantity: Int
    var isStaple = false
    var unitWeightKg: Double? = nil
}

private struct CreationCustomItemForm: View {
    @Binding var items: [CreationCustomItem]
    let recommendationNames: Set<String>
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
                    ForEach(PackingCategory.allCases) { Text($0.label).tag($0) }
                }
                Stepper("數量：\(quantity)", value: $quantity, in: 1...99)
            }
            .navigationTitle("新增自訂用品")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入", action: attemptAdd)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            Text("「\(duplicateName ?? "這項物品")」和既有推薦或自訂用品可能重複，請確認是否真的需要兩筆。")
        }
    }

    private func attemptAdd() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = PackingStaples.normalized(trimmed)
        let catalogID = PackingStaples.catalogID(for: trimmed)
        let allNames = items.map(\.name) + Array(recommendationNames)
        if let match = allNames.first(where: {
            PackingStaples.normalized($0) == normalized
                || (catalogID != nil && PackingStaples.catalogID(for: $0) == catalogID)
        }) {
            duplicateName = match
        } else {
            addAndDismiss()
        }
    }

    private func addAndDismiss() {
        items.append(CreationCustomItem(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category, quantity: quantity))
        dismiss()
    }
}
