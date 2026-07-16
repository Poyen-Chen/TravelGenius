//
//  OnboardingTripSetupView.swift
//  TravelGenius
//
//  Onboarding 第 5 步：30 秒建立行程（只問影響清單的三件事），
//  以及第 7 步：清單揭曉＋分享（病毒時刻）。
//

import SwiftUI

struct OnboardingTripSetupView: View {
    @Binding var countryCode: String
    @Binding var city: String
    @Binding var startDate: Date
    @Binding var endDate: Date
    var onGenerate: () -> Void

    private var availableCities: [String] {
        StaticDataStore.shared.etiquetteCities(countryCode: countryCode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("你要去哪裡？")
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text("30 秒就好——目的地與日期決定你的清單。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 20)

            Form {
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
                DatePicker("出發", selection: $startDate, displayedComponents: .date)
                DatePicker("回程", selection: $endDate, in: startDate..., displayedComponents: .date)
            }
            .scrollContentBackground(.hidden)
            .onChange(of: countryCode) { _, _ in city = "" }
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
        return StaticDataStore.shared.aviationRules(countryCode: trip.countryCode).count
    }

    private var itemCount: Int {
        trip?.packingItems?.count ?? 0
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

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
                           text: "\(itemCount) 項專屬打包清單，附「因為是…」理由")
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
