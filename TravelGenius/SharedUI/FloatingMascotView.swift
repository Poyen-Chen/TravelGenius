//
//  FloatingMascotView.swift
//  TravelGenius
//
//  浮動小史萊姆：固定在右下角、底部分頁列上方；僅作為視覺提示，
//  不攔截操作，也不支援拖曳或展開。
//

import SwiftUI

struct FloatingMascotDock: View {
    @Environment(MascotState.self) private var mascot

    var body: some View {
        mascotHead
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 16)
            // Keeps the mascot above the tab bar and clear of its controls.
            .padding(.bottom, 82)
    }

    private var mascotHead: some View {
        MascotView(expression: mascot.expression, size: 44)
            .padding(6)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }

}
