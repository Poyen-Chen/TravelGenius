import SwiftUI
import SwiftData

struct TripDetailView: View {
    private enum WorkspacePage: String, CaseIterable, Identifiable {
        case overview = "總覽"
        case packing = "打包"
        case restrictions = "違禁品"
        case knowledge = "知識"
        var id: String { rawValue }
    }

    private enum Preview: String, Identifiable { case airport, returnMode, knowledge; var id: String { rawValue } }

    @Environment(\.packmonTheme) private var theme
    @Environment(AppState.self) private var appState
    let trip: Trip
    @State private var page: WorkspacePage = .overview
    @State private var preview: Preview?

    init(trip: Trip, startsInPacking: Bool = false) {
        self.trip = trip
        _page = State(initialValue: startsInPacking ? .packing : .overview)
    }

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader
            pagePicker
            Group {
                switch page {
                case .overview: overview
                case .packing: PackingListView(trip: trip)
                case .restrictions: TripRestrictionsView(trip: trip)
                case .knowledge:
                    FeaturePreviewCard(title: "\(trip.city)旅行知識", subtitle: "城市文化與禮儀將在下一階段完成", symbol: "book.pages")
                        .padding(theme.spacing.medium)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .background(theme.colors.canvas.ignoresSafeArea())
        .navigationTitle("我的行程")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $preview) { value in
            switch value {
            case .airport: FeaturePreviewSheet(title: "機場模式", message: "入口先保留。之後會把當天最重要的證件、安檢與登機事項集中在這裡。", symbol: "airplane.departure")
            case .returnMode: FeaturePreviewSheet(title: "回程模式", message: "入口先保留。之後可用同一份清單反向檢查，避免把物品留在住宿處。", symbol: "arrow.uturn.left.circle")
            case .knowledge: FeaturePreviewSheet(title: "旅行知識", message: "完整城市知識會在下一階段加入。", symbol: "book.pages")
            }
        }
        .onAppear { appState.setActive(trip) }
    }

    private var workspaceHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(statusText).font(.caption.weight(.bold)).foregroundStyle(theme.colors.accent)
            Text(trip.name).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(theme.colors.text)
            if let preferences = trip.packingPreferences {
                Text("此行程設定：\(preferences.party.label)・\(preferences.packingStyle.label)")
                    .font(.caption).foregroundStyle(theme.colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, theme.spacing.medium).padding(.top, 4).padding(.bottom, 12)
    }

    private var pagePicker: some View {
        HStack(spacing: 4) {
            ForEach(WorkspacePage.allCases) { item in
                Button { page = item } label: {
                    Text(item.rawValue).font(.caption.weight(.bold)).foregroundStyle(page == item ? Color.white : theme.colors.secondaryText)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(page == item ? theme.colors.accent : Color.clear, in: Capsule())
                }.buttonStyle(.plain)
            }
        }
        .padding(4).background(theme.colors.surface, in: Capsule()).padding(.horizontal, theme.spacing.medium).padding(.bottom, 10)
    }

    private var overview: some View {
        let items = trip.packingItems ?? []
        let packed = items.filter(\.isPacked).count
        return ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.medium) {
                PackmonCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("打包進度").font(.headline.weight(.bold))
                            Spacer()
                            Text("\(packed)/\(items.count)").font(.title3.weight(.black)).foregroundStyle(theme.colors.secondaryAccent)
                        }
                        ProgressView(value: items.isEmpty ? 0 : Double(packed), total: Double(max(items.count, 1))).tint(theme.colors.secondaryAccent)
                        Text(items.isEmpty ? "清單還沒生成" : "還有 \(items.count - packed) 件要確認")
                            .font(.caption).foregroundStyle(theme.colors.secondaryText)
                    }
                }

                HStack(spacing: 10) {
                    overviewMetric(title: "待處理", value: "\(min(max(items.count - packed, 0), 9)) 項", symbol: "exclamationmark.circle")
                    overviewMetric(title: "旅程天數", value: "\(trip.totalDays) 天", symbol: "calendar")
                }

                PackmonCard {
                    HStack(spacing: 12) {
                        Image(systemName: "cloud.fill").font(.title2).foregroundStyle(theme.colors.secondaryAccent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("天氣概況").font(.subheadline.weight(.bold))
                            Text("冬季多陰天・建議洋蔥式穿搭").font(.caption).foregroundStyle(theme.colors.secondaryText)
                        }
                    }
                }

                Button { page = .packing } label: {
                    Label("繼續打包", systemImage: "checklist").frame(maxWidth: .infinity)
                }.buttonStyle(PackmonPrimaryButtonStyle())

                Text("旅程工具").font(.headline.weight(.bold)).padding(.top, 4)
                Button { preview = .airport } label: { FeaturePreviewCard(title: "機場模式", subtitle: "出發當天快速查看重點", symbol: "airplane.departure") }.buttonStyle(.plain)
                Button { preview = .returnMode } label: { FeaturePreviewCard(title: "回程模式", subtitle: "反向檢查，不遺留物品", symbol: "arrow.uturn.left.circle") }.buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacing.medium).padding(.bottom, 32)
        }
    }

    private func overviewMetric(title: String, value: String, symbol: String) -> some View {
        PackmonCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol).foregroundStyle(theme.colors.accent)
                Text(value).font(.title3.weight(.black)).foregroundStyle(theme.colors.text)
                Text(title).font(.caption).foregroundStyle(theme.colors.secondaryText)
            }
        }
    }

    private var statusText: String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: trip.startDate)).day ?? 0
        if days > 0 { return "還有\(days)天・\(trip.startDate.formatted(.dateTime.month().day()))出發" }
        return trip.contains(.now) ? "旅途中・回程 (trip.endDate.formatted(.dateTime.month().day()))" : "行程已完成"
    }
}

private struct TripRestrictionsView: View {
    private enum Direction: String, CaseIterable, Identifiable { case outbound = "出境・台灣"; case inbound = "入境・日本"; var id: String { rawValue } }
    let trip: Trip
    @Environment(\.packmonTheme) private var theme
    @State private var direction: Direction = .inbound

    private var countryCode: String { direction == .outbound ? trip.originCountryCode : trip.countryCode }
    private var items: [ProhibitedItem] {
        let order: [ProhibitedSeverity] = [.banned, .permit, .declare]
        return StaticDataStore.shared.prohibitedItems(countryCode: countryCode).sorted { (order.firstIndex(of: $0.severity) ?? 9) < (order.firstIndex(of: $1.severity) ?? 9) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("方向", selection: $direction) {
                    ForEach(Direction.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)

                HStack(spacing: 8) {
                    signalCount("2", label: "禁止", tint: theme.colors.danger)
                    signalCount("3", label: "限量", tint: theme.colors.warning)
                    signalCount("27", label: "可帶", tint: theme.colors.success)
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(theme.colors.danger)
                    Text("清單中的食品、藥品與電池可能受限，打包前請逐項確認。")
                        .font(.footnote.weight(.semibold)).foregroundStyle(theme.colors.text)
                }
                .padding(12).background(theme.colors.accentSoft, in: RoundedRectangle(cornerRadius: theme.radius.medium))

                ForEach(items) { item in
                    PackmonRowCard {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(item.itemZh).font(.subheadline.weight(.bold))
                                Spacer(); restrictionPill(item.severity)
                            }
                            Text(item.reasonZh).font(.caption).foregroundStyle(theme.colors.secondaryText).lineLimit(3)
                            if let name = item.sourceName, let source = item.sourceUrl, let url = URL(string: source) {
                                Link("官方來源・\(name)", destination: url).font(.caption2.weight(.semibold))
                            }
                        }
                    }
                }

                if direction == .inbound {
                    ForEach(StaticDataStore.shared.aviationRules(destination: trip.countryCode, origin: trip.originCountryCode).prefix(2)) { rule in
                        PackmonRowCard {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text(rule.itemZh).font(.subheadline.weight(.bold))
                                    Spacer(); PackmonStatusPill(title: rule.restriction.label, tint: theme.colors.warning)
                                }
                                Text(rule.detailZh).font(.caption).foregroundStyle(theme.colors.secondaryText).lineLimit(3)
                            }
                        }
                    }
                    PackmonRowCard {
                        HStack {
                            Text("常備藥（2 個月內）").font(.subheadline.weight(.bold))
                            Spacer(); PackmonStatusPill(title: "可帶", tint: theme.colors.success)
                        }
                    }
                }
            }.padding(.horizontal, theme.spacing.medium).padding(.bottom, 30)
        }
    }

    private func restrictionPill(_ severity: ProhibitedSeverity) -> some View {
        let tint: Color = severity == .banned ? theme.colors.danger : theme.colors.warning
        return PackmonStatusPill(title: severity.label, tint: tint)
    }

    private func signalCount(_ count: String, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(count).font(.title3.weight(.black))
            Text(label).font(.caption2.weight(.bold))
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity).padding(.vertical, 9)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: theme.radius.small))
    }
}
