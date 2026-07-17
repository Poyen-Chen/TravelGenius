//
//  TripCreationFlowView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

/// 新版三步驟行程建立流程：基本資訊 → 推薦清單 → 海關提醒。
struct TripCreationFlowView: View {
    private enum Step: Int, CaseIterable {
        case basics = 1
        case recommendations = 2
        case travelRules = 3

        var title: String {
            switch self {
            case .basics: "行程基本資訊"
            case .recommendations: "推薦打包清單"
            case .travelRules: "海關與出入境提醒"
            }
        }

        var subtitle: String {
            switch self {
            case .basics: "告訴我們去哪裡與旅行日期。"
            case .recommendations: "保留需要的建議，也可以加入自己的物品。"
            case .travelRules: "出發前先掌握去程、回程與安檢風險。"
            }
        }
    }

    let initialTrip: Trip?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppState.self) private var appState

    @State private var step: Step
    @State private var workingTrip: Trip?
    @State private var name: String
    @State private var countryCode: String
    @State private var city: String
    @State private var originCountryCode: String
    @State private var originCity: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var recommendations: [PackingListGenerator.GeneratedItem] = []
    @State private var selectedRecommendationNames: Set<String> = []
    @State private var showingAddItem = false
    @State private var saveFeedback = false

    init(trip: Trip? = nil) {
        initialTrip = trip
        let arguments = ProcessInfo.processInfo.arguments
        let debugStep: Int? = arguments.firstIndex(of: "-createTripStep").flatMap { index in
            guard index + 1 < arguments.count else { return nil }
            return Int(arguments[index + 1])
        }
        let defaultCountryCode = trip?.countryCode ?? "JP"
        let defaultOriginCode = trip?.originCountryCode ?? "TW"
        let today = Calendar.current.startOfDay(for: .now)
        _step = State(initialValue: Step(rawValue: trip?.draftCreationStep ?? debugStep ?? 1) ?? .basics)
        _workingTrip = State(initialValue: trip)
        _name = State(initialValue: trip?.name ?? "")
        _countryCode = State(initialValue: defaultCountryCode)
        _city = State(initialValue: trip?.city ?? StaticDataStore.shared.defaultCity(countryCode: defaultCountryCode)?.cityZh ?? "")
        _originCountryCode = State(initialValue: defaultOriginCode)
        _originCity = State(initialValue: trip?.originCity ?? StaticDataStore.shared.defaultCity(countryCode: defaultOriginCode)?.cityZh ?? "")
        _startDate = State(initialValue: trip?.startDate ?? today)
        _endDate = State(initialValue: trip?.endDate ?? Calendar.current.date(byAdding: .day, value: 4, to: today) ?? today)
    }

    private var availableCities: [City] {
        StaticDataStore.shared.cities(countryCode: countryCode)
    }

    private var availableOriginCities: [City] {
        StaticDataStore.shared.cities(countryCode: originCountryCode)
    }

    private var automaticName: String {
        let countryName = StaticDataStore.shared.country(code: countryCode)?.nameZh ?? countryCode
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: startDate),
            to: Calendar.current.startOfDay(for: endDate)
        ).day ?? 0
        return "\(countryName)\(city.isEmpty ? "" : "・\(city)") \(max(days + 1, 1)) 天"
    }

    private var customItems: [PackingItem] {
        (workingTrip?.packingItems ?? [])
            .filter(\.isCustom)
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FlowProgressHeader(
                    currentStep: step.rawValue,
                    totalSteps: Step.allCases.count,
                    title: step.title,
                    subtitle: step.subtitle
                )
                .padding(.horizontal)
                .padding(.top, PackSmartDesign.Spacing.medium)
                .padding(.bottom, PackSmartDesign.Spacing.small)

                Group {
                    switch step {
                    case .basics: basicsForm
                    case .recommendations: recommendationList
                    case .travelRules: travelRulesList
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: step)
            }
            .background(PackSmartDesign.ColorToken.canvas)
            .navigationTitle("新增行程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        persistDraftBeforeDismissal()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .sheet(isPresented: $showingAddItem) {
                if let workingTrip {
                    AddPackingItemView(trip: workingTrip)
                }
            }
            .sensoryFeedback(.success, trigger: saveFeedback)
            .onAppear {
                if step != .basics {
                    prepareRecommendations()
                }
            }
            .onDisappear(perform: persistDraftBeforeDismissal)
        }
        .interactiveDismissDisabled(step != .basics)
    }

    private var basicsForm: some View {
        Form {
            Section("出發地") {
                Picker("國家", selection: $originCountryCode) {
                    ForEach(StaticDataStore.shared.focusCountries) { country in
                        Text("\(country.flagEmoji) \(country.nameZh)").tag(country.code)
                    }
                }
                Picker("城市", selection: $originCity) {
                    ForEach(availableOriginCities) { cityOption in
                        Text(cityOption.cityZh).tag(cityOption.cityZh)
                    }
                }
            }

            Section("目的地") {
                Picker("國家", selection: $countryCode) {
                    ForEach(StaticDataStore.shared.focusCountries) { country in
                        Text("\(country.flagEmoji) \(country.nameZh)").tag(country.code)
                    }
                }
                Picker("城市", selection: $city) {
                    ForEach(availableCities) { cityOption in
                        Text(cityOption.cityZh).tag(cityOption.cityZh)
                    }
                }
            }

            Section("日期") {
                DatePicker("出發", selection: $startDate, displayedComponents: .date)
                DatePicker("回程", selection: $endDate, in: startDate..., displayedComponents: .date)
            }

            Section {
                TextField("名稱（選填）", text: $name)
            } header: {
                Text("行程名稱")
            } footer: {
                Text("留空會使用「\(automaticName)」。")
            }
        }
        .scrollContentBackground(.hidden)
        .onChange(of: countryCode) { _, newValue in
            city = StaticDataStore.shared.defaultCity(countryCode: newValue)?.cityZh ?? ""
        }
        .onChange(of: originCountryCode) { _, newValue in
            originCity = StaticDataStore.shared.defaultCity(countryCode: newValue)?.cityZh ?? ""
        }
        .onChange(of: startDate) { _, newValue in
            if endDate < newValue { endDate = newValue }
        }
    }

    private var recommendationList: some View {
        List {
            Section {
                HStack(spacing: PackSmartDesign.Spacing.small) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tint)
                    Text("已選 \(selectedRecommendationNames.count)／\(recommendations.count) 項推薦")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button(selectedRecommendationNames.count == recommendations.count ? "全不選" : "全選") {
                        if selectedRecommendationNames.count == recommendations.count {
                            selectedRecommendationNames.removeAll()
                        } else {
                            selectedRecommendationNames = Set(recommendations.map(\.name))
                        }
                    }
                    .font(.subheadline)
                }
                .accessibilityElement(children: .combine)
            }

            ForEach(groupedRecommendations, id: \.category) { group in
                Section(group.category.label) {
                    ForEach(group.items) { item in
                        Button {
                            if selectedRecommendationNames.contains(item.name) {
                                selectedRecommendationNames.remove(item.name)
                            } else {
                                selectedRecommendationNames.insert(item.name)
                            }
                        } label: {
                            HStack(spacing: PackSmartDesign.Spacing.medium) {
                                Image(systemName: selectedRecommendationNames.contains(item.name) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selectedRecommendationNames.contains(item.name) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .foregroundStyle(.primary)
                                    Text(item.reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if item.quantity > 1 {
                                    Text("×\(item.quantity)")
                                        .font(.footnote.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.name)，\(selectedRecommendationNames.contains(item.name) ? "已採納" : "未採納")")
                    }
                }
            }

            Section("自訂物品") {
                ForEach(customItems) { item in
                    Label("\(item.name)\(item.quantity > 1 ? " ×\(item.quantity)" : "")", systemImage: item.category.symbolName)
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(customItems[index])
                    }
                }
                Button("新增自訂物品", systemImage: "plus.circle.fill") {
                    showingAddItem = true
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var groupedRecommendations: [(category: PackingCategory, items: [PackingListGenerator.GeneratedItem])] {
        PackingCategory.allCases.compactMap { category in
            let items = recommendations.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    private var travelRulesList: some View {
        List {
            if let workingTrip {
                Section {
                    Label("禁止攜帶、需許可與申報項目都會保留在行程 Tips。", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.primary)
                } footer: {
                    Text("規定可能變動；每項資料均附官方來源，出發前請再次確認最新公告。")
                }
                ProhibitedSections(trip: workingTrip, mode: .customs)
                ProhibitedSections(trip: workingTrip, mode: .aviation)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var actionBar: some View {
        HStack(spacing: PackSmartDesign.Spacing.medium) {
            if step != .basics {
                Button("上一步") {
                    goBack()
                }
                .frame(minWidth: 88, minHeight: 52)
                .buttonStyle(.bordered)
            }

            Button {
                advance()
            } label: {
                Text(step == .travelRules ? "我知道了，完成建立" : "繼續")
            }
            .buttonStyle(PackSmartPrimaryButtonStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, PackSmartDesign.Spacing.small)
        .background(.bar)
    }

    private func advance() {
        switch step {
        case .basics:
            guard let trip = saveBasics(asDraft: true) else { return }
            trip.draftCreationStep = Step.recommendations.rawValue
            prepareRecommendations()
            step = .recommendations
        case .recommendations:
            persistRecommendations()
            workingTrip?.draftCreationStep = Step.travelRules.rawValue
            step = .travelRules
        case .travelRules:
            finishCreation()
        }
    }

    private func goBack() {
        switch step {
        case .basics:
            break
        case .recommendations:
            persistRecommendations()
            workingTrip?.draftCreationStep = Step.basics.rawValue
            step = .basics
        case .travelRules:
            workingTrip?.draftCreationStep = Step.recommendations.rawValue
            step = .recommendations
        }
    }

    @discardableResult
    private func saveBasics(asDraft: Bool) -> Trip? {
        let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? automaticName : name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trip: Trip
        if let workingTrip {
            trip = workingTrip
        } else {
            let country = StaticDataStore.shared.country(code: countryCode)
            trip = Trip(
                name: resolvedName,
                countryCode: countryCode,
                startDate: startDate,
                endDate: endDate,
                homeCurrencyCode: "TWD",
                localCurrencyCode: country?.currencyCode ?? "TWD",
                totalBudget: 0,
                tripType: .leisure
            )
            context.insert(trip)
            workingTrip = trip
        }
        trip.name = resolvedName
        trip.countryCode = countryCode
        trip.city = city
        trip.originCountryCode = originCountryCode
        trip.originCity = originCity
        trip.startDate = startDate
        trip.endDate = endDate
        trip.isDraft = asDraft
        try? context.save()
        return trip
    }

    private func prepareRecommendations() {
        guard let trip = workingTrip ?? saveBasics(asDraft: true) else { return }
        recommendations = PackingListGenerator.generate(for: trip)
        let excluded = trip.excludedPackingNames
        selectedRecommendationNames = Set(recommendations.map(\.name)).subtracting(excluded)
    }

    private func persistRecommendations() {
        guard let trip = workingTrip else { return }
        let allNames = Set(recommendations.map(\.name))
        trip.excludedPackingNames = allNames.subtracting(selectedRecommendationNames)

        let existingAutomatic = (trip.packingItems ?? []).filter { !$0.isCustom }
        for item in existingAutomatic where !selectedRecommendationNames.contains(item.name) {
            context.delete(item)
        }
        let existingNames = Set(existingAutomatic.map(\.name))
        for item in recommendations where selectedRecommendationNames.contains(item.name) && !existingNames.contains(item.name) {
            context.insert(PackingItem(
                name: item.name,
                category: item.category,
                reasonKey: item.reason,
                quantity: item.quantity,
                isCustom: false,
                sortIndex: item.sortIndex,
                trip: trip
            ))
        }
        try? context.save()
    }

    private func finishCreation() {
        guard let trip = saveBasics(asDraft: false) else { return }
        persistRecommendations()
        trip.isDraft = false
        trip.hasReviewedTravelRules = true
        trip.draftCreationStep = Step.travelRules.rawValue
        appState.setActive(trip)
        WidgetSync.update(trip: trip)
        try? context.save()
        saveFeedback.toggle()
        dismiss()
    }

    private func persistDraftBeforeDismissal() {
        guard let workingTrip, workingTrip.isDraft else { return }
        _ = saveBasics(asDraft: true)
        if step != .basics {
            persistRecommendations()
        }
        workingTrip.draftCreationStep = step.rawValue
        try? context.save()
    }
}
