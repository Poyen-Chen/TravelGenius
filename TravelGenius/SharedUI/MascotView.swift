//
//  MascotView.swift
//  TravelGenius
//
//  吉祥物「小史萊姆」：動畫 GIF（checklist-slime-idle）＋表情徽章。
//  表情隨情境變化（一般／開心／警戒）。
//

import SwiftUI
import UIKit
import ImageIO

enum MascotExpression {
    case normal
    case happy
    case alert
}

struct MascotView: View {
    var expression: MascotExpression = .normal
    var size: CGFloat = 56

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AnimatedGIFView(name: "checklist-slime-idle", isAnimating: !reduceMotion)
                .frame(width: size * 1.2, height: size * 1.2)
                .clipShape(Circle())

            // 表情徽章
            if expression == .alert {
                Text("!")
                    .font(.system(size: size * 0.4, weight: .heavy, design: .rounded))
                    .foregroundStyle(.orange)
                    .offset(x: size * 0.52, y: -size * 0.45)
            }
            if expression == .happy {
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(.yellow)
                    .offset(x: size * 0.5, y: -size * 0.42)
            }
        }
        .frame(width: size * 1.35, height: size * 1.2)
        .accessibilityHidden(true)
    }
}

/// 播放 bundle 內 GIF 的輕量元件（縮圖解碼控制記憶體；尊重減少動態設定）
struct AnimatedGIFView: UIViewRepresentable {
    let name: String
    var isAnimating: Bool = true

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        let (frames, duration) = Self.decodeFrames(named: name)
        if isAnimating && frames.count > 1 {
            imageView.animationImages = frames
            imageView.animationDuration = duration
            imageView.startAnimating()
        }
        imageView.image = frames.first
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        if isAnimating && !(imageView.isAnimating) && (imageView.animationImages?.count ?? 0) > 1 {
            imageView.startAnimating()
        } else if !isAnimating && imageView.isAnimating {
            imageView.stopAnimating()
        }
    }

    /// 以縮圖解碼（最長邊 240px）避免 512² × 40 幀吃掉數十 MB 記憶體
    private static func decodeFrames(named name: String) -> ([UIImage], TimeInterval) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "gif"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return ([], 0)
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 240,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        var frames: [UIImage] = []
        var duration: TimeInterval = 0
        for index in 0..<CGImageSourceGetCount(source) {
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, index, thumbnailOptions as CFDictionary) else { continue }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gifProperties = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let unclamped = gifProperties?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
            let clamped = gifProperties?[kCGImagePropertyGIFDelayTime] as? Double
            let delay = (unclamped ?? 0) > 0 ? unclamped! : (clamped ?? 0.1)
            duration += max(delay, 0.02)
            frames.append(UIImage(cgImage: cgImage))
        }
        return (frames, duration)
    }
}

/// 吉祥物＋對話泡泡橫列（onboarding 等處使用）
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
