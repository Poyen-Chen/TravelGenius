//
//  FloatingMascotView.swift
//  TravelGenius
//
//  浮動小史萊姆：固定在右下角、底部分頁列上方；點一下可顯示提醒，
//  但不支援拖曳。對話泡泡不攔截下方 UI 操作。
//

import SwiftUI

struct FloatingMascotDock: View {
    @Environment(MascotState.self) private var mascot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if mascot.isExpanded {
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
                    .frame(maxWidth: 230, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    // The speech bubble remains visible, but gestures pass through to the app.
                    .allowsHitTesting(false)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }

            Button {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
                    mascot.isExpanded.toggle()
                }
            } label: {
                mascotHead
            }
            .buttonStyle(.plain)
            .accessibilityLabel(mascot.isExpanded ? "Jelly：\(mascot.message)" : "Jelly")
            .accessibilityHint(mascot.isExpanded ? "點一下隱藏提醒" : "點一下顯示提醒")
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 16)
            // Keeps the mascot above the tab bar and clear of its controls.
            .padding(.bottom, 82)
            .animation(reduceMotion ? nil : .spring(duration: 0.35), value: mascot.isExpanded)
    }

    private var mascotHead: some View {
        MascotView(expression: mascot.expression, size: 44)
            .padding(6)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}
