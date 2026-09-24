import SwiftUI
import SwiftData

struct TripListView: View {
    private enum SheetDestination: String, Identifiable {
        case create, etiquette, staples, history
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.packmonTheme) private var theme
    @Environment(AppState.self) private var appState
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var sheet: SheetDestination?
    @State private var pendingDeletion: Trip?
    @State private var navigationPath: [Trip] = []
    @State private var createdTrip: Trip?
    @State private var startPackingID: UUID?

    private var featuredTrip: Trip? {
        appState.activeTrip(in: trips) ?? trips.first(where: { $0.lifecycleStatus != .completed })
    }

    private var recentTrips: [Trip] {
        Array(trips.filter { $0.id != featuredTrip?.id }.prefix(2))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.large) {
                    header
                    if let trip = featuredTrip {
                        activeTripCard(trip)
                        recentSection
                    } else {
                        emptyState
                    }
                    independentTools
                }
                .padding(.horizontal, theme.spacing.medium)
                .padding(.top, theme.spacing.medium)
                .padding(.bottom, 40)
            }
            .background(theme.colors.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip, startsInPacking: startPackingID == trip.id)
            }
            .sheet(item: $sheet, onDismiss: openCreatedTrip) { destination in
                switch destination {
                case .create: TripCreationFlowView(createdTrip: $createdTrip)
                case .etiquette: FeaturePreviewSheet(title: "禮儀圖鑑", message: "不綁行程也能查各地禮儀；完整圖鑑會在下一階段開放。", symbol: "book.pages")
                case .staples: PackingStaplesView()
                case .history: FeaturePreviewSheet(title: "歷史回顧", message: "入口先保留。之後會整理每趟行程的打包完成度與遺漏紀錄。", symbol: "clock.arrow.circlepath")
                }
            }
            .sheet(item: $pendingDeletion) { trip in
                PackmonRemovalSheet(title: "刪除這趟行程？", name: trip.name,
                    message: "行程與其中的打包清單會一起刪除，這個動作無法復原。",
                    actionTitle: "刪除行程", remove: deletePendingTrip)
            }
            .onAppear { if appState.consumeCreateTripLaunchRequest() { sheet = .create } }
            .onChange(of: navigationPath) { _, path in
                if path.isEmpty { startPackingID = nil }
            }
        }
    }

    private func openCreatedTrip() {
        guard let trip = createdTrip else { return }
        createdTrip = nil
        startPackingID = trip.id
        navigationPath.append(trip)
    }

    private var header: some View {
        HStack {
            Text("我的行程")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(theme.colors.text)
            Spacer()
            Button { sheet = .create } label: {
                Label("新行程", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(theme.colors.accent, in: Capsule())
            }
        }
    }

    private func activeTripCard(_ trip: Trip) -> some View {
        let items = trip.packingItems ?? []
        let packed = items.filter(\.isPacked).count
        let remaining = max(items.count - packed, 0)
        return NavigationLink(value: trip) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    PackmonStatusPill(title: trip.lifecycleStatus == .inProgress ? "進行中・\(countdownText(trip))" : countdownText(trip))
                    Spacer()
                    if remaining > 0 {
                        Label("\(min(remaining, 9)) 項待處理", systemImage: "circle.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(theme.colors.danger)
                    }
                }
                .padding(.trailing, 30)
                Text(trip.name)
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text)
                Text("\(shortDate(trip.startDate))–\(shortDate(trip.endDate))・\(trip.totalDays)天・冬季多陰天")
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.secondaryText)
                ProgressView(value: items.isEmpty ? 0 : Double(packed), total: Double(max(items.count, 1)))
                    .tint(theme.colors.secondaryAccent)
                HStack {
                    Text(items.isEmpty ? "清單待生成" : "打包進度 \(packed)/\(items.count)")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .foregroundStyle(theme.colors.secondaryText)
                HStack(spacing: 10) {
                    MascotView(expression: remaining > 0 ? .normal : .happy, size: 56)
                    Text(items.isEmpty ? "行程準備好了，點進去產生你的打包清單。" : remaining == 0 ? "全部打包完成，可以安心出發了！" : "還有\(remaining)件，禦寒衣物差最多，點進去繼續")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.colors.text)
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
                .background(theme.colors.elevatedSurface.opacity(0.78), in: RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous))
            }
            .padding(theme.spacing.medium)
            .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous).stroke(theme.colors.separator, lineWidth: 0.75) }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            tripMenu(trip)
                .padding(.top, 12)
                .padding(.trailing, 12)
        }
        .contextMenu {
            Button("設為目前行程", systemImage: "checkmark.circle") { appState.setActive(trip) }
            Button("刪除", systemImage: "trash", role: .destructive) { pendingDeletion = trip }
        }
    }

    @ViewBuilder private var recentSection: some View {
        if !recentTrips.isEmpty {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text("最近行程").font(.headline.weight(.bold))
                    Spacer()
                    Button("查看全部") { sheet = .history }
                        .font(.caption.weight(.semibold)).foregroundStyle(theme.colors.accent)
                }
                ForEach(recentTrips) { trip in
                    NavigationLink(value: trip) {
                        PackmonRowCard {
                            HStack(spacing: 12) {
                                Image(systemName: trip.lifecycleStatus.symbolName)
                                    .foregroundStyle(theme.colors.secondaryAccent)
                                    .frame(width: 34, height: 34)
                                    .background(theme.colors.secondaryAccent.opacity(0.12), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(trip.name).font(.subheadline.weight(.bold))
                                    Text("\(shortDate(trip.startDate))–\(shortDate(trip.endDate))・\(trip.totalDays)天")
                                        .font(.caption).foregroundStyle(theme.colors.secondaryText)
                                }
                                Spacer()
                                Color.clear.frame(width: 32, height: 32)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .trailing) {
                        tripMenu(trip).padding(.trailing, 10)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        PackmonCard {
            VStack(spacing: 15) {
                MascotView(size: 104)
                Text("還沒有行程").font(.title2.weight(.black)).foregroundStyle(theme.colors.text)
                Text("查詢與圖鑑照樣能用，建立行程後我才開始準備清單。")
                    .font(.subheadline).foregroundStyle(theme.colors.secondaryText).multilineTextAlignment(.center)
                Button("建立第一個行程") { sheet = .create }.buttonStyle(PackmonPrimaryButtonStyle())
            }.frame(maxWidth: .infinity)
        }
    }

    private var independentTools: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("不用建立行程也能用").font(.headline.weight(.bold))
            toolRow("能不能帶？", subtitle: "查海關與航空限制", symbol: "magnifyingglass") { appState.open(.checker) }
            toolRow("禮儀圖鑑", subtitle: "先看當地眉角", symbol: "book.pages") { sheet = .etiquette }
            toolRow("常備用品", subtitle: "設定每次旅行都會帶的用品", symbol: "backpack") { sheet = .staples }
        }
    }

    private func toolRow(_ title: String, subtitle: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PackmonRowCard {
                HStack(spacing: 12) {
                    Image(systemName: symbol).foregroundStyle(theme.colors.accent).frame(width: 36, height: 36)
                        .background(theme.colors.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.subheadline.weight(.bold)).foregroundStyle(theme.colors.text)
                        Text(subtitle).font(.caption).foregroundStyle(theme.colors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(theme.colors.secondaryText)
                }
            }
        }.buttonStyle(.plain)
    }

    private func shortDate(_ date: Date) -> String { date.formatted(.dateTime.month(.twoDigits).day(.twoDigits)) }

    private func tripMenu(_ trip: Trip) -> some View {
        Menu {
            if appState.activeTripID != trip.id.uuidString {
                Button("設為目前行程", systemImage: "checkmark.circle") { appState.setActive(trip) }
            }
            Button("刪除行程", systemImage: "trash", role: .destructive) { pendingDeletion = trip }
        } label: {
            Image(systemName: "ellipsis")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.colors.secondaryText)
                .frame(width: 32, height: 32)
                .background(theme.colors.elevatedSurface.opacity(0.88), in: Circle())
        }
        .accessibilityLabel("管理 \(trip.name)")
    }

    private func deletePendingTrip() {
        guard let trip = pendingDeletion else { return }
        if appState.activeTripID == trip.id.uuidString { appState.setActive(nil) }
        context.delete(trip)
        try? context.save()
        pendingDeletion = nil
    }

    private func countdownText(_ trip: Trip) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: trip.startDate)).day ?? 0
        if days > 0 { return "還有 \(days) 天" }
        if trip.contains(.now) { return "旅途中" }
        return trip.lifecycleStatus == .completed ? "已完成" : "準備出發"
    }
}
