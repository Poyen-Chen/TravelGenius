//
//  TipsRootView.swift
//  TravelGenius
//
//  Tips 分頁：亮點「這個能帶嗎」即問即答＋海關／安檢／城市文化三段內容。
//

import SwiftUI
import SwiftData

struct TipsRootView: View {
    var trip: Trip?
    var embedded = false

    @Environment(AppState.self) private var appState
    @Environment(MascotState.self) private var mascot
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]

    private enum Segment: String, CaseIterable, Identifiable {
        case customs = "海關規定"
        case aviation = "航空安檢"
        case culture = "城市文化"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .customs
    @State private var query = ""
    @State private var verdicts: [BringVerdict] = []
    @FocusState private var searchFocused: Bool

    init(trip: Trip? = nil, embedded: Bool = false) {
        self.trip = trip
        self.embedded = embedded
    }

    private var selectedTrip: Trip? {
        trip ?? appState.activeTrip(in: trips)
    }

    var body: some View {
        Group {
            if embedded {
                rootContent
            } else {
                NavigationStack {
                    rootContent
                }
            }
        }
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-showEtiquette") { segment = .culture }
            if arguments.contains("-showProhibited") { segment = .customs }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if let selectedTrip {
            content(for: selectedTrip)
                .navigationTitle("Tips・\(StaticDataStore.shared.country(code: selectedTrip.countryCode)?.nameZh ?? selectedTrip.countryCode)\(selectedTrip.city.isEmpty ? "" : "・\(selectedTrip.city)")")
                .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("尚無行程", systemImage: "lightbulb", description: Text("建立行程後，這裡會顯示目的地的海關規定與文化提醒。"))
                .navigationTitle("Tips")
        }
    }

    private func content(for trip: Trip) -> some View {
        List {
            checkerSection(for: trip)

            Section {
                Picker("分類", selection: $segment) {
                    ForEach(Segment.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            switch segment {
            case .customs:
                ProhibitedSections(trip: trip, mode: .customs)
            case .aviation:
                ProhibitedSections(trip: trip, mode: .aviation)
            case .culture:
                EtiquetteSections(trip: trip)
            }
        }
    }

    // MARK: - 亮點：「這個能帶嗎」

    private func checkerSection(for trip: Trip) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("這個能帶嗎？輸入物品名稱", text: $query)
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .onSubmit(runCheck)
                    if !query.isEmpty {
                        Button {
                            query = ""
                            verdicts = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("清除查詢")
                    }
                }
                .padding(10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))

                ForEach(verdicts) { verdict in
                    VerdictCard(verdict: verdict)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("這個能帶嗎？")
        } footer: {
            if !verdicts.isEmpty {
                Text("同時查去程與回程海關、航線安檢；判定附官方來源，特殊物品出發前請以最新公告為準。")
            } else {
                Text("例如「肉鬆」「行動電源」— 去程回程一次查。")
            }
        }
    }

    private func runCheck() {
        guard let trip = selectedTrip else { return }
        verdicts = CanIBringService.check(query, destination: trip.countryCode, origin: trip.originCountryCode)
        if let top = verdicts.first {
            mascot.speak(bubbleText(for: top), expression: expression(for: top))
        }
    }

    private func expression(for verdict: BringVerdict) -> MascotExpression {
        switch verdict.kind {
        case .banned, .permit: .alert
        case .unrestricted: .happy
        default: .normal
        }
    }

    private func bubbleText(for verdict: BringVerdict) -> String {
        switch verdict.kind {
        case .banned: "噗！這個不能帶 — \(verdict.matchedName)"
        case .permit: "要先申請許可才行 — \(verdict.matchedName)"
        case .declare: "可以帶，但要記得申報 — \(verdict.matchedName)"
        case .carryOnOnly: "只能隨身、不能托運 — \(verdict.matchedName)"
        case .checkedOnly: "只能托運、不能隨身 — \(verdict.matchedName)"
        case .limited: "可以帶，但有量的限制 — \(verdict.matchedName)"
        case .unrestricted: "查過了，沒有限制，放心帶！"
        }
    }
}

// MARK: - 判定卡

private struct VerdictCard: View {
    let verdict: BringVerdict

    private var tint: Color {
        switch verdict.kind {
        case .banned: .red
        case .permit, .limited: .orange
        case .declare: .yellow
        case .carryOnOnly: .blue
        case .checkedOnly: .indigo
        case .unrestricted: .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(verdict.kind.label, systemImage: verdict.kind.symbolName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                Spacer()
                if let lastVerified = verdict.lastVerified {
                    Text("查證 \(lastVerified)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            if let context = verdict.context {
                Text(context)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(tint)
            }
            Text(verdict.matchedName)
                .font(.body.weight(.semibold))
            Text(verdict.reason)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let sourceName = verdict.sourceName,
               let sourceUrl = verdict.sourceUrl,
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
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
