//
//  OnboardingView.swift
//  TravelGenius
//
//  首次啟動：四題使用者偏好（年齡／性別／同行／經驗）→ 建行程 → 處理動畫 → 清單揭曉。
//  偏好直接影響清單生成（「因為是…」分組看得見）。
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    var onComplete: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    private enum Step: Int, CaseIterable {
        case welcome, age, gender, party, experience, setup, processing, reveal
    }

    @State private var step: Step = .welcome
    @State private var ageBand: AgeBand = .adult
    @State private var gender: GenderPreference = .undisclosed
    @State private var party: TravelParty = .solo
    @State private var experience: TravelExperience = .some

    // 快速建行程
    @State private var countryCode = "JP"
    @State private var city = StaticDataStore.shared.defaultCity(countryCode: "JP")?.cityZh ?? ""
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
                    Button("略過") { finish(openChecklist: false) }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Group {
                switch step {
                case .welcome: welcomeStep
                case .age: ageStep
                case .gender: genderStep
                case .party: partyStep
                case .experience: experienceStep
                case .setup: OnboardingTripSetupView(
                    countryCode: $countryCode,
                    city: $city,
                    startDate: $startDate,
                    endDate: $endDate,
                    onGenerate: startProcessing
                )
                case .processing: processingStep
                case .reveal: OnboardingRevealView(trip: createdTrip) {
                    finish(openChecklist: true)
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
            MascotBubbleRow(expression: .happy, message: "嗨！我是小旅犬 🐾 回答四個小問題，我幫你把行李清單客製到位。")
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                Text("出國前，先看懂海關風險")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                Text("再拿到為你客製的打包清單與當地 Tips。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer()

            Button {
                step = .age
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

    // MARK: - 2–5. 偏好四問

    private var ageStep: some View {
        preferenceStep(
            title: "你的年齡層是？",
            subtitle: "不同年齡的必備品不一樣。",
            options: AgeBand.allCases,
            selection: $ageBand,
            label: { $0.label },
            emoji: { _ in nil },
            next: { step = .gender }
        )
    }

    private var genderStep: some View {
        preferenceStep(
            title: "你的性別是？",
            subtitle: "只用來調整個人用品建議，可以略過。",
            options: GenderPreference.allCases,
            selection: $gender,
            label: { $0.label },
            emoji: { _ in nil },
            next: { step = .party }
        )
    }

    private var partyStep: some View {
        preferenceStep(
            title: "這趟跟誰一起？",
            subtitle: "同行組成會改變清單內容。",
            options: TravelParty.allCases,
            selection: $party,
            label: { $0.label },
            emoji: { $0.emoji },
            next: { step = .experience }
        )
    }

    private var experienceStep: some View {
        preferenceStep(
            title: "出國經驗大概是？",
            subtitle: "新手我會多幫你備幾樣保命文件。",
            options: TravelExperience.allCases,
            selection: $experience,
            label: { $0.label },
            emoji: { _ in nil },
            next: { step = .setup }
        )
    }

    private func preferenceStep<T: Identifiable & Equatable>(
        title: String,
        subtitle: String,
        options: [T],
        selection: Binding<T>,
        label: @escaping (T) -> String,
        emoji: @escaping (T) -> String?,
        next: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title: title, subtitle: subtitle)

            VStack(spacing: 10) {
                ForEach(options) { option in
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        HStack(spacing: 12) {
                            if let emoji = emoji(option) {
                                Text(emoji).font(.title3)
                            }
                            Text(label(option))
                                .font(.body.weight(.semibold))
                            Spacer()
                            Image(systemName: selection.wrappedValue == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selection.wrappedValue == option ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .strokeBorder(selection.wrappedValue == option ? Color.accentColor : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Spacer()
            continueButton(action: next)
        }
    }

    // MARK: - 7. 處理動畫

    private var processingStep: some View {
        VStack(spacing: 20) {
            Spacer()
            MascotView(expression: .normal, size: 64)
            ProgressView()
                .controlSize(.large)
            Text(processingText)
                .font(.headline)
                .contentTransition(.opacity)
            Text("依你的目的地、日期、同行組成與經驗客製")
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
        // 先存偏好，生成器會讀取
        let preferences = UserPreferences(ageBand: ageBand, gender: gender, party: party, experience: experience)
        preferences.save()

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
            tripType: .leisure
        )
        trip.city = city
        context.insert(trip)
        PackingListGenerator.sync(trip: trip, context: context, preferences: preferences)
        appState.setActive(trip)
        createdTrip = trip

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            processingText = "正在依你的偏好客製清單…"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            step = .reveal
        }
    }

    private func finish(openChecklist: Bool) {
        if openChecklist {
            UserDefaults.standard.set(true, forKey: "startOnPackingTab")
        }
        WidgetSync.update(trip: createdTrip)
        onComplete()
    }
}
