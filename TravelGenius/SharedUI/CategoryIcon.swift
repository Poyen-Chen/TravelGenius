//
//  CategoryIcon.swift
//  TravelGenius
//

import SwiftUI

extension ExpenseCategory {
    var color: Color {
        switch self {
        case .food: .orange
        case .transport: .blue
        case .lodging: .indigo
        case .shopping: .pink
        case .entertainment: .purple
        case .other: .gray
        }
    }
}

struct CategoryIcon: View {
    let category: ExpenseCategory

    var body: some View {
        Image(systemName: category.symbolName)
            .font(.subheadline)
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(category.color.gradient, in: Circle())
            .accessibilityLabel(category.label)
    }
}
