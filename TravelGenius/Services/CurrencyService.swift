//
//  CurrencyService.swift
//  TravelGenius
//

import Foundation

struct CurrencyService {
    static let shared = CurrencyService(table: StaticDataStore.shared.exchangeRates)

    let table: ExchangeRateTable

    /// 1 單位 code 折合多少基準幣別
    private func rateToBase(_ code: String) -> Double? {
        if code == table.base { return 1 }
        return table.rates[code]
    }

    /// 1 單位 from 折合多少 to；查無匯率時回傳 1（原值記錄）
    func rate(from: String, to: String) -> Decimal {
        if from == to { return 1 }
        guard let f = rateToBase(from), let t = rateToBase(to), t != 0 else { return 1 }
        return Decimal(f / t)
    }

    func convert(_ amount: Decimal, from: String, to: String) -> Decimal {
        amount * rate(from: from, to: to)
    }
}
