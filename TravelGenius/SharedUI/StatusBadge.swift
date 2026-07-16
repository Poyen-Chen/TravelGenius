//
//  StatusBadge.swift
//  TravelGenius
//

import SwiftUI

extension RunwayStatus {
    var color: Color {
        switch self {
        case .safe: .green
        case .caution: .orange
        case .over: .red
        }
    }
}

struct StatusBadge: View {
    let status: RunwayStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 10, height: 10)
            Text(status.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(status.color.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("預算狀態：\(status.label)")
    }
}
