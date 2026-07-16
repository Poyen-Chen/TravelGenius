//
//  FloatingMascotView.swift
//  TravelGenius
//
//  右緣浮動小旅犬：可上下拖曳（位置記憶）、點一下縮成半露狗頭、再點展開訊息泡泡。
//

import SwiftUI

struct FloatingMascotDock: View {
    @Environment(MascotState.self) private var mascot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 垂直位置（0–1，相對可拖曳範圍），跨啟動記憶
    @AppStorage("mascotDockY") private var storedY: Double = 0.6
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let topInset: CGFloat = 70
            let bottomInset: CGFloat = 120
            let travel = max(proxy.size.height - topInset - bottomInset, 1)
            let y = min(max(topInset + travel * storedY + dragOffset, topInset), topInset + travel)

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
                            state = value.translation.height
                        }
                        .onEnded { value in
                            let landed = topInset + travel * storedY + value.translation.height
                            storedY = Double(min(max((landed - topInset) / travel, 0), 1))
                        }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(mascot.isExpanded ? "小旅犬：\(mascot.message)" : "小旅犬（已縮起）")
                .accessibilityHint("點一下\(mascot.isExpanded ? "縮起" : "展開")，拖曳可移動位置")
                .accessibilityAddTraits(.isButton)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: mascot.isExpanded ? -6 : 28, y: y)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: mascot.isExpanded)
    }

    private var dock: some View {
        HStack(alignment: .center, spacing: 6) {
            if mascot.isExpanded {
                Text(mascot.message)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.primary.opacity(0.08))
                    )
                    .frame(maxWidth: 230, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }

            MascotView(expression: mascot.expression, size: 44)
                .padding(6)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08)))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
    }
}
