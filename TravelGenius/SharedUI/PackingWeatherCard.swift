import SwiftUI

struct PackingWeatherCard: View {
    let weather: PackingWeather
    var saved = false
    @Environment(\.packmonTheme) private var theme
    @State private var showingDetails = false

    var body: some View {
        PackmonCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(weather.packingReminder, systemImage: weather.tags.contains("rain") ? "umbrella" : "bag")
                    .font(.headline)
                    .foregroundStyle(theme.colors.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let summary = weather.summary {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { metrics(summary) }
                        VStack(alignment: .leading, spacing: 8) { metrics(summary) }
                    }
                    .font(.subheadline.weight(.medium))
                }
                Text("\(saved ? "建立時參考" : weather.request.cityName) · \(weather.coverageLabel)")
                    .font(.caption)
                Button { showingDetails = true } label: {
                    HStack {
                        Text("查看天氣詳情")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.colors.accent)
                WeatherAttribution(weather: weather)
            }
            .foregroundStyle(theme.colors.secondaryText)
        }
        .sheet(isPresented: $showingDetails) {
            PackingWeatherDetails(weather: weather, saved: saved)
        }
    }

    @ViewBuilder private func metrics(_ summary: WeatherSummary) -> some View {
        Label("\(Int(summary.tempMin.rounded()))–\(Int(summary.tempMax.rounded()))°C", systemImage: "thermometer.medium")
        Label(summary.rainDays == 0 ? "預報日降雨機率皆低於50%" : "\(summary.rainDays) 天降雨機率較高", systemImage: "drop")
    }
}

private struct PackingWeatherDetails: View {
    let weather: PackingWeather
    let saved: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.packmonTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                PackingWeatherEvidence(weather: weather, saved: saved)
                    .padding()
            }
            .background(theme.colors.canvas)
            .navigationTitle("旅程天氣")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .tint(theme.colors.accent)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.colors.canvas)
    }
}

private struct WeatherAttribution: View {
    let weather: PackingWeather
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let credit = weather.credit {
            Link(destination: credit.legalURL) {
                AsyncImage(url: colorScheme == .dark ? credit.darkMark : credit.lightMark) { image in
                    image.resizable().scaledToFit()
                } placeholder: { Text("Apple Weather") }
                .frame(height: 18)
            }
            .accessibilityLabel("Apple Weather，資料來源與法律聲明")
        } else if weather.request.source == .openMeteo && !weather.days.isEmpty {
            Link("Open-Meteo · CC BY 4.0", destination: URL(string: "https://open-meteo.com/")!)
                .font(.caption)
        }
    }
}

private struct PackingWeatherEvidence: View {
    let weather: PackingWeather
    var saved = false
    @Environment(\.packmonTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(weather.request.cityName) · \(shortDate(weather.request.start))–\(shortDate(weather.request.end))")
                    .font(.title2.bold())
                Text("\(saved ? "建立時參考 · " : "")\(weather.coverageLabel)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.colors.accent)
            }

            if let summary = weather.summary {
                Text(summary.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colors.accent)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.colors.accentSoft, in: RoundedRectangle(cornerRadius: 16))
            }

            if !weather.days.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        HStack(spacing: 8) {
                            Text("日期").frame(maxWidth: .infinity, alignment: .leading)
                            Text("溫度").frame(maxWidth: .infinity)
                            Text("降雨機率").frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .font(.subheadline)
                        .foregroundStyle(theme.colors.secondaryText)
                        .padding(12)
                        Divider()
                    }
                    ForEach(weather.days.sorted { $0.date < $1.date }, id: \.date) { day in
                        Group {
                            if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(dayLabel(day.date)).bold()
                                Text("\(Int(day.low.rounded()))–\(Int(day.high.rounded()))°C")
                                rainLabel(day)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                HStack(spacing: 8) {
                                    Text(dayLabel(day.date)).fontWeight(.medium)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(Int(day.low.rounded()))–\(Int(day.high.rounded()))°C")
                                        .frame(maxWidth: .infinity)
                                    rainLabel(day)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                        }
                        .font(.subheadline)
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .background(day.rainChance >= 0.5 ? theme.colors.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityElement(children: .combine)
                        Divider()
                    }
                }
            }

            Label(weather.packingReminder, systemImage: weather.tags.contains("rain") ? "umbrella" : "bag")
                .font(.headline)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.colors.accentSoft, in: RoundedRectangle(cornerRadius: 16))

            if !weather.missingDates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(weather.days.isEmpty ? "尚無每日預報" : "另有 \(weather.missingDates.count) 天無預報", systemImage: "calendar.badge.clock")
                        .font(.headline)
                    Text(weather.seasonal == nil ? "請在出發前確認目的地天氣。" : "這些日期依當地季節準備，不是每日預報。")
                    if let failure = weather.failure { Text(failure.message) }
                }
                .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup("預報與資料說明") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("旅行日期：\(weather.request.start) ～ \(weather.request.end)")
                        if !weather.missingDates.isEmpty {
                            Text("無預報日期：\(weather.missingDates.joined(separator: "、"))")
                        }
                        if !weather.days.isEmpty {
                            Text("水滴百分比表示當日降雨機率。達 50% 計為降雨機率較高，不代表確定下雨。溫度範圍僅統計有預報的日期。")
                        }
                        if saved { Text("查看天氣不會自動更動你的打包清單。") }
                        if !weather.missingDates.isEmpty, let source = weather.seasonal {
                            Link("季節參考：\(source.sourceName)", destination: source.sourceURL)
                            Text("由氣候概述整理，非氣象統計值；整理日期：\(source.checkedOn)。")
                        }
                        if weather.request.source == .openMeteo && !weather.days.isEmpty {
                            Text("Open-Meteo 資料已整理為打包參考。")
                            Link("資料授權 CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                }
                .padding(16)
                .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: 16))
                Label("\(weather.days.isEmpty ? "整理" : "取得")於 \(weather.fetchedAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                if saved { Text("建立清單時保存，非即時更新。") }
                WeatherAttribution(weather: weather)
            }
            .font(.subheadline)
            .foregroundStyle(theme.colors.secondaryText)
        }
        .foregroundStyle(theme.colors.text)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rainLabel(_ day: WeatherDay) -> some View {
        Label("\(Int((day.rainChance * 100).rounded()))%", systemImage: day.rainChance >= 0.5 ? "drop.fill" : "drop")
            .foregroundStyle(day.rainChance >= 0.5 ? theme.colors.accent : theme.colors.secondaryText)
            .accessibilityLabel("降雨機率 \(Int((day.rainChance * 100).rounded()))%")
    }

    private func dayLabel(_ value: String) -> String {
        guard let date = weather.request.date(value) else { return value }
        let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
        return "\(shortDate(value))（\(weekdays[weather.request.calendar.component(.weekday, from: date) - 1])）"
    }

    private func shortDate(_ date: String) -> String {
        let parts = date.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) else { return date }
        return "\(month)/\(day)"
    }
}
