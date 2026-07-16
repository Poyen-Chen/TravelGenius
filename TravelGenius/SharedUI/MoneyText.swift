//
//  MoneyText.swift
//  TravelGenius
//

import SwiftUI

struct MoneyText: View {
    let amount: Decimal
    let currencyCode: String

    var body: some View {
        let decimals = StaticDataStore.shared.currency(code: currencyCode)?.decimals ?? 2
        Text(amount, format: .currency(code: currencyCode).precision(.fractionLength(0...decimals)))
            .monospacedDigit()
    }
}
