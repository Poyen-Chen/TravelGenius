//
//  OnboardingView.swift
//  TravelGenius
//

import SwiftUI

/// 首次啟動只完成基本偏好；行程由主畫面的三步驟流程建立。
struct OnboardingView: View {
    var onComplete: () -> Void

    private enum Step: Int, CaseIterable {
        case welcome
        case age
        case gender
        case party
        case experience
    }

    @State private var step: Step = .welcome
    @State private var ageBand: AgeBand = .adult
    @State private var gender: GenderPreference = .undisclosed
    @State private var party: TravelParty = .solo
    @State private var experience: TravelExperience = .some

    private var progress: Double {
        Double(step.rawValue) / Double(Step.allCases.count - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ProgressView(value: progress)
                    .tint(.accentColor)
                    .accessibilityLabel("基本設定進度")
                    .accessibilityValue("\(Int(progress * 100))%")
                Button("略過", action: finish)
                    .font(.footnote)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal)

            Group {
                switch step {
                case .welcome: welcomeStep
                case .age:
                    preferenceStep(
                        title: "你的年齡層是？",
                        subtitle: "不同年齡的必備品不一樣。",
                        options: AgeBand.allCases,
                        selection: $ageBand,
                        label: { $0.label },
                        next: { step = .gender }
                    )
                case .gender:
                    preferenceStep(
                        title: "你的性別是？",
                        subtitle: "只用來調整個人用品建議，也可以選擇不透露。",
                        options: GenderPreference.allCases,
                        selection: $gender,
                        label: { $0.label },
                        next: { step = .party }
                    )
                case .party:
                    preferenceStep(
                        title: "通常跟誰旅行？",
                        subtitle: "建立行程後仍可在基本設定修改。",
                        options: TravelParty.allCases,
                        selection: $party,
                        label: { $0.label },
                        next: { step = .experience }
                    )
                case .experience:
                    preferenceStep(
                        title: "出國經驗大概是？",
                        subtitle: "第一次出國會多一些文件與保險提醒。",
                        options: TravelExperience.allCases,
                        selection: $experience,
                        label: { $0.label },
                        buttonTitle: "完成基本設定",
                        next: finish
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(PackSmartDesign.ColorToken.canvas)
    }

    private var welcomeStep: some View {
        VStack(spacing: PackSmartDesign.Spacing.large) {
            Spacer()
            MascotBubbleRow(expression: .happy, message: "回答四個小問題，我會依你的旅行方式調整打包建議。")
                .padding(.horizontal, PackSmartDesign.Spacing.large)

            VStack(spacing: PackSmartDesign.Spacing.small) {
                Text("先把每趟旅程準備好")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                Text("建立行程後，你會拿到專屬清單、海關風險與當地 Tips。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, PackSmartDesign.Spacing.xLarge)
            Spacer()

            Button("開始設定") { step = .age }
                .buttonStyle(PackSmartPrimaryButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, PackSmartDesign.Spacing.large)
        }
    }

    private func preferenceStep<T: Identifiable & Equatable>(
        title: String,
        subtitle: String,
        options: [T],
        selection: Binding<T>,
        label: @escaping (T) -> String,
        buttonTitle: String = "繼續",
        next: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: PackSmartDesign.Spacing.medium) {
            VStack(alignment: .leading, spacing: PackSmartDesign.Spacing.small) {
                Text(title)
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, PackSmartDesign.Spacing.large)

            VStack(spacing: PackSmartDesign.Spacing.small) {
                ForEach(options) { option in
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        HStack(spacing: 12) {
                            Text(label(option))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: selection.wrappedValue == option ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selection.wrappedValue == option ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        }
                        .padding()
                        .frame(minHeight: 52)
                        .background(
                            PackSmartDesign.ColorToken.elevatedSurface,
                            in: RoundedRectangle(cornerRadius: PackSmartDesign.Radius.medium, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: PackSmartDesign.Radius.medium, style: .continuous)
                                .stroke(selection.wrappedValue == option ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection.wrappedValue == option ? .isSelected : [])
                }
            }
            .padding(.horizontal)

            Spacer()
            Button(buttonTitle, action: next)
                .buttonStyle(PackSmartPrimaryButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, PackSmartDesign.Spacing.large)
        }
    }

    private func finish() {
        UserPreferences(
            ageBand: ageBand,
            gender: gender,
            party: party,
            experience: experience
        ).save()
        onComplete()
    }
}
