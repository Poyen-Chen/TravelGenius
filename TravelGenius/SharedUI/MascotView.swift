//
//  MascotView.swift
//  TravelGenius
//
//  吉祥物「小旅犬」：SwiftUI shapes 繪製的簡約小狗＋對話泡泡。
//  表情隨情境變化（一般／開心／警戒）。
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

    private var earColor: Color { Color(red: 0.55, green: 0.38, blue: 0.24) }
    private var faceColor: Color { Color(red: 0.91, green: 0.76, blue: 0.55) }
    private var muzzleColor: Color { Color(red: 0.98, green: 0.93, blue: 0.83) }

    var body: some View {
        ZStack {
            // 垂耳
            HStack(spacing: size * 0.62) {
                Capsule().fill(earColor)
                    .frame(width: size * 0.26, height: size * 0.5)
                    .rotationEffect(.degrees(18))
                Capsule().fill(earColor)
                    .frame(width: size * 0.26, height: size * 0.5)
                    .rotationEffect(.degrees(-18))
            }
            .offset(y: -size * 0.18)

            // 臉
            Circle()
                .fill(faceColor)
                .frame(width: size, height: size)

            // 吻部
            Ellipse()
                .fill(muzzleColor)
                .frame(width: size * 0.52, height: size * 0.4)
                .offset(y: size * 0.18)

            // 鼻子
            RoundedRectangle(cornerRadius: size * 0.06)
                .fill(Color(red: 0.28, green: 0.2, blue: 0.16))
                .frame(width: size * 0.16, height: size * 0.11)
                .offset(y: size * 0.08)

            // 眼睛
            eyes

            // 嘴（依表情）
            mouth

            // 警戒符號
            if expression == .alert {
                Text("!")
                    .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.orange)
                    .offset(x: size * 0.58, y: -size * 0.42)
            }
        }
        .frame(width: size * 1.35, height: size * 1.2)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var eyes: some View {
        let eyeOffsetX = size * 0.2
        let eyeOffsetY = -size * 0.08
        if expression == .happy {
            // 開心：彎彎的眼睛
            HStack(spacing: size * 0.24) {
                HappyEye().stroke(Color.black.opacity(0.75), style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                    .frame(width: size * 0.16, height: size * 0.08)
                HappyEye().stroke(Color.black.opacity(0.75), style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                    .frame(width: size * 0.16, height: size * 0.08)
            }
            .offset(y: eyeOffsetY)
        } else {
            HStack(spacing: size * 0.28) {
                Circle().fill(Color.black.opacity(0.8)).frame(width: size * 0.11, height: size * 0.11)
                Circle().fill(Color.black.opacity(0.8)).frame(width: size * 0.11, height: size * 0.11)
            }
            .offset(x: expression == .alert ? 0 : 0, y: eyeOffsetY)
        }
        let _ = eyeOffsetX
    }

    @ViewBuilder
    private var mouth: some View {
        if expression == .happy {
            // 吐舌
            Capsule()
                .fill(Color(red: 0.93, green: 0.45, blue: 0.45))
                .frame(width: size * 0.14, height: size * 0.18)
                .offset(y: size * 0.3)
        }
    }
}

private struct HappyEye: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height)
        )
        return path
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
        .accessibilityLabel("小旅犬提醒：\(message)")
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
