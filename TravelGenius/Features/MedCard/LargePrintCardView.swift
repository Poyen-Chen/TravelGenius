//
//  LargePrintCardView.swift
//  TravelGenius
//
//  大字模式：就醫時隔著櫃檯出示，關鍵資訊雙語大字呈現。
//

import SwiftUI

struct LargePrintCardView: View {
    let profile: MedicalProfile
    let language: String

    @Environment(\.dismiss) private var dismiss

    private var translation: MedicalTranslation? {
        StaticDataStore.shared.medicalTranslations.languages[language]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let t = translation {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t.bloodType)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text(profile.bloodType == .unknown ? "—" : profile.bloodType.rawValue)
                                .font(.system(size: 64, weight: .heavy, design: .rounded))
                        }

                        if !profile.sortedAllergies.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(t.allergies)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                ForEach(profile.sortedAllergies) { allergy in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(DrugMapper.translateAllergen(allergy.name, to: language) ?? allergy.name)
                                            .font(.system(size: 34, weight: .bold))
                                            .foregroundStyle(allergy.severity == .severe ? .red : .primary)
                                        Text(allergy.name)
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        if !profile.sortedMedications.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(t.medications)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                ForEach(profile.sortedMedications) { medication in
                                    Text("\(medication.genericName.isEmpty ? medication.brandName : medication.genericName) \(medication.dosage)")
                                        .font(.system(size: 30, weight: .semibold))
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("大字模式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
