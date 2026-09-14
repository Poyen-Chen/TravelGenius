//
//  WeatherAttributionView.swift
//  TravelGenius
//
//  WeatherKit 規定的資料來源標示：顯示 Apple Weather 標誌，並連到 Apple 的法律聲明頁。
//

import SwiftUI
import WeatherKit

struct WeatherAttributionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var attribution: WeatherAttribution?

    var body: some View {
        HStack(spacing: 6) {
            if let attribution {
                AsyncImage(url: colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Text(attribution.serviceName)
                }
                .frame(height: 12)
                .accessibilityLabel(attribution.serviceName)
                Link("資料來源與法律聲明", destination: attribution.legalPageURL)
            } else {
                Text("天氣資料來源：Apple Weather")
            }
        }
        .font(.caption2)
        .task {
            attribution = try? await WeatherKit.WeatherService.shared.attribution
        }
    }
}
