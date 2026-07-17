//
//  FirstLaunchGuideView.swift
//  TravelGenius
//
//  首次完成基本設定後顯示的三頁功能導覽。
//

import SwiftUI

struct FirstLaunchGuideView: View {
    var onComplete: () -> Void

    @State private var page = 0

    private let slides: [GuideSlide] = [
        GuideSlide(
            title: "你的專屬 Checklist",
            description: "依照旅行方式與目的地，幫你推薦真正需要帶的物品。",
            accent: .blue,
            kind: .checklist
        ),
        GuideSlide(
            title: "出發前的重要提醒",
            description: "海關、出入境規定與當地文化資訊，出發前一次掌握。",
            accent: .orange,
            kind: .travelInfo
        ),
        GuideSlide(
            title: "認識 Packmon Jelly",
            description: "可愛的 Jelly 會陪你準備旅行，還會分享實用冷知識。",
            accent: .purple,
            kind: .jelly
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("略過", action: onComplete)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, PackSmartDesign.Spacing.medium)

            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    guidePage(slide)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 7) {
                ForEach(slides.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? slides[index].accent : Color.secondary.opacity(0.2))
                        .frame(width: index == page ? 24 : 7, height: 7)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: page)
            .padding(.bottom, PackSmartDesign.Spacing.medium)

            Button(page == slides.count - 1 ? "開始使用" : "下一步") {
                if page == slides.count - 1 {
                    onComplete()
                } else {
                    withAnimation { page += 1 }
                }
            }
            .buttonStyle(PackSmartPrimaryButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, PackSmartDesign.Spacing.large)
        }
        .background(PackSmartDesign.ColorToken.canvas)
    }

    private func guidePage(_ slide: GuideSlide) -> some View {
        VStack(spacing: PackSmartDesign.Spacing.large) {
            Spacer(minLength: PackSmartDesign.Spacing.medium)

            slideArtwork(for: slide)
                .frame(maxWidth: 330)

            VStack(spacing: PackSmartDesign.Spacing.small) {
                Text(slide.title)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                Text(slide.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, PackSmartDesign.Spacing.xLarge)

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func slideArtwork(for slide: GuideSlide) -> some View {
        switch slide.kind {
        case .checklist:
            guideScreenshot("OnboardingChecklistPreview", accent: slide.accent)

        case .travelInfo:
            guideScreenshot("OnboardingTipsPreview", accent: slide.accent)

        case .jelly:
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(slide.accent.opacity(0.13))
                    .frame(width: 210, height: 210)
                MascotView(expression: .happy, size: 125)
                Label("冷知識到站！", systemImage: "lightbulb.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(slide.accent, in: Capsule())
                    .offset(x: 14, y: -3)
            }
            .frame(height: 220)
        }
    }

    private func guideScreenshot(_ name: String, accent: Color) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(accent.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}

private struct GuideSlide {
    enum Kind {
        case checklist
        case travelInfo
        case jelly
    }

    let title: String
    let description: String
    let accent: Color
    let kind: Kind
}
