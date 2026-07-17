//
//  FloatingMascotView.swift
//  TravelGenius
//
//  浮動小史萊姆：左右兩緣皆可停靠（放開時吸附較近的一側）、上下拖曳（位置記憶）、
//  點一下只切換訊息泡泡，角色本身保持完整顯示。
//

import SwiftUI

struct FloatingMascotDock: View {
    @Environment(MascotState.self) private var mascot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 垂直位置（0–1，相對可拖曳範圍），跨啟動記憶
    @AppStorage("mascotDockY") private var storedY: Double = 0.6
    /// 停靠側（跨啟動記憶）
    @AppStorage("mascotDockOnLeft") private var dockOnLeft: Bool = false
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let topInset: CGFloat = 70
            let bottomInset: CGFloat = 120
            let travel = max(proxy.size.height - topInset - bottomInset, 1)
            let y = min(max(topInset + travel * storedY + dragOffset.height, topInset), topInset + travel)
            // 角色始終完整顯示；拖曳中跟著手指水平移動
            let restingX: CGFloat = dockOnLeft ? 6 : -6
            let x = restingX + dragOffset.width

            dock
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
                        mascot.isExpanded.toggle()
                    }
                }
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { value in
                            let landedY = topInset + travel * storedY + value.translation.height
                            storedY = Double(min(max((landedY - topInset) / travel, 0), 1))
                            // 依放開位置吸附較近的一側
                            let anchorX = dockOnLeft ? CGFloat(60) : proxy.size.width - 60
                            let landedX = anchorX + value.translation.width
                            withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
                                dockOnLeft = landedX < proxy.size.width / 2
                            }
                        }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(mascot.isExpanded ? "小史萊姆：\(mascot.message)" : "小史萊姆")
                .accessibilityHint("點一下\(mascot.isExpanded ? "隱藏" : "顯示")對話框，拖曳可上下移動或換到另一側")
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
