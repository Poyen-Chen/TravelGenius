//
//  MascotView.swift
//  TravelGenius
//
//  吉祥物「小史萊姆」與對話泡泡。
//  警戒狀態會額外顯示提示符號。
//

import SwiftUI

enum MascotExpression {
    case normal
    case happy
    case alert
}

struct MascotView: View {
    var expression: MascotExpression = .normal
    var size: CGFloat = 56

    private var iconDiameter: CGFloat { size * 1.36 }

    var body: some View {
        ZStack {
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemBackground))

                Image("PackmonSlime")
                    .resizable()
                    .scaledToFill()
                    .frame(width: iconDiameter, height: iconDiameter)
                    .scaleEffect(1.28)
            }
            .frame(width: iconDiameter, height: iconDiameter)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.12), radius: size * 0.08, y: size * 0.04)

            if expression == .alert {
                Text("!")
                    .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.orange)
                    .shadow(color: .white, radius: 1)
                    .offset(x: size * 0.65, y: -size * 0.58)
            }
        }
        .frame(width: size * 1.48, height: size * 1.48)
        .accessibilityHidden(true)
    }
}

/// 吉祥物＋對話泡泡橫列（清單頁頂、Tips 查詢結果、空狀態共用）
struct MascotBubbleRow: View {
    var expression: MascotExpression = .normal
    let message: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            MascotView(expression: expression, size: 46)
            Text(message)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    BubbleShape()
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("小史萊姆提醒：\(message)")
    }
}

private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 14
        let tailSize: CGFloat = 8
        var path = Path(
            roundedRect: CGRect(x: rect.minX + tailSize, y: rect.minY, width: rect.width - tailSize, height: rect.height),
            cornerRadius: radius
        )
        // 左側小尾巴
        path.move(to: CGPoint(x: rect.minX + tailSize, y: rect.midY - tailSize))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + tailSize, y: rect.midY + tailSize))
        path.closeSubpath()
        return path
    }
}
