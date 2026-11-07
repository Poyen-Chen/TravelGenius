import SwiftUI
import SwiftData

struct StandaloneBringCheckerView: View {
    @Environment(\.packmonTheme) private var theme
    @Environment(MascotState.self) private var mascot
    @State private var origin = "TW"
    @State private var destination = "JP"
    @State private var query = ""
    @State private var verdicts: [BringVerdict] = []

    private let popular = ["牛肉乾・肉製品", "行動電源", "酒與菸", "常備藥"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.large) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("能不能帶？")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                        Text("不用建立行程，先選航線就能查。")
                            .font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                    }

                    PackmonCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("這次從哪裡到哪裡？").font(.subheadline.weight(.bold))
                            HStack(spacing: 8) {
                                countryMenu(selection: $origin)
                                Image(systemName: "arrow.right").foregroundStyle(theme.colors.secondaryText)
                                countryMenu(selection: $destination)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(theme.colors.secondaryText)
                        TextField("輸入物品，例如：行動電源", text: $query)
                            .submitLabel(.search).onSubmit(runCheck)
                        if !query.isEmpty {
                            Button { query = ""; verdicts = [] } label: { Image(systemName: "xmark.circle.fill") }
                                .buttonStyle(.plain).foregroundStyle(theme.colors.secondaryText)
                        }
                    }
                    .padding(.horizontal, 14).frame(height: 52)
                    .background(theme.colors.elevatedSurface, in: RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: theme.radius.medium).stroke(theme.colors.separator, lineWidth: 0.75) }

                    if verdicts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("常見物品").font(.headline.weight(.bold))
                            ForEach(popular, id: \.self) { item in
                                Button { query = item.components(separatedBy: "・").first ?? item; runCheck() } label: {
                                    commonItemRow(item)
                                }.buttonStyle(.plain)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                MascotView(expression: verdicts.first?.kind == .unrestricted ? .happy : .alert, size: 52)
                                Text(summaryText).font(.subheadline.weight(.semibold))
                            }
                            ForEach(verdicts) { verdict in verdictCard(verdict) }
                        }
                    }
                }
                .padding(theme.spacing.medium).padding(.bottom, 32)
            }
            .background(theme.colors.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func countryMenu(selection: Binding<String>) -> some View {
        Menu {
            ForEach(StaticDataStore.shared.focusCountries) { country in
                Button("\(country.flagEmoji) \(country.nameZh)") { selection.wrappedValue = country.code }
            }
        } label: {
            let country = StaticDataStore.shared.country(code: selection.wrappedValue)
            HStack { Text("\(country?.flagEmoji ?? "") \(country?.nameZh ?? selection.wrappedValue)"); Spacer(); Image(systemName: "chevron.down") }
                .font(.subheadline.weight(.semibold)).foregroundStyle(theme.colors.text)
                .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 44)
                .background(theme.colors.canvas, in: RoundedRectangle(cornerRadius: theme.radius.small))
        }
    }

    private func commonItemRow(_ item: String) -> some View {
        let label: String
        let tint: Color
        if item.hasPrefix("牛肉") { label = "禁止"; tint = theme.colors.danger }
        else if item.hasPrefix("常備") { label = "可帶"; tint = theme.colors.success }
        else { label = "限量"; tint = theme.colors.warning }
        return PackmonRowCard {
            HStack {
                Text(item).font(.subheadline.weight(.semibold)).foregroundStyle(theme.colors.text)
                Spacer()
                PackmonStatusPill(title: label, tint: tint)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(theme.colors.secondaryText)
            }
        }
    }

    private func verdictCard(_ verdict: BringVerdict) -> some View {
        let tint = verdictTint(verdict.kind)
        return PackmonCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(verdict.kind.label, systemImage: verdict.kind.symbolName)
                        .font(.subheadline.weight(.bold)).foregroundStyle(tint)
                    Spacer()
                    if let context = verdict.context { Text(context).font(.caption2).foregroundStyle(theme.colors.secondaryText) }
                }
                Text(verdict.matchedName).font(.headline)
                Text(verdict.reason).font(.footnote).foregroundStyle(theme.colors.secondaryText)
                if let name = verdict.sourceName, let source = verdict.sourceUrl, let url = URL(string: source) {
                    Link("官方來源・\(name)", destination: url).font(.caption.weight(.semibold))
                }
            }
        }
    }

    private var summaryText: String {
        guard let top = verdicts.first else { return "" }
        switch top.kind {
        case .banned: return "這個不能帶，先看看原因與官方規定。"
        case .permit, .declare, .carryOnOnly, .checkedOnly, .limited, .review: return "可以準備，但有條件限制。"
        case .unrestricted: return "目前沒有足夠資料判定，請查官方來源。"
        }
    }

    private func runCheck() {
        verdicts = CanIBringService.check(query, destination: destination, origin: origin)
        guard let top = verdicts.first else { return }
        mascot.speak(summaryText, expression: top.kind == .unrestricted ? .normal : .alert)
    }

    private func verdictTint(_ kind: BringVerdict.Kind) -> Color {
        switch kind {
        case .banned: theme.colors.danger
        case .unrestricted, .review: theme.colors.warning
        case .carryOnOnly: theme.colors.accent
        default: theme.colors.warning
        }
    }
}

struct KnowledgeLibraryView: View {
    @Environment(\.packmonTheme) private var theme
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("旅行知識").font(.system(size: 30, weight: .black, design: .rounded))
                    Text("先保留知識入口；第二階段會加入可依國家與城市瀏覽的禮儀圖鑑。")
                        .foregroundStyle(theme.colors.secondaryText)
                    FeaturePreviewCard(title: "禮儀圖鑑", subtitle: "餐桌、交通、參拜與日常文化", symbol: "book.pages")
                    FeaturePreviewCard(title: "機場小抄", subtitle: "安檢、轉機與登機提醒", symbol: "airplane")
                }.padding(theme.spacing.medium)
            }.background(theme.colors.canvas.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct ProfileHubView: View {
    private enum Destination: String, Identifiable {
        case staples, preferences, appearance, account
        var id: String { rawValue }
    }
    @Environment(\.packmonTheme) private var theme
    @Environment(CloudAccount.self) private var account
    @Query private var trips: [Trip]
    @State private var destination: Destination?
    @State private var preferences = UserPreferences.forNewTrips()
    @State private var stapleCount: Int?
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.light.rawValue

    private func refreshSummary() {
        preferences = .forNewTrips()
        stapleCount = (try? PackingStaples.load())?.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("我的").font(.system(size: 30, weight: .black, design: .rounded))
                    Text("讓清單，更懂你的旅行習慣。")
                        .font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                    Group {
                        HStack(spacing: 14) {
                            MascotView(size: 64)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("和 Packmon 一起出發").font(.headline)
                                Text("\(trips.count) 趟行程・\(stapleCount.map { "\($0) 項常備用品" } ?? "常備用品待確認")")
                                    .font(.footnote).foregroundStyle(theme.colors.secondaryText)
                            }
                        }
                    }
                    settingsRow(.staples, "常備清單", "每次新行程，都幫你一起帶上", "backpack")
                    settingsRow(.preferences, "個人打包需求", "常用設備、用品與打包習慣", "slider.horizontal.3")
                    settingsRow(.appearance, "外觀設定", AppAppearance(stored: appearanceRaw).label, "paintpalette")
                    settingsRow(.account, "帳號與同步", accountSummary, "icloud")
                    Label(account.syncEnabled ? "行程與常備用品會同步到雲端" : "行程與設定保存在這台裝置",
                          systemImage: account.syncEnabled ? "icloud" : "iphone")
                        .font(.footnote).foregroundStyle(theme.colors.secondaryText)
                }.padding(theme.spacing.medium).padding(.bottom, 32)
            }.background(theme.colors.canvas.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        }
        .onAppear(perform: refreshSummary)
        .sheet(item: $destination, onDismiss: refreshSummary) { destination in
            switch destination {
            case .staples: PackingStaplesView()
            case .preferences: PreferenceSettingsView()
            case .appearance: AppearanceSettingsView()
            case .account: AccountSyncView()
            }
        }
    }

    private var accountSummary: String {
        switch account.phase {
        case .unconfigured: "這個版本尚未提供"
        case .signedOut, .awaitingCode: "登入後可以換手機繼續使用"
        case .signedIn: account.syncEnabled ? "\(account.accountLabel)・同步中" : "\(account.accountLabel)・同步未開啟"
        }
    }

    private func settingsRow(_ target: Destination, _ title: String, _ subtitle: String, _ symbol: String) -> some View {
        Button { destination = target } label: {
            FeaturePreviewCard(title: title, subtitle: subtitle, symbol: symbol)
        }.buttonStyle(.plain)
    }
}

struct FeaturePreviewCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    @Environment(\.packmonTheme) private var theme
    var body: some View {
        PackmonRowCard {
            HStack(spacing: 12) {
                Image(systemName: symbol).foregroundStyle(theme.colors.accent).frame(width: 36, height: 36).background(theme.colors.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline).foregroundStyle(theme.colors.text); Text(subtitle).font(.caption).foregroundStyle(theme.colors.secondaryText) }
                Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(theme.colors.secondaryText)
            }
        }
    }
}

struct FeaturePreviewSheet: View {
    let title: String
    let message: String
    let symbol: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.packmonTheme) private var theme
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: symbol).font(.system(size: 44)).foregroundStyle(theme.colors.accent)
                Text(title).font(.title2.weight(.black))
                Text(message).font(.subheadline).foregroundStyle(theme.colors.secondaryText).multilineTextAlignment(.center)
                Spacer()
            }.padding(32).background(theme.colors.canvas.ignoresSafeArea()).toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.presentationDetents([.medium])
    }
}
