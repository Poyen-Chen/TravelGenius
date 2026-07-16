//
//  ProhibitedItemsView.swift
//  TravelGenius
//
//  海關違禁品與航空安檢規則的 section 元件（嵌入 Tips 分頁的 List 使用）。
//

import SwiftUI

/// Tips 分頁的海關／安檢內容
struct ProhibitedSections: View {
    enum Mode {
        case customs
        case aviation
    }

    let trip: Trip
    let mode: Mode

    private var country: Country? {
        StaticDataStore.shared.country(code: trip.countryCode)
    }

    /// 依嚴重度排序：禁止 → 需許可 → 需申報
    private var customsItems: [ProhibitedItem] {
        let order: [ProhibitedSeverity] = [.banned, .permit, .declare]
        return StaticDataStore.shared.prohibitedItems(countryCode: trip.countryCode)
            .sorted { (order.firstIndex(of: $0.severity) ?? 9) < (order.firstIndex(of: $1.severity) ?? 9) }
    }

    private var aviationRules: [AviationRule] {
        StaticDataStore.shared.aviationRules(countryCode: trip.countryCode)
    }

    private var lastVerified: String? {
        switch mode {
        case .customs: customsItems.map(\.lastVerified).max()
        case .aviation: aviationRules.map(\.lastVerified).max()
        }
    }

    var body: some View {
        switch mode {
        case .customs:
            Section("入境海關・\(country?.nameZh ?? trip.countryCode)") {
                if customsItems.isEmpty {
                    Text("此目的地尚未收錄違禁品規則。")
                        .foregroundStyle(.secondary)
                }
                ForEach(customsItems) { item in
                    RegulationRow(
                        title: item.itemZh,
                        detail: item.reasonZh,
                        sourceName: item.sourceName,
                        sourceUrl: item.sourceUrl
                    ) {
                        SeverityBadge(severity: item.severity)
                    }
                }
            }
            verifiedFooter
        case .aviation:
            Section("航空安檢・隨身／托運") {
                ForEach(aviationRules) { rule in
                    RegulationRow(
                        title: rule.itemZh,
                        detail: rule.detailZh,
                        sourceName: rule.sourceName,
                        sourceUrl: rule.sourceUrl
                    ) {
                        RestrictionBadge(restriction: rule.restriction)
                    }
                }
            }
            verifiedFooter
        }
    }

    private var verifiedFooter: some View {
        Section {
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let lastVerified {
                    Text("最後查證：\(lastVerified)")
                }
                Text("每項條目均附官方來源連結；規定可能變動，出發前請以最新公告為準。")
            }
        }
    }
}

/// 單條法規列：名稱＋標章＋原因＋官方來源
struct RegulationRow<Badge: View>: View {
    let title: String
    let detail: String
    let sourceName: String?
    let sourceUrl: String?
    @ViewBuilder var badge: () -> Badge

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.body.weight(.medium))
                Spacer()
                badge()
            }
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let sourceName, let sourceUrl, let url = URL(string: sourceUrl) {
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

struct RestrictionBadge: View {
    let restriction: AviationRestriction

    private var color: Color {
        switch restriction {
        case .banned: .red
        case .carryOnOnly: .blue
        case .checkedOnly: .indigo
        case .limited: .orange
        }
    }

    var body: some View {
        Label(restriction.label, systemImage: restriction.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color, in: Capsule())
            .accessibilityLabel("安檢限制：\(restriction.label)")
    }
}

struct SeverityBadge: View {
    let severity: ProhibitedSeverity

    private var color: Color {
        switch severity {
        case .banned: .red
        case .permit: .orange
        case .declare: .yellow
        }
    }

    var body: some View {
        Label(severity.label, systemImage: severity.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(severity == .declare ? Color.primary : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(severity == .declare ? 0.35 : 1), in: Capsule())
            .accessibilityLabel("嚴重度：\(severity.label)")
    }
}
