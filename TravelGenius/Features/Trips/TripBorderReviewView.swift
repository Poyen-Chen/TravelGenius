import SwiftUI

struct BorderReviewEntry: Identifiable, Hashable {
    let id: String
    let checkpoint: BorderCheckpoint
    let authority: BorderAuthority
    let status: BorderRuleStatus
    let title: String
    let actionTitle: String
    let detail: String
    let sourceName: String?
    let sourceUrl: String?
    let lastVerified: String?
    let priority: Int

    var completionID: String {
        "\(id)|\(lastVerified ?? "unverified")"
    }
}

enum BorderReviewCatalog {
    static func entries(for trip: Trip, checkpoint: BorderCheckpoint) -> [BorderReviewEntry] {
        let store = StaticDataStore.shared
        let countryCode = checkpoint.countryCode(for: trip)
        var entries = store.borderRules(
            countryCode: countryCode,
            checkpoint: checkpoint,
            on: checkpoint.date(for: trip)
        ).map {
            BorderReviewEntry(
                id: "border-\($0.id)",
                checkpoint: checkpoint,
                authority: $0.authority,
                status: $0.status,
                title: $0.titleZh,
                actionTitle: $0.actionZh,
                detail: $0.detailZh,
                sourceName: $0.sourceName,
                sourceUrl: $0.sourceUrl,
                lastVerified: $0.lastVerified,
                priority: $0.priority ?? 50 + $0.status.sortOrder
            )
        }

        if !checkpoint.isDeparture {
            entries += store.prohibitedItems(countryCode: countryCode).map {
                BorderReviewEntry(
                    id: "prohibited-\(checkpoint.rawValue)-\($0.id)",
                    checkpoint: checkpoint,
                    authority: $0.authority ?? .customs,
                    status: status(for: $0.severity),
                    title: $0.itemZh,
                    actionTitle: $0.actionZh ?? $0.itemZh,
                    detail: $0.reasonZh,
                    sourceName: $0.sourceName,
                    sourceUrl: $0.sourceUrl,
                    lastVerified: $0.lastVerified,
                    priority: $0.priority ?? 50 + status(for: $0.severity).sortOrder
                )
            }
        }

        if checkpoint.isDeparture {
            entries += store.aviationRules(departureCountry: countryCode).map {
                BorderReviewEntry(
                    id: "aviation-\(checkpoint.rawValue)-\($0.id)",
                    checkpoint: checkpoint,
                    authority: .aviation,
                    status: .review,
                    title: $0.itemZh,
                    actionTitle: "確認\($0.itemZh)的隨身與托運方式",
                    detail: $0.detailZh,
                    sourceName: $0.sourceName,
                    sourceUrl: $0.sourceUrl,
                    lastVerified: $0.lastVerified,
                    priority: 100
                )
            }
        }

        return entries.sorted {
            if $0.priority != $1.priority {
                return $0.priority < $1.priority
            }
            if $0.status.sortOrder != $1.status.sortOrder {
                return $0.status.sortOrder < $1.status.sortOrder
            }
            if $0.authority.rawValue != $1.authority.rawValue {
                return $0.authority.rawValue < $1.authority.rawValue
            }
            return $0.title < $1.title
        }
    }

    static func coverageNote(for trip: Trip, checkpoint: BorderCheckpoint) -> String? {
        let countryCode = checkpoint.countryCode(for: trip)
        let hasDirectionalRules = !StaticDataStore.shared.borderRules(
            countryCode: countryCode,
            checkpoint: checkpoint,
            on: checkpoint.date(for: trip)
        ).isEmpty
        let hasAviationRules = checkpoint.isDeparture
            && !StaticDataStore.shared.aviationRules(departureCountry: countryCode).isEmpty
        if checkpoint.isDeparture && !hasDirectionalRules && !hasAviationRules {
            return "此關卡尚未完整收錄當地出口規定；航空安檢與官方來源仍需在出發前確認。"
        }
        if !checkpoint.isDeparture && StaticDataStore.shared.prohibitedItems(countryCode: countryCode).isEmpty {
            return "此關卡尚未收錄完整入境規定；沒有顯示項目不代表可以攜帶。"
        }
        return nil
    }

    private static func status(for severity: ProhibitedSeverity) -> BorderRuleStatus {
        switch severity {
        case .banned: .avoid
        case .declare: .declare
        case .permit, .review: .review
        }
    }
}

private enum BorderReviewProgressStore {
    private static func key(for tripID: UUID) -> String {
        "border-review-confirmed-\(tripID.uuidString)"
    }

    static func load(tripID: UUID) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key(for: tripID)) ?? [])
    }

    static func save(_ values: Set<String>, tripID: UUID) {
        UserDefaults.standard.set(values.sorted(), forKey: key(for: tripID))
    }
}

struct TripBorderReviewView: View {
    private enum SheetDestination: Identifiable {
        case entry(BorderReviewEntry)
        case all(BorderCheckpoint)
        case sources(BorderCheckpoint)

        var id: String {
            switch self {
            case .entry(let entry): "entry-\(entry.id)"
            case .all(let checkpoint): "all-\(checkpoint.rawValue)"
            case .sources(let checkpoint): "sources-\(checkpoint.rawValue)"
            }
        }
    }

    let trip: Trip

    @Environment(\.packmonTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var checkpoint: BorderCheckpoint = .destinationArrival
    @State private var confirmed: Set<String> = []
    @State private var sheet: SheetDestination?

    private var entries: [BorderReviewEntry] {
        BorderReviewCatalog.entries(for: trip, checkpoint: checkpoint)
    }

    private var authorities: [BorderAuthority] {
        BorderAuthority.allCases.filter { authority in
            entries.contains { $0.authority == authority }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.medium) {
                heading
                checkpointSelector
                currentCheckpointCard
            }
            .padding(.horizontal, theme.spacing.medium)
            .padding(.bottom, theme.spacing.xLarge)
        }
        .onAppear {
            confirmed = BorderReviewProgressStore.load(tripID: trip.id)
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .entry(let entry):
                BorderEntryDetailSheet(entry: entry)
            case .all(let checkpoint):
                BorderRulesSheet(
                    title: checkpoint.title(for: trip),
                    entries: BorderReviewCatalog.entries(for: trip, checkpoint: checkpoint),
                    showsSourcesOnly: false
                )
            case .sources(let checkpoint):
                BorderRulesSheet(
                    title: "官方來源與查證日期",
                    entries: BorderReviewCatalog.entries(for: trip, checkpoint: checkpoint),
                    showsSourcesOnly: true
                )
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text("通關檢查")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text)
                Label("官方資料", systemImage: "checkmark.shield")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.colors.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(theme.colors.accentSoft, in: Capsule())
            }
            Text("依照旅程順序，只顯示這一關要做的事。")
                .font(.subheadline)
                .foregroundStyle(theme.colors.secondaryText)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var checkpointSelector: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("選擇通關關卡", selection: $checkpoint) {
                ForEach(BorderCheckpoint.allCases) { item in
                    Text("\(item.number)・\(item.title(for: trip))").tag(item)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacing.medium)
            .background(theme.colors.elevatedSurface, in: RoundedRectangle(cornerRadius: theme.radius.medium))
        } else {
            VStack(spacing: 10) {
                HStack {
                    Text("去程").frame(maxWidth: .infinity)
                    Text("回程").frame(maxWidth: .infinity)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.colors.secondaryText)

                HStack(alignment: .top, spacing: 4) {
                    ForEach(BorderCheckpoint.allCases) { item in
                        checkpointButton(item)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 13)
            .background(theme.colors.elevatedSurface, in: RoundedRectangle(cornerRadius: theme.radius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.medium)
                    .stroke(theme.colors.separator, lineWidth: 0.75)
            }
        }
    }

    private func checkpointButton(_ item: BorderCheckpoint) -> some View {
        let isSelected = item == checkpoint
        return Button {
            checkpoint = item
        } label: {
            VStack(spacing: 7) {
                Text("\(item.number)")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(isSelected ? Color.white : theme.colors.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(isSelected ? theme.colors.accent : theme.colors.surface, in: Circle())
                Text(item.title(for: trip))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.colors.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                Text(shortAuthoritySummary(for: item))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("第 \(item.number) 關，\(item.title(for: trip))，\(shortAuthoritySummary(for: item))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func shortAuthoritySummary(for item: BorderCheckpoint) -> String {
        let values = BorderReviewCatalog.entries(for: trip, checkpoint: item)
        let included = BorderAuthority.allCases.filter { authority in values.contains { $0.authority == authority } }
        return included.map(\.label).joined(separator: "・")
    }

    private var currentCheckpointCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(checkpoint.title(for: trip))
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(theme.colors.text)

            if !authorities.isEmpty {
                HStack(spacing: 7) {
                    ForEach(authorities) { authority in
                        Label(authority.label, systemImage: authority.symbolName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.colors.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(theme.colors.accentSoft, in: Capsule())
                    }
                }
            }

            if entries.isEmpty {
                unverifiedState
            } else {
                Text("有 \(entries.count) 件事需要確認")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(theme.colors.accent)

                VStack(spacing: 0) {
                    ForEach(Array(entries.prefix(3).enumerated()), id: \.element.id) { index, entry in
                        actionRow(entry)
                        if index < min(entries.count, 3) - 1 {
                            Divider().overlay(theme.colors.separator)
                        }
                    }
                }
                .background(theme.colors.elevatedSurface, in: RoundedRectangle(cornerRadius: theme.radius.medium))

                Button {
                    sheet = .all(checkpoint)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                        Text("查看禁止、限量與申報規定")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text("共 \(entries.count) 條")
                            .foregroundStyle(theme.colors.secondaryText)
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(theme.colors.text)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                Divider().overlay(theme.colors.separator)

                Button {
                    sheet = .sources(checkpoint)
                } label: {
                    Label("官方來源與查證日期", systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.colors.accent)
                }
                .buttonStyle(.plain)
            }

            if let coverage = BorderReviewCatalog.coverageNote(for: trip, checkpoint: checkpoint) {
                Label(coverage, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
            } else {
                Label("沒有收錄不代表可以攜帶；不確定時請查官方來源。", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
            }
        }
        .padding(theme.spacing.medium)
        .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: theme.radius.large))
    }

    private func actionRow(_ entry: BorderReviewEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.authority.symbolName)
                .font(.title3)
                .foregroundStyle(tint(for: entry.status))
                .frame(width: 34, height: 34)
                .background(tint(for: entry.status).opacity(0.12), in: Circle())

            Button {
                sheet = .entry(entry)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.actionTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.colors.text)
                        .multilineTextAlignment(.leading)
                    Text("\(entry.authority.label)・\(entry.status.label)")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                toggleConfirmation(entry)
            } label: {
                Image(systemName: confirmed.contains(entry.completionID) ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(confirmed.contains(entry.completionID) ? theme.colors.success : theme.colors.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(entry.actionTitle)，\(confirmed.contains(entry.completionID) ? "標記為未確認" : "標記為已確認")")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 13)
    }

    private var unverifiedState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("尚未收錄此關卡的完整規定", systemImage: "questionmark.circle")
                .font(.headline)
            Text("請不要把空白當成可以攜帶；出發前請向當地海關、檢疫機關與航空公司確認。")
                .font(.subheadline)
                .foregroundStyle(theme.colors.secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.elevatedSurface, in: RoundedRectangle(cornerRadius: theme.radius.medium))
    }

    private func toggleConfirmation(_ entry: BorderReviewEntry) {
        if confirmed.contains(entry.completionID) {
            confirmed.remove(entry.completionID)
        } else {
            confirmed.insert(entry.completionID)
        }
        BorderReviewProgressStore.save(confirmed, tripID: trip.id)
    }

    private func tint(for status: BorderRuleStatus) -> Color {
        switch status {
        case .avoid: theme.colors.danger
        case .declare, .review: theme.colors.warning
        case .prepare: theme.colors.accent
        }
    }
}

private struct BorderEntryDetailSheet: View {
    let entry: BorderReviewEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.packmonTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.medium) {
                    Label(entry.authority.label, systemImage: entry.authority.symbolName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.colors.accent)
                    Text(entry.title)
                        .font(.title2.weight(.black))
                    Text(entry.detail)
                        .font(.body)
                        .foregroundStyle(theme.colors.secondaryText)
                    sourceBlock
                    Text("規定可能變動；此確認只代表你看過提醒，不是海關或航空公司的核准。")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                .padding(theme.spacing.medium)
            }
            .background(theme.colors.canvas)
            .navigationTitle(entry.actionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var sourceBlock: some View {
        if let sourceName = entry.sourceName,
           let sourceUrl = entry.sourceUrl,
           let url = URL(string: sourceUrl) {
            PackmonCard {
                VStack(alignment: .leading, spacing: 8) {
                    if let lastVerified = entry.lastVerified {
                        Text("最後查證：\(lastVerified)")
                            .font(.caption.weight(.bold))
                    }
                    Link(destination: url) {
                        Label("開啟官方來源・\(sourceName)", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
    }
}

private struct BorderRulesSheet: View {
    let title: String
    let entries: [BorderReviewEntry]
    let showsSourcesOnly: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.packmonTheme) private var theme

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "尚未收錄",
                        systemImage: "questionmark.circle",
                        description: Text("沒有顯示項目不代表可以攜帶，請以官方公告為準。")
                    )
                } else {
                    ForEach(BorderAuthority.allCases) { authority in
                        let authorityEntries = entries.filter { $0.authority == authority }
                        if !authorityEntries.isEmpty {
                            Section(authority.label) {
                                ForEach(authorityEntries) { entry in
                                    if showsSourcesOnly {
                                        sourceRow(entry)
                                    } else {
                                        NavigationLink {
                                            BorderEntryDetailSheet(entry: entry)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(entry.title).font(.body.weight(.semibold))
                                                Text(entry.status.label)
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(entry.status == .avoid ? theme.colors.danger : theme.colors.warning)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.canvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func sourceRow(_ entry: BorderReviewEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title).font(.body.weight(.semibold))
            if let lastVerified = entry.lastVerified {
                Text("最後查證：\(lastVerified)")
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
            } else {
                Text("尚無查證日期")
                    .font(.caption)
                    .foregroundStyle(theme.colors.warning)
            }
            if let sourceName = entry.sourceName,
               let sourceUrl = entry.sourceUrl,
               let url = URL(string: sourceUrl) {
                Link(destination: url) {
                    Label(sourceName, systemImage: "arrow.up.right.square")
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 3)
    }
}
