//
//  FloatingMascotView.swift
//  TravelGenius
//
//  浮動小史萊姆：貼右緣，可上下拖曳（位置記憶），點一下展開／收起。
//   ・展開：完整露出 + 對話泡泡（並換一則冷知識）
//   ・收起：狗頭半露右緣，泡泡隱藏
//  對話泡泡不攔截下方 UI 操作；空白區不吃觸控（點得到 App）。
//

import SwiftUI

struct FloatingMascotDock: View {
    /// 展開時呼叫（用來換下一則冷知識）。
    var onExpand: (() -> Void)? = nil

    @Environment(MascotState.self) private var mascot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 垂直位置（容器高度的比例，0=最上、1=最下），可拖曳記憶。
    @AppStorage("mascotDockYFraction") private var yFraction: Double = 0.72

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    /// 收起時往右藏的位移（半露右緣）。
    private let peekInset: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let topLimit: CGFloat = 90
            let bottomLimit = max(topLimit, h - 110)
            let y = min(max(yFraction * h + dragOffset, topLimit), bottomLimit)

            HStack(alignment: .center, spacing: 8) {
                if mascot.isExpanded && !isDragging {
                    bubble
                }
                head(height: h)
            }
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .offset(x: mascot.isExpanded ? 0 : peekInset)
            .position(x: geo.size.width / 2, y: y)
            .animation(reduceMotion ? nil : .spring(duration: 0.35), value: mascot.isExpanded)
        }
        .ignoresSafeArea(.keyboard)
    }

    private var bubble: some View {
        Text(mascot.message)
            .font(.footnote)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
            .frame(maxWidth: 210, alignment: .trailing)
            .fixedSize(horizontal: false, vertical: true)
            // 泡泡可見但不攔截手勢，讓下方 UI 照常操作。
            .allowsHitTesting(false)
            .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
    }

    private func head(height: CGFloat) -> some View {
        MascotView(expression: mascot.expression, size: 44)
            .padding(6)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let committed = (yFraction * height + value.translation.height) / height
                        yFraction = min(max(committed, 0.12), 0.9)
                        dragOffset = 0
                        isDragging = false
                    }
            )
            .onTapGesture { toggle() }
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(mascot.isExpanded ? "小史萊姆：\(mascot.message)" : "小史萊姆")
            .accessibilityHint("點一下\(mascot.isExpanded ? "收起" : "展開")提醒，上下拖曳可移動位置")
    }

    private func toggle() {
        let willExpand = !mascot.isExpanded
        withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
            mascot.isExpanded.toggle()
        }
        if willExpand { onExpand?() }
    }
}
