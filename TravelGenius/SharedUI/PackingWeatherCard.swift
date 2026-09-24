import SwiftUI

struct PackingWeatherCard: View {
    let weather: PackingWeather
    var saved = false
    @Environment(\.packmonTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        PackmonCard {
            VStack(alignment: .leading, spacing: 8) {
                Label(saved ? "建立清單時的天氣依據" : "\(weather.request.cityName)・天氣參考", systemImage: "cloud.sun")
                    .font(.headline)
                Text(weather.title).font(.subheadline.weight(.semibold))
                Text("旅行日期：\(weather.request.start) ～ \(weather.request.end)")
                if let summary = weather.summary {
                    Text("有預報的 \(weather.days.count) 天：\(summary.headline)")
                    Text("預報日期：\(weather.days.map(\.date).joined(separator: "、"))")
                    Text("降雨機率達 50% 的日期計為降雨機率較高；不代表確定下雨。")
                }
                if !weather.missingDates.isEmpty {
                    Text("其餘 \(weather.missingDates.count) 天\(weather.seasonal == nil ? "缺少季節資料，請自行確認目的地天氣。" : "依當地月份特性準備，不是每日預報。")")
                    if let source = weather.seasonal {
                        Link("季節參考來源：\(source.sourceName)", destination: source.sourceURL)
                        Text("由氣候概述整理的打包參考，非氣象統計值；資料整理：\(source.checkedOn)。")
                    }
                }
                if let failure = weather.failure { Text(failure.message) }
                Text("\(weather.days.isEmpty ? "整理" : "取得")時間：\(weather.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                if saved { Text("此為建立時保存的依據，不是最新預報；不會自動更動你的清單。") }
                if let credit = weather.credit {
                    AsyncImage(url: colorScheme == .dark ? credit.darkMark : credit.lightMark) { image in
                        image.resizable().scaledToFit()
                    } placeholder: { Text("Apple Weather") }
                    .frame(height: 18).accessibilityLabel("Apple Weather")
                    Link("天氣資料來源與法律聲明", destination: credit.legalURL)
                } else if weather.request.source == .openMeteo && !weather.days.isEmpty {
                    Link("天氣資料：Open-Meteo（已整理為打包參考）", destination: URL(string: "https://open-meteo.com/")!)
                    Link("資料授權 CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
                }
            }
            .font(.caption)
            .foregroundStyle(theme.colors.secondaryText)
        }
    }
}
