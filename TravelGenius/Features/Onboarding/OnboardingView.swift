//
//  OnboardingView.swift
//  TravelGenius
//
//  問卷式 onboarding：目標 → 痛點 → 解方 → 快速建行程 → 處理動畫 → 清單揭曉（分享）。
//  只在首次啟動顯示（@AppStorage "hasOnboarded"）。
//

import SwiftUI
import SwiftData

/// 痛點選項：文案取材自使用者研究（Dcard/PTT/App 評論整理）
enum OnboardingPain: String, CaseIterable, Identifiable {
    case forgetting
    case customs
    case overspend
    case reimbursement
    case leaveBehind
    case medical

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .forgetting: "😰"
        case .customs: "🛃"
        case .overspend: "💸"
        case .reimbursement: "🧾"
        case .leaveBehind: "🏨"
        case .medical: "🏥"
        }
    }

    var label: String {
        switch self {
        case .forgetting: "每次打包都怕漏帶東西"
        case .customs: "搞不清楚海關什麼不能帶"
        case .overspend: "旅費常常不知不覺超支"
        case .reimbursement: "出差報帳整理到懷疑人生"
        case .leaveBehind: "退房總擔心把東西留在飯店"
        case .medical: "在國外看病說不清楚自己的狀況"
        }
    }

    /// 解方橋接：灰字痛點 → 粗體解法
    var solution: (title: String, symbol: String) {
        switch self {
        case .forgetting: ("依目的地、天氣與旅行型態自動生成專屬清單", "suitcase.fill")
        case .customs: ("內建海關違禁品與航空安檢規則，附官方來源", "exclamationmark.octagon.fill")
        case .overspend: ("跑道倒數：還能撐幾天，一個數字說清楚", "gauge.with.needle")
        case .reimbursement: ("兩步記帳＋收據照片，一鍵匯出 CSV／PDF", "doc.richtext.fill")
        case .leaveBehind: ("回程模式：同一份清單反向檢查，不留東西", "arrow.uturn.left.circle.fill")
        case .medical: ("醫療卡自動翻譯成當地語言，緊急資訊一頁出示", "cross.case.fill")
        }
    }
}

struct OnboardingView: View {
    var onComplete: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    private enum Step: Int, CaseIterable {
        case welcome, goal, pains, solution, setup, processing, reveal
    }

    @State private var step: Step = .welcome
    @State private var tripType: TripType = .leisure
    @State private var selectedPains: Set<OnboardingPain> = []

    // 快速建行程
    @State private var countryCode = "JP"
    @State private var city = ""
    @State private var startDate = Calendar.current.startOfDay(for: .now)
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 4, to: Calendar.current.startOfDay(for: .now)) ?? .now
    @State private var createdTrip: Trip?
    @State private var processingText = "正在比對海關與安檢規則…"

    private var progress: Double {
        Double(step.rawValue) / Double(Step.allCases.count - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ProgressView(value: progress)
                    .tint(.accentColor)
                    .accessibilityLabel("流程進度 \(Int(progress * 100))%")
                if step.rawValue <= Step.setup.rawValue {
                    Button("略過") { finish(openPacking: false) }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Group {
                switch step {
                case .welcome: welcomeStep
                case .goal: goalStep
                case .pains: painsStep
                case .solution: solutionStep
                case .setup: OnboardingTripSetupView(
                    countryCode: $countryCode,
                    city: $city,
                    startDate: $startDate,
                    endDate: $endDate,
                    onGenerate: startProcessing
                )
                case .processing: processingStep
                case .reveal: OnboardingRevealView(trip: createdTrip) {
                    finish(openPacking: true)
                }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.snappy, value: step)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - 1. Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundStyle(.red)
                    Text("海關風險・日本")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.red)
                }
                Text("感冒藥（含偽麻黃鹼）— 禁止")
                    .font(.footnote.weight(.medium))
                Text("違反覺醒劑取締法，攜帶恐涉刑責")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: 300, alignment: .leading)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))

            VStack(spacing: 8) {
                Text("出國前，先看懂海關風險")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                Text("再拿到為你客製的打包清單、旅費跑道與醫療卡。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer()

            Button {
                step = .goal
            } label: {
                Text("開始")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - 2. 目標

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title: "你最常是哪一種旅行？", subtitle: "清單和記帳會依此客製。")

            VStack(spacing: 10) {
                goalOption(.leisure, emoji: "🗺️", detail: "行程自由，重點是玩得盡興")
                goalOption(.business, emoji: "💼", detail: "要報帳、要津貼、要正式服裝")
                goalOption(.backpacking, emoji: "🎒", detail: "行李越輕越好，預算抓很緊")
                goalOption(.family, emoji: "👨‍👩‍👧", detail: "大人小孩的東西都不能漏")
            }
            .padding(.horizontal)

            Spacer()
            continueButton { step = .pains }
        }
    }

    private func goalOption(_ type: TripType, emoji: String, detail: String) -> some View {
        Button {
            tripType = type
        } label: {
            HStack(spacing: 12) {
                Text(emoji).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.label).font(.body.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: tripType == type ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(tripType == type ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .strokeBorder(tripType == type ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. 痛點

    private var painsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title: "出國前後，哪些事讓你最煩？", subtitle: "可複選，我們一項一項解決。")

            VStack(spacing: 10) {
                ForEach(OnboardingPain.allCases) { pain in
                    Button {
                        if selectedPains.contains(pain) {
                            selectedPains.remove(pain)
                        } else {
                            selectedPains.insert(pain)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(pain.emoji)
                            Text(pain.label)
                                .font(.subheadline.weight(.medium))
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: selectedPains.contains(pain) ? "checkmark.square.fill" : "square")
                                .foregroundStyle(selectedPains.contains(pain) ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .strokeBorder(selectedPains.contains(pain) ? Color.accentColor : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Spacer()
            continueButton { step = .solution }
        }
    }

    // MARK: - 4. 解方橋接

    private var displayedPains: [OnboardingPain] {
        let picked = OnboardingPain.allCases.filter { selectedPains.contains($0) }
        return picked.isEmpty ? [.forgetting, .customs, .overspend] : Array(picked.prefix(4))
    }

    private var solutionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title: "你說的這些，我們都準備好了", subtitle: "TravelGenius 針對你的困擾，逐項對應。")

            VStack(spacing: 12) {
                ForEach(displayedPains) { pain in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: pain.solution.symbol)
                            .font(.title3)
                            .foregroundStyle(.tint)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pain.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .strikethrough()
                            Text(pain.solution.title)
                                .font(.subheadline.weight(.semibold))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)

            Spacer()
            continueButton(title: "建立我的第一個行程") { step = .setup }
        }
    }

    // MARK: - 6. 處理動畫

    private var processingStep: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text(processingText)
                .font(.headline)
                .contentTransition(.opacity)
            Text("依你的目的地、日期與旅行型態客製")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .onAppear(perform: runProcessing)
    }

    // MARK: - Helpers

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.title, design: .rounded).weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }

    private func continueButton(title: String = "繼續", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .padding(.bottom, 20)
    }

    private func startProcessing() {
        step = .processing
    }

    private func runProcessing() {
        // 立即建立行程與清單，動畫只是醞釀感
        let country = StaticDataStore.shared.country(code: countryCode)
        let calendar = Calendar.current
        let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: endDate)).day ?? 0) + 1
        let trip = Trip(
            name: "\(country?.nameZh ?? countryCode)\(city.isEmpty ? "" : "・\(city)") \(max(days, 1)) 天",
            countryCode: countryCode,
            startDate: startDate,
            endDate: endDate,
            homeCurrencyCode: "TWD",
            localCurrencyCode: country?.currencyCode ?? "TWD",
            totalBudget: 0,
            tripType: tripType
        )
        trip.city = city
        context.insert(trip)
        PackingListGenerator.sync(trip: trip, context: context)
        appState.setActive(trip)
        createdTrip = trip

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            processingText = "正在客製你的打包清單…"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            step = .reveal
        }
    }

    private func finish(openPacking: Bool) {
        if openPacking {
            UserDefaults.standard.set(true, forKey: "startOnPackingTab")
        }
        WidgetSync.update(trip: createdTrip)
        onComplete()
    }
}
