//
//  FloatingMascotView.swift
//  TravelGenius
//
//  浮動小史萊姆：左右兩緣皆可停靠（放開時吸附較近的一側）、上下拖曳（位置記憶）、
//  點一下縮成半露狗頭、再點展開訊息泡泡。
//

import SwiftUI

struct FloatingMascotDock: View {
    /// 由收合點開時呼叫（用來換一則冷知識）
    var onExpand: (() -> Void)? = nil

    @Environment(MascotState.self) private var mascot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 垂直位置（0–1，相對可拖曳範圍），跨啟動記憶
    @AppStorage("mascotDockY") private var storedY: Double = 0.6
    /// 停靠側（跨啟動記憶）
    @AppStorage("mascotDockOnLeft") private var dockOnLeft: Bool = false
    /// 拖曳中的即時位移（不經動畫，純跟手）
    @State private var dragTranslation: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let topInset: CGFloat = 70
            let bottomInset: CGFloat = 120
            let travel = max(proxy.size.height - topInset - bottomInset, 1)
            let y = min(max(topInset + travel * storedY + dragTranslation.height, topInset), topInset + travel)
            // 縮起時狗頭半露出停靠側；拖曳中跟著手指水平移動
            let restingX: CGFloat = mascot.isExpanded ? (dockOnLeft ? 6 : -6) : (dockOnLeft ? -28 : 28)
            let x = restingX + dragTranslation.width

            dock
                .contentShape(Rectangle())
                // 單一手勢同時處理點擊與拖曳：minimumDistance 0 → 起手零延遲、
                // 不需等待 tap/drag 消歧義；放開時依移動距離判斷是點擊還是拖曳
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging,
                               hypot(value.translation.width, value.translation.height) > 4 {
                                isDragging = true
                            }
                            if isDragging {
                                dragTranslation = value.translation
                            }
                        }
                        .onEnded { value in
                            defer { isDragging = false }
                            guard isDragging else {
                                // 視為點擊：切換展開／縮起
                                let willExpand = !mascot.isExpanded
                                withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
                                    mascot.isExpanded.toggle()
                                }
                                if willExpand {
                                    onExpand?()
                                }
                                return
                            }
                            // 落點：更新記憶位置（基準位置與位移互相抵銷，不跳動），
                            // 超出邊界或換側的部分以 spring 吸附
                            let landedY = topInset + travel * storedY + value.translation.height
                            storedY = Double(min(max((landedY - topInset) / travel, 0), 1))
                            let anchorX = dockOnLeft ? CGFloat(60) : proxy.size.width - 60
                            let landedX = anchorX + value.translation.width
                            withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
                                dockOnLeft = landedX < proxy.size.width / 2
                                dragTranslation = .zero
                            }
                        }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(mascot.isExpanded ? "小史萊姆：\(mascot.message)" : "小史萊姆（已縮起）")
                .accessibilityHint("點一下\(mascot.isExpanded ? "縮起" : "展開")，拖曳可上下移動或換到另一側")
                .accessibilityAddTraits(.isButton)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: dockOnLeft ? .topLeading : .topTrailing)
                .offset(x: x, y: y)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: mascot.isExpanded)
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: dockOnLeft)
    }

    private var dock: some View {
        HStack(alignment: .center, spacing: 6) {
            if dockOnLeft {
                mascotHead
                if mascot.isExpanded { bubble(edge: .leading) }
            } else {
                if mascot.isExpanded { bubble(edge: .trailing) }
                mascotHead
            }
        }
    }

    private var mascotHead: some View {
        MascotView(expression: mascot.expression, size: 44)
            .padding(6)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }

    private func bubble(edge: Edge) -> some View {
        Text(mascot.message)
            .font(.footnote)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
            .frame(maxWidth: 230, alignment: edge == .leading ? .leading : .trailing)
            .fixedSize(horizontal: false, vertical: true)
            .transition(reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity))
    }
}
