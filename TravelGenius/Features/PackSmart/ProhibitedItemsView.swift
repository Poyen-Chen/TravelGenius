//
//  ProhibitedItemsView.swift
//  TravelGenius
//

import SwiftUI

struct ProhibitedItemsView: View {
    let trip: Trip

    private var country: Country? {
        StaticDataStore.shared.country(code: trip.countryCode)
    }

    /// 依嚴重度排序：禁止 → 需許可 → 需申報
    private var items: [ProhibitedItem] {
        let order: [ProhibitedSeverity] = [.banned, .permit, .declare]
        return StaticDataStore.shared.prohibitedItems(countryCode: trip.countryCode)
            .sorted { (order.firstIndex(of: $0.severity) ?? 9) < (order.firstIndex(of: $1.severity) ?? 9) }
    }

    private var aviationRules: [AviationRule] {
        StaticDataStore.shared.aviationRules(countryCode: trip.countryCode)
    }

    private var lastVerified: String? {
        (items.map(\.lastVerified) + aviationRules.map(\.lastVerified)).max()
    }

    var body: some View {
        List {
            if !items.isEmpty {
                Section("入境海關・\(country?.nameZh ?? trip.countryCode)") {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.itemZh)
                            .font(.body.weight(.medium))
                        Spacer()
                        SeverityBadge(severity: item.severity)
                    }
                    Text(item.reasonZh)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let sourceName = item.sourceName,
                       let sourceUrl = item.sourceUrl,
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
            }

            if !aviationRules.isEmpty {
                Section("航空安檢・隨身／托運") {
                    ForEach(aviationRules) { rule in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(rule.itemZh)
                                    .font(.body.weight(.medium))
                                Spacer()
                                RestrictionBadge(restriction: rule.restriction)
                            }
                            Text(rule.detailZh)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if let sourceName = rule.sourceName,
                               let sourceUrl = rule.sourceUrl,
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
            }

            Section {
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if let lastVerified {
                        Text("最後查證：\(lastVerified)")
                    }
                    Text("每項條目均附官方來源連結；規定可能變動，出發前請點擊來源以最新公告為準。安檢細節依航空公司規定可能更嚴格。")
                }
            }
        }
        .navigationTitle("海關與安檢・\(country?.nameZh ?? trip.countryCode)")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if items.isEmpty && aviationRules.isEmpty {
                ContentUnavailableView("尚無資料", systemImage: "checkmark.seal", description: Text("此目的地尚未收錄違禁品規則。"))
            }
        }
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
