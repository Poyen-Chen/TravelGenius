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
    @State private var countryCode = ""
    @State private var city = ""
    @State private var originCountryCode = "TW"
    @State private var originCity = StaticDataStore.shared.defaultCity(countryCode: "TW")?.cityZh ?? ""
    @State private var startDate = Calendar.current.startOfDay(for: .now)
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 4, to: Calendar.current.startOfDay(for: .now)) ?? .now
    @State private var didLoad = false

    /// 名稱留空時自動命名，例如「日本・東京 5 天」
    private var autoName: String {
        let countryName = StaticDataStore.shared.country(code: countryCode)?.nameZh ?? countryCode
        let calendar = Calendar.current
        let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: endDate)).day ?? 0) + 1
        return "\(countryName)\(city.isEmpty ? "" : "・\(city)") \(max(days, 1)) 天"
    }

    private var availableCities: [City] {
        StaticDataStore.shared.cities(countryCode: countryCode)
    }

    private var availableOriginCities: [City] {
        StaticDataStore.shared.cities(countryCode: originCountryCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("出發地") {
                    Picker("國家／地區", selection: Binding(get: { originCountryCode }, set: {
                        originCountryCode = $0
                        originCity = StaticDataStore.shared.defaultCity(countryCode: $0)?.cityZh ?? ""
                    })) {
                        if !StaticDataStore.focusCountryCodes.contains(originCountryCode) {
                            Text(StaticDataStore.shared.country(code: originCountryCode)?.nameZh ?? originCountryCode).tag(originCountryCode)
                        }
                        ForEach(StaticDataStore.shared.focusCountries) { country in
                            Text("\(country.flagEmoji) \(country.nameZh)").tag(country.code)
                        }
                    }
                    Picker("城市", selection: $originCity) {
                        if !availableOriginCities.contains(where: { $0.cityZh == originCity }) {
                            Text(originCity.isEmpty ? "未指定" : originCity).tag(originCity)
                        }
                        ForEach(availableOriginCities) { cityOption in
                            Text(cityOption.cityZh).tag(cityOption.cityZh)
                        }
                    }
                }

                Section("目的地") {
                    Picker("國家／地區", selection: Binding(get: { countryCode }, set: {
                        if countryCode != $0 { countryCode = $0; city = "" }
                    })) {
                        Text("請選擇").tag("")
                        if let trip, !StaticDataStore.destinationCountryCodes.contains(trip.countryCode) {
                            Text("\(StaticDataStore.shared.country(code: trip.countryCode)?.nameZh ?? trip.countryCode)（原有行程）").tag(trip.countryCode)
                        }
                        ForEach(StaticDataStore.shared.destinationCountries) { country in
                            Text("\(country.flagEmoji) \(country.nameZh)").tag(country.code)
                        }
                    }
                    Picker("城市", selection: $city) {
                        Text("請選擇城市").tag("")
                        if let trip, trip.countryCode == countryCode, !trip.city.isEmpty,
                           !availableCities.contains(where: { $0.cityZh == trip.city }) {
                            Text("\(trip.city)（原有行程）").tag(trip.city)
                        }
                        ForEach(availableCities) { cityOption in
                            Text(cityOption.cityZh).tag(cityOption.cityZh)
                        }
                    }
                    .disabled(countryCode.isEmpty)
                }

                Section("日期") {
                    DatePicker("出發", selection: $startDate, displayedComponents: .date)
                    DatePicker("回程", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                Section {
                    TextField("名稱（留空自動命名）", text: $name)
                } footer: {
                    Text("留空會命名為「\(autoName)」")
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
                        .disabled(countryCode.isEmpty || (city.isEmpty && !(trip?.countryCode == countryCode && trip?.city == city)))
                }
            }
            .onChange(of: startDate) { _, newValue in
                if endDate < newValue { endDate = newValue }
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

    private func loadIfNeeded() {
        guard let trip, !didLoad else { return }
        didLoad = true
        name = trip.name
        countryCode = trip.countryCode
        city = trip.city
        originCountryCode = trip.originCountryCode
        originCity = trip.originCity
        startDate = trip.startDate
        endDate = trip.endDate
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let name = trimmedName.isEmpty ? autoName : trimmedName
        if let trip {
            trip.name = name
            trip.countryCode = countryCode
            if let country = StaticDataStore.shared.country(code: countryCode) {
                trip.localCurrencyCode = country.currencyCode
            }
            trip.city = city
            trip.originCountryCode = originCountryCode
            trip.originCity = originCity
            trip.startDate = startDate
            trip.endDate = endDate
            // Saved metadata must never implicitly replace the user's packing list.
            // Missing recommendations are reviewed explicitly on the packing page.
        } else {
            let country = StaticDataStore.shared.country(code: countryCode)
            let newTrip = Trip(
                name: name,
                countryCode: countryCode,
                startDate: startDate,
                endDate: endDate,
                homeCurrencyCode: "TWD",
                localCurrencyCode: country?.currencyCode ?? "TWD",
                totalBudget: 0,
                tripType: .leisure
            )
            newTrip.city = city
            newTrip.originCountryCode = originCountryCode
            newTrip.originCity = originCity
            context.insert(newTrip)
            appState.setActive(newTrip)
        }
        dismiss()
    }
}
