//
//  TripFormView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

struct TripFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    /// nil = 新增；non-nil = 編輯
    var trip: Trip?

    @State private var name = ""
    @State private var countryCode = "JP"
    @State private var city = ""
    @State private var tripType: TripType = .leisure
    @State private var startDate = Calendar.current.startOfDay(for: .now)
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 4, to: Calendar.current.startOfDay(for: .now)) ?? .now
    @State private var budgetText = ""
    @State private var homeCurrency = "TWD"
    @State private var localCurrency = "JPY"
    @State private var didLoad = false
    @FocusState private var budgetFocused: Bool

    /// 逐鍵解析輸入的預算（容許千分位逗號）
    private var budget: Decimal? {
        Decimal(string: budgetText.replacingOccurrences(of: ",", with: ""))
    }

    /// 名稱留空時自動命名，例如「日本・東京 5 天」
    private var autoName: String {
        let countryName = StaticDataStore.shared.country(code: countryCode)?.nameZh ?? countryCode
        let calendar = Calendar.current
        let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: endDate)).day ?? 0) + 1
        return "\(countryName)\(city.isEmpty ? "" : "・\(city)") \(max(days, 1)) 天"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本資料") {
                    TextField("名稱（留空自動命名）", text: $name)
                    Picker("目的地", selection: $countryCode) {
                        ForEach(StaticDataStore.shared.countries) { country in
                            Text("\(country.flagEmoji) \(country.nameZh)").tag(country.code)
                        }
                    }
                    if !availableCities.isEmpty {
                        Picker("城市", selection: $city) {
                            Text("不指定").tag("")
                            ForEach(availableCities, id: \.self) { cityName in
                                Text(cityName).tag(cityName)
                            }
                        }
                    }
                    Picker("旅行型態", selection: $tripType) {
                        ForEach(TripType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                }

                Section("日期") {
                    DatePicker("出發", selection: $startDate, displayedComponents: .date)
                    DatePicker("回程", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                Section {
                    HStack {
                        TextField("總預算（選填）", text: $budgetText)
                            .keyboardType(.decimalPad)
                            .focused($budgetFocused)
                        if let budget, budget > 0 {
                            MoneyText(amount: budget, currencyCode: homeCurrency)
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }
                    Picker("本幣", selection: $homeCurrency) { currencyOptions }
                    Picker("當地幣別", selection: $localCurrency) { currencyOptions }
                } header: {
                    Text("預算")
                } footer: {
                    Text("可先留空，之後在記帳分頁補上就會開始追蹤跑道。")
                }
            }
            .navigationTitle(trip == nil ? "新增行程" : "編輯行程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存", action: save)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { budgetFocused = false }
                }
            }
            .onChange(of: countryCode) { _, newValue in
                if let country = StaticDataStore.shared.country(code: newValue) {
                    localCurrency = country.currencyCode
                }
                city = ""
            }
            .onChange(of: startDate) { _, newValue in
                if endDate < newValue { endDate = newValue }
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

    private var currencyOptions: some View {
        ForEach(StaticDataStore.shared.currencies) { currency in
            Text("\(currency.code)　\(currency.nameZh)").tag(currency.code)
        }
    }

    /// 有城市限定文化提醒資料的城市
    private var availableCities: [String] {
        StaticDataStore.shared.etiquetteCities(countryCode: countryCode)
    }

    private func loadIfNeeded() {
        guard let trip, !didLoad else { return }
        didLoad = true
        name = trip.name
        countryCode = trip.countryCode
        city = trip.city
        tripType = trip.tripType
        startDate = trip.startDate
        endDate = trip.endDate
        budgetText = "\(NSDecimalNumber(decimal: trip.totalBudget))"
        homeCurrency = trip.homeCurrencyCode
        localCurrency = trip.localCurrencyCode
    }

    private func save() {
        let budget = self.budget ?? 0
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let name = trimmedName.isEmpty ? autoName : trimmedName
        if let trip {
            trip.name = name
            trip.countryCode = countryCode
            trip.city = city
            trip.tripType = tripType
            trip.startDate = startDate
            trip.endDate = endDate
            trip.totalBudget = budget
            trip.homeCurrencyCode = homeCurrency
            trip.localCurrencyCode = localCurrency
        } else {
            let newTrip = Trip(
                name: name,
                countryCode: countryCode,
                startDate: startDate,
                endDate: endDate,
                homeCurrencyCode: homeCurrency,
                localCurrencyCode: localCurrency,
                totalBudget: budget,
                tripType: tripType
            )
            newTrip.city = city
            context.insert(newTrip)
            appState.setActive(newTrip)
        }
        dismiss()
    }
}
