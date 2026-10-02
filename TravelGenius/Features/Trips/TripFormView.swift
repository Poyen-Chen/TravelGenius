import SwiftUI
import SwiftData

@MainActor
struct TripEditView: View {
    private enum Stage { case details, review }

    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.packmonTheme) private var theme
    @Environment(AppState.self) private var appState

    @State private var stage: Stage = .details
    @State private var name: String
    @State private var countryCode: String
    @State private var city: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var preferences: UserPreferences
    @State private var packingContext: TripPackingContext
    @State private var weatherDraft = WeatherDraft()
    @State private var review: PackingListGenerator.Review?
    @State private var selectedAdditions: Set<String> = []
    @State private var selectedIncreases: Set<UUID> = []
    @State private var selectedReductions: Set<UUID> = []
    @State private var selectedRemovals: Set<UUID> = []
    @State private var isSaving = false
    @State private var saveError: String?

    init(trip: Trip) {
        self.trip = trip
        _name = State(initialValue: trip.name)
        _countryCode = State(initialValue: trip.countryCode)
        _city = State(initialValue: trip.city)
        _startDate = State(initialValue: trip.startDate)
        _endDate = State(initialValue: trip.endDate)
        _preferences = State(initialValue: trip.packingPreferences ?? .forNewTrips())
        _packingContext = State(initialValue: trip.packingContext ?? .empty)
    }

    private var availableCities: [City] {
        StaticDataStore.shared.cities(countryCode: countryCode)
    }

    private var selectedCity: City? {
        availableCities.first { $0.cityZh == city }
    }

    private var weatherRequest: WeatherRequest? {
        selectedCity.flatMap { WeatherService.request(city: $0, start: startDate, end: endDate) }
    }

    private var resolvedWeather: PackingWeather? {
        if let saved = trip.packingWeather, saved.request == weatherRequest { return saved }
        guard weatherDraft.request == weatherRequest else { return nil }
        return weatherDraft.result
    }

    private var tripDays: Int {
        max((Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate),
            to: Calendar.current.startOfDay(for: endDate)).day ?? 0) + 1, 1)
    }

    private var autoName: String {
        let country = StaticDataStore.shared.country(code: countryCode)?.nameZh ?? countryCode
        return "\(country)\(city.isEmpty ? "" : "・\(city)") \(tripDays) 天"
    }

    private var canReview: Bool {
        !countryCode.isEmpty && selectedCity != nil && endDate >= startDate
            && packingContext.valid && resolvedWeather != nil
            && !weatherDraft.loading
    }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .details: detailsForm
                case .review: reviewView
                }
            }
            .navigationTitle(stage == .details ? "編輯行程" : "確認清單調整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .background(theme.colors.canvas.ignoresSafeArea())
        }
        .task(id: weatherRequest) {
            guard let query = weatherRequest, trip.packingWeather?.request != query else {
                weatherDraft.cancel(); return
            }
            weatherDraft.begin(query, fetch: WeatherService.fetch,
                fallback: { WeatherService.fallback($0, failure: $1) })
        }
        .onDisappear { weatherDraft.cancel() }
        .alert("無法儲存變更", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("好", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }
        .interactiveDismissDisabled(isSaving)
    }

    private var detailsForm: some View {
        Form {
            Section {
                TextField("行程名稱", text: $name)
                Picker("目的地", selection: Binding(get: { countryCode }, set: { value in
                    guard countryCode != value else { return }
                    countryCode = value
                    city = StaticDataStore.shared.defaultCity(countryCode: value)?.cityZh ?? ""
                })) {
                    ForEach(StaticDataStore.shared.destinationCountries) { country in
                        Text("\(country.flagEmoji) \(country.nameZh)").tag(country.code)
                    }
                }
                Picker("城市", selection: $city) {
                    ForEach(availableCities) { Text($0.cityZh).tag($0.cityZh) }
                }
                DatePicker("出發", selection: $startDate, displayedComponents: .date)
                DatePicker("回程", selection: $endDate, in: startDate..., displayedComponents: .date)
            } header: {
                Text("基本資訊")
            } footer: {
                Text("共 \(tripDays) 天。更改目的地後，請重新查看違禁品與航空提醒。")
            }

            Section {
                Picker("打包風格", selection: $preferences.packingStyle) {
                    ForEach(PackingStyle.allCases) { style in
                        Text(style == .full ? "準備齊全" : style.label).tag(style)
                    }
                }.pickerStyle(.segmented)
            } header: {
                Text("打包風格")
            } footer: {
                Text("這是這趟行程自己的設定，不會改變全域預設值。")
            }

            optionSection("這趟會帶的設備", options: PersonalPackingOptions.devices, devices: true)
            optionSection("這趟常備需求", options: PersonalPackingOptions.needs, devices: false)

            Section("活動") {
                ForEach(PackingActivity.recommendationOptions) { activity in
                    selectionRow(activity.label, selected: packingContext.activities.contains(activity)) {
                        toggle(activity, in: &packingContext.activities)
                    }
                }
            }

            Section("住宿與洗衣") {
                selectionRow(PackingStay.hostel.label, selected: packingContext.stays.contains(.hostel)) {
                    toggle(PackingStay.hostel, in: &packingContext.stays)
                }
                Picker("途中洗衣", selection: $packingContext.laundry) {
                    ForEach(PackingLaundryPlan.allCases) { Text($0.label).tag($0) }
                }
            }

            Section("天氣依據") {
                if weatherDraft.loading {
                    HStack { ProgressView(); Text("正在更新天氣與建議…") }
                    if let query = weatherRequest {
                        Button("先用季節參考") {
                            weatherDraft.useFallback(WeatherService.fallback(query, failure: .skipped))
                        }
                    }
                } else if let weather = resolvedWeather {
                    Text(weather.coverageLabel)
                    if let failure = weather.failure {
                        Text(failure.message).font(.caption).foregroundStyle(theme.colors.secondaryText)
                    }
                } else {
                    Text("請選擇可用的目的地與日期。")
                        .foregroundStyle(theme.colors.secondaryText)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .onChange(of: startDate) { _, value in if endDate < value { endDate = value } }
    }

    @ViewBuilder
    private func optionSection(_ title: String, options: [PersonalPackingOptions.Option], devices: Bool) -> some View {
        Section(title) {
            ForEach(options) { option in
                selectionRow(option.label,
                    selected: (devices ? preferences.devices : preferences.needs).contains(option.id)) {
                    togglePersonalOption(option.id, devices: devices)
                }
            }
        }
    }

    private func selectionRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(theme.colors.text)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? theme.colors.accent : theme.colors.secondaryText)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
         .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var reviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let weather = resolvedWeather { PackingWeatherCard(weather: weather) }
                Text("新增與增加數量預設勾選；減量與移除預設不勾選。只有按下儲存後才會變更清單。")
                    .font(.subheadline).foregroundStyle(theme.colors.secondaryText)

                if let review, review.isEmpty {
                    PackmonCard {
                        Label("行程資料會更新，打包清單不需要調整。", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(theme.colors.success)
                    }
                }
                if let review {
                    generatedSection("建議新增", items: review.additions)
                    increaseSection(review.increases)
                    reductionSection(review.reductions)
                    removalSection(review.removals)
                }
            }
            .padding(theme.spacing.medium).padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(isSaving ? "儲存中…" : "套用已選調整並儲存", action: { save(applyChecklistChanges: true) })
                    .buttonStyle(PackmonPrimaryButtonStyle()).disabled(isSaving)
                if review?.isEmpty == false {
                    Button("只儲存行程，保留目前清單", action: { save(applyChecklistChanges: false) })
                        .font(.subheadline.weight(.semibold)).disabled(isSaving)
                }
            }
            .padding(.horizontal, theme.spacing.medium).padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }

    @ViewBuilder
    private func generatedSection(_ title: String, items: [PackingListGenerator.GeneratedItem]) -> some View {
        if !items.isEmpty {
            reviewCard(title) {
                ForEach(items) { item in
                    reviewToggle(selected: selectedAdditions.contains(item.id),
                        title: item.name, detail: "×\(item.quantity)・\(item.reason)") {
                        toggle(item.id, in: &selectedAdditions)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func increaseSection(_ items: [PackingListGenerator.QuantityIncrease]) -> some View {
        if !items.isEmpty {
            reviewCard("建議增加數量") {
                ForEach(items) { item in
                    reviewToggle(selected: selectedIncreases.contains(item.id), title: item.name,
                        detail: "\(item.currentQuantity) → \(item.suggestedQuantity)・\(item.reason)", warning: item.isPacked) {
                        toggle(item.id, in: &selectedIncreases)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func reductionSection(_ items: [PackingListGenerator.QuantityReduction]) -> some View {
        if !items.isEmpty {
            reviewCard("可以減少數量") {
                ForEach(items) { item in
                    reviewToggle(selected: selectedReductions.contains(item.id), title: item.name,
                        detail: "\(item.currentQuantity) → \(item.suggestedQuantity)・\(item.reason)", warning: item.isPacked) {
                        toggle(item.id, in: &selectedReductions)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func removalSection(_ items: [PackingListGenerator.RemovalSuggestion]) -> some View {
        if !items.isEmpty {
            reviewCard("可能不再需要") {
                ForEach(items) { item in
                    reviewToggle(selected: selectedRemovals.contains(item.id), title: item.name,
                        detail: item.reason, warning: item.isPacked) {
                        toggle(item.id, in: &selectedRemovals)
                    }
                }
            }
        }
    }

    private func reviewCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        let rows = content()
        return PackmonCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.headline)
                rows
            }
        }
    }

    private func reviewToggle(selected: Bool, title: String, detail: String, warning: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .font(.title3).foregroundStyle(theme.colors.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(theme.colors.text)
                    Text(detail).font(.caption).foregroundStyle(theme.colors.secondaryText)
                    if warning { Text("已打包，套用前請再次確認").font(.caption2).foregroundStyle(.orange) }
                }
                Spacer(minLength: 0)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(stage == .details ? "取消" : "返回") {
                if stage == .details { dismiss() } else { stage = .details }
            }.disabled(isSaving)
        }
        if stage == .details {
            ToolbarItem(placement: .confirmationAction) {
                Button("檢視變更", action: prepareReview).disabled(!canReview)
            }
        }
    }

    private func prepareReview() {
        guard let weather = resolvedWeather else { return }
        let candidate = makeCandidateTrip(weather: weather)
        let generated = PackingListGenerator.generate(for: candidate)
        let result = PackingListGenerator.review(for: trip, generated: generated)
        review = result
        selectedAdditions = Set(result.additions.map(\.id))
        selectedIncreases = Set(result.increases.map(\.id))
        selectedReductions = []
        selectedRemovals = []
        stage = .review
    }

    private func makeCandidateTrip(weather: PackingWeather) -> Trip {
        let country = StaticDataStore.shared.country(code: countryCode)
        let candidate = Trip(name: name, countryCode: countryCode, startDate: startDate, endDate: endDate,
            homeCurrencyCode: trip.homeCurrencyCode, localCurrencyCode: country?.currencyCode ?? trip.localCurrencyCode,
            totalBudget: trip.totalBudget, tripType: trip.tripType)
        candidate.city = city
        candidate.originCountryCode = trip.originCountryCode
        candidate.originCity = trip.originCity
        candidate.replacePackingPreferences(preferences)
        candidate.replacePackingContext(packingContext)
        candidate.packingWeather = weather
        return candidate
    }

    private func applyDraft(weather: PackingWeather) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.name = trimmed.isEmpty ? autoName : trimmed
        if trip.countryCode != countryCode { trip.hasReviewedTravelRules = false }
        trip.countryCode = countryCode
        trip.city = city
        trip.startDate = startDate
        trip.endDate = endDate
        trip.localCurrencyCode = StaticDataStore.shared.country(code: countryCode)?.currencyCode ?? trip.localCurrencyCode
        trip.replacePackingPreferences(preferences)
        trip.replacePackingContext(packingContext)
        trip.packingWeather = weather
    }

    private func save(applyChecklistChanges: Bool) {
        guard !isSaving, let weather = resolvedWeather, let review else { return }
        isSaving = true
        defer { isSaving = false }

        let original = TripEditSnapshot(trip: trip)
        applyDraft(weather: weather)
        do {
            if applyChecklistChanges {
                _ = try PackingListGenerator.applyReview(trip: trip,
                    selectedAdditionIDs: selectedAdditions,
                    selectedIncreaseIDs: selectedIncreases,
                    selectedReductionIDs: selectedReductions,
                    selectedRemovalIDs: selectedRemovals,
                    preferences: preferences, packingContext: packingContext, weather: weather,
                    context: modelContext)
            } else {
                trip.packingReviewPending = !review.isEmpty
                try modelContext.save()
            }
            appState.setActive(trip)
            WidgetSync.update(trip: trip)
            dismiss()
        } catch {
            original.restore(trip)
            saveError = "變更尚未儲存，請再試一次。"
        }
    }

    private func togglePersonalOption(_ id: String, devices: Bool) {
        var values = devices ? preferences.devices : preferences.needs
        toggle(id, in: &values)
        if devices { preferences.devices = values } else { preferences.needs = values }
    }

    private func toggle<Value: Equatable>(_ value: Value, in values: inout [Value]) {
        if let index = values.firstIndex(of: value) { values.remove(at: index) } else { values.append(value) }
    }

    private func toggle<Value: Hashable>(_ value: Value, in values: inout Set<Value>) {
        if values.contains(value) { values.remove(value) } else { values.insert(value) }
    }
}

private struct TripEditSnapshot {
    let name: String
    let countryCode: String
    let city: String
    let startDate: Date
    let endDate: Date
    let localCurrencyCode: String
    let preferencesRaw: String
    let contextRaw: String
    let weatherRaw: String
    let reviewedTravelRules: Bool
    let reviewPending: Bool

    init(trip: Trip) {
        name = trip.name
        countryCode = trip.countryCode
        city = trip.city
        startDate = trip.startDate
        endDate = trip.endDate
        localCurrencyCode = trip.localCurrencyCode
        preferencesRaw = trip.packingPreferencesRaw
        contextRaw = trip.packingContextRaw
        weatherRaw = trip.packingWeatherRaw
        reviewedTravelRules = trip.hasReviewedTravelRules
        reviewPending = trip.packingReviewPending
    }

    func restore(_ trip: Trip) {
        trip.name = name
        trip.countryCode = countryCode
        trip.city = city
        trip.startDate = startDate
        trip.endDate = endDate
        trip.localCurrencyCode = localCurrencyCode
        trip.packingPreferencesRaw = preferencesRaw
        trip.packingContextRaw = contextRaw
        trip.packingWeatherRaw = weatherRaw
        trip.hasReviewedTravelRules = reviewedTravelRules
        trip.packingReviewPending = reviewPending
    }
}
