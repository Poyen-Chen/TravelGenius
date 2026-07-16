//
//  EtiquetteCardsView.swift
//  TravelGenius
//
//  城市文化提醒 section 元件（嵌入 Tips 分頁）：
//  城市限定優先（同一國家不同城市習慣可能相反，例如東京手扶梯靠左、大阪靠右），其次全國通用。
//

import SwiftUI

struct EtiquetteSections: View {
    let trip: Trip

    private var allCards: [EtiquetteCard] {
        StaticDataStore.shared.etiquetteCards(countryCode: trip.countryCode)
    }

    private var generalCards: [EtiquetteCard] {
        allCards.filter { $0.cityZh == nil }
    }

    /// 依資料檔順序排列的城市分組
    private var citySections: [(city: String, cards: [EtiquetteCard])] {
        StaticDataStore.shared.etiquetteCities(countryCode: trip.countryCode).map { city in
            (city, allCards.filter { $0.cityZh == city })
        }
    }

    var body: some View {
        if allCards.isEmpty {
            Section {
                Text("此目的地尚未收錄文化提醒。")
                    .foregroundStyle(.secondary)
            }
        }

        if !trip.city.isEmpty {
            // 指定城市：城市限定放最前面，再列全國通用
            if let section = citySections.first(where: { $0.city == trip.city }) {
                Section("\(section.city)・城市限定") {
                    ForEach(section.cards) { card in
                        EtiquetteRow(card: card, highlighted: true)
                    }
                }
            }
            if !generalCards.isEmpty {
                Section("全國通用") {
                    ForEach(generalCards) { card in
                        EtiquetteRow(card: card, highlighted: false)
                    }
                }
            }
        } else {
            if !generalCards.isEmpty {
                Section("全國通用") {
                    ForEach(generalCards) { card in
                        EtiquetteRow(card: card, highlighted: false)
                    }
                }
            }
            ForEach(citySections, id: \.city) { section in
                Section("\(section.city)・城市限定") {
                    ForEach(section.cards) { card in
                        EtiquetteRow(card: card, highlighted: false)
                    }
                }
            }
        }

        Section {
        } footer: {
            Text("內容整理自各地觀光局與官方公告；涉及罰則的條目附來源連結。")
        }
    }
}

private struct EtiquetteRow: View {
    let card: EtiquetteCard
    let highlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(card.titleZh, systemImage: highlighted ? "mappin.circle.fill" : "hand.raised")
                .font(.body.weight(.semibold))
                .foregroundStyle(highlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            Text(card.bodyZh)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let sourceName = card.sourceName,
               let sourceUrl = card.sourceUrl,
               let url = URL(string: sourceUrl) {
                Link(destination: url) {
                    HStack(spacing: 3) {
                        Image(systemName: "link")
                        Text("來源：\(sourceName)")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8))
                    }
                    .font(.caption)
                }
                .accessibilityLabel("開啟資料來源：\(sourceName)")
            }
        }
        .padding(.vertical, 4)
    }
}
