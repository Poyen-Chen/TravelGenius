//
//  DemoSeeder.swift
//  TravelGenius
//
//  以 -seedDemo 啟動引數載入示範資料，供開發與截圖驗證使用。
//

import Foundation
import SwiftData

enum DemoSeeder {
    @MainActor
    static func seedIfNeeded(into context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Trip>())) ?? 0
        guard count == 0 else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -2, to: today),
              let end = calendar.date(byAdding: .day, value: 2, to: today) else { return }

        let trip = Trip(
            name: "東京商務行程",
            countryCode: "JP",
            startDate: start,
            endDate: end,
            homeCurrencyCode: "TWD",
            localCurrencyCode: "JPY",
            totalBudget: 40000,
            tripType: .business
        )
        trip.city = "東京"
        context.insert(trip)

        let rate = CurrencyService.shared.rate(from: "JPY", to: "TWD")
        let entries: [(day: Int, amount: Decimal, category: ExpenseCategory, note: String, reimbursable: Bool)] = [
            (-2, 4200, .transport, "機場計程車", true),
            (-2, 1850, .food, "拉麵晚餐", true),
            (-2, 12000, .lodging, "商務旅館", true),
            (-1, 980, .food, "早餐咖啡", true),
            (-1, 1600, .transport, "地鐵一日券", true),
            (-1, 3200, .food, "居酒屋", true),
            (-1, 5400, .shopping, "伴手禮", false),
            (0, 750, .food, "便利商店", true),
            (0, 2800, .entertainment, "美術館門票", false),
            (0, 1450, .food, "午餐定食", true),
            (0, 2400, .food, "商務晚餐", true),
            (0, 1200, .transport, "計程車", true),
        ]
        for entry in entries {
            guard let base = calendar.date(byAdding: .day, value: entry.day, to: today),
                  let time = calendar.date(byAdding: .hour, value: 12 + entry.day, to: base) else { continue }
            let expense = Expense(
                amount: entry.amount,
                currencyCode: "JPY",
                rateToHome: rate,
                category: entry.category,
                note: entry.note,
                date: time,
                trip: trip
            )
            expense.isReimbursable = entry.reimbursable
            context.insert(expense)
        }

        PackingListGenerator.sync(trip: trip, context: context)
        for item in (trip.packingItems ?? []).prefix(5) {
            item.isPacked = true
        }

        seedMedicalProfile(into: context)
        try? context.save()
    }

    @MainActor
    private static func seedMedicalProfile(into context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<MedicalProfile>())) ?? 0
        guard existing == 0 else { return }

        let profile = MedicalProfile()
        profile.fullName = "陳柏彥"
        profile.bloodType = .oPositive
        profile.medicalHistoryNotes = "高血壓（控制中）"
        profile.insuranceProvider = "AIA"
        profile.insurancePolicyNumber = "AIA-88231"
        profile.insurancePhone = "+886-2-8752-0000"
        context.insert(profile)

        let allergy1 = AllergyRecord(name: "盤尼西林", type: .drug, severity: .severe)
        allergy1.profile = profile
        let allergy2 = AllergyRecord(name: "花生", type: .food, severity: .mild)
        allergy2.profile = profile
        context.insert(allergy1)
        context.insert(allergy2)

        let med1 = Medication(brandName: "普拿疼", genericName: "Paracetamol", dosage: "500mg", schedule: "需要時")
        med1.profile = profile
        let med2 = Medication(brandName: "脈優", genericName: "Amlodipine", dosage: "5mg", schedule: "每日 1 次")
        med2.profile = profile
        context.insert(med1)
        context.insert(med2)

        let calendar = Calendar.current
        if let covidDate = calendar.date(byAdding: .month, value: -8, to: .now),
           let fluDate = calendar.date(byAdding: .month, value: -9, to: .now) {
            let vaccine1 = VaccineRecord(name: "COVID-19 追加劑", date: covidDate)
            vaccine1.profile = profile
            let vaccine2 = VaccineRecord(name: "流感疫苗", date: fluDate)
            vaccine2.profile = profile
            context.insert(vaccine1)
            context.insert(vaccine2)
        }

        let contact = EmergencyContact(name: "陳美惠", relationship: "配偶", phone: "+886-912-345-678")
        contact.profile = profile
        context.insert(contact)
    }
}
