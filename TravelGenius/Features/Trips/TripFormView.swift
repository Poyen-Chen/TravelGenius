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
    @State private var city = StaticDataStore.shared.defaultCity(countryCode: "JP")?.cityZh ?? ""
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

    var body: some View {
        NavigationStack {
            Form {
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
                }
            }
            .onChange(of: countryCode) { _, newValue in
                city = StaticDataStore.shared.defaultCity(countryCode: newValue)?.cityZh ?? ""
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
        startDate = trip.startDate
        endDate = trip.endDate
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let name = trimmedName.isEmpty ? autoName : trimmedName
        if let trip {
            let packingContextChanged = trip.countryCode != countryCode
                || trip.city != city
                || trip.startDate != startDate
                || trip.endDate != endDate
            trip.name = name
            trip.countryCode = countryCode
            trip.city = city
            trip.startDate = startDate
            trip.endDate = endDate
            // 目的地／日期變更會影響清單內容與海關規則，需重新合併生成
            if packingContextChanged && !(trip.packingItems ?? []).isEmpty {
                PackingListGenerator.sync(trip: trip, context: context)
            }
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
            context.insert(newTrip)
            appState.setActive(newTrip)
        }
        dismiss()
    }
}
