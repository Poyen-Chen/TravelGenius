//
//  FirstLaunchGuideView.swift
//  TravelGenius
//
//  新用戶進入行程頁後，底部三步卡片。看完或略過寫入 hasSeenFirstLaunchGuide。
//

import SwiftUI

struct FirstLaunchGuideView: View {
    var onComplete: () -> Void

    @Environment(\.packmonTheme) private var theme
    @State private var page = 0

    private let steps = [
        "先建立一趟行程。",
        "清單會依目的地和天氣準備，把已打包的物品勾起來。",
        "查詢看能不能帶，知識看當地禮儀。",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(page + 1) / \(steps.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.colors.secondaryText)
                Spacer()
                Button("略過", action: onComplete)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colors.secondaryText)
            }
            Text(steps[page])
                .font(.headline)
                .foregroundStyle(theme.colors.text)
                .fixedSize(horizontal: false, vertical: true)
            Button(page == steps.count - 1 ? "開始使用" : "下一步") {
                if page == steps.count - 1 {
                    onComplete()
                } else {
                    withAnimation { page += 1 }
                }
            }
            .buttonStyle(PackmonPrimaryButtonStyle())
        }
        .padding(16)
        .background(theme.colors.elevatedSurface, in: RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous)
                .stroke(theme.colors.separator, lineWidth: 0.75)
        }
        .accessibilityElement(children: .contain)
    }
}
