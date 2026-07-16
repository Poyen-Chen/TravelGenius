//
//  OnboardingTripSetupView.swift
//  TravelGenius
//
//  Onboarding 建行程步驟（東亞三國、預設城市自動帶入），
//  以及揭曉步驟：清單完成＋分享（病毒時刻）。
//

import SwiftUI

struct OnboardingTripSetupView: View {
    @Binding var countryCode: String
    @Binding var city: String
    @Binding var originCountryCode: String
    @Binding var originCity: String
    @Binding var startDate: Date
    @Binding var endDate: Date
    var onGenerate: () -> Void

    private var availableCities: [City] {
        StaticDataStore.shared.cities(countryCode: countryCode)
    }

    private var availableOriginCities: [City] {
        StaticDataStore.shared.cities(countryCode: originCountryCode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("你要去哪裡？")
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text("目的地與日期決定你的清單和 Tips。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 20)

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

            Button(action: onGenerate) {
                Label("看海關風險＋產生清單", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - 揭曉＋分享

struct OnboardingRevealView: View {
    let trip: Trip?
    var onFinish: () -> Void

    private var bannedCount: Int {
        guard let trip else { return 0 }
        return StaticDataStore.shared.prohibitedItems(countryCode: trip.countryCode)
            .filter { $0.severity == .banned }.count
    }

    private var aviationCount: Int {
        guard let trip else { return 0 }
        return StaticDataStore.shared.aviationRules(destination: trip.countryCode, origin: trip.originCountryCode).count
    }

    private var itemCount: Int {
        trip?.packingItems?.count ?? 0
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            MascotView(expression: .happy, size: 64)

            VStack(spacing: 6) {
                Text("你的行前包完成！")
                    .font(.system(.title, design: .rounded).weight(.bold))
                if let trip {
                    Text(trip.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                summaryRow(symbol: "exclamationmark.octagon.fill", tint: .red,
                           text: "\(bannedCount) 項海關禁止攜帶物品，先避開")
                summaryRow(symbol: "airplane", tint: .blue,
                           text: "\(aviationCount) 條航空安檢規定，隨身托運不搞混")
                summaryRow(symbol: "suitcase.fill", tint: .indigo,
                           text: "\(itemCount) 項專屬清單，含你的同行與經驗客製")
            }
            .padding(.horizontal)

            Spacer()

            if let trip {
                ShareLink(item: PackingShareText.make(for: trip)) {
                    Label("分享清單給同行的人", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.bottom, 4)
            }

            Button(action: onFinish) {
                Text("開始打包")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    private func summaryRow(symbol: String, tint: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 28)
            Text(text)
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
