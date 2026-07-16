//
//  EmergencyScreenView.swift
//  TravelGenius
//
//  一頁緊急畫面：當地急救電話、血型、過敏、保險與聯絡人快撥。
//

import SwiftUI

struct EmergencyScreenView: View {
    let profile: MedicalProfile
    let countryCode: String

    @Environment(\.dismiss) private var dismiss

    private var country: Country? {
        StaticDataStore.shared.country(code: countryCode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let country {
                        dialButton(
                            title: "撥打當地急救電話",
                            subtitle: "\(country.flagEmoji) \(country.nameZh)・救護 \(country.emergency.ambulance)",
                            number: country.emergency.ambulance,
                            prominent: true
                        )
                    }

                    infoCard("血型", systemImage: "drop.fill") {
                        Text(profile.bloodType == .unknown ? "未填寫" : profile.bloodType.rawValue)
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                    }

                    if !profile.sortedAllergies.isEmpty {
                        infoCard("過敏", systemImage: "allergens") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(profile.sortedAllergies) { allergy in
                                    HStack {
                                        Text(allergy.name)
                                            .font(.title3.weight(allergy.severity == .severe ? .bold : .regular))
                                        if allergy.severity == .severe {
                                            Text("嚴重")
                                                .font(.caption.weight(.bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.red, in: Capsule())
                                                .foregroundStyle(.white)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }

                    if !profile.sortedMedications.isEmpty {
                        infoCard("用藥", systemImage: "pills.fill") {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(profile.sortedMedications) { medication in
                                    Text("\(medication.genericName.isEmpty ? medication.brandName : medication.genericName) \(medication.dosage)")
                                        .font(.body.weight(.medium))
                                }
                            }
                        }
                    }

                    if !profile.insurancePolicyNumber.isEmpty || !profile.insuranceProvider.isEmpty {
                        infoCard("保險", systemImage: "shield.fill") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(profile.insuranceProvider)　\(profile.insurancePolicyNumber)")
                                    .font(.body.weight(.medium))
                                if !profile.insurancePhone.isEmpty {
                                    Button {
                                        dial(profile.insurancePhone)
                                    } label: {
                                        Label("24hr 專線 \(profile.insurancePhone)", systemImage: "phone.fill")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }
                            }
                        }
                    }

                    ForEach(profile.sortedContacts) { contact in
                        dialButton(
                            title: "\(contact.name)（\(contact.relationship)）",
                            subtitle: contact.phone,
                            number: contact.phone,
                            prominent: false
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("緊急資訊")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("關閉") { dismiss() }
                }
            }
        }
        .tint(.red)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func dialButton(title: String, subtitle: String, number: String, prominent: Bool) -> some View {
        Button {
            dial(number)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "phone.fill")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(prominent ? .title3.weight(.bold) : .body.weight(.semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.borderedProminent)
        .tint(prominent ? .red : .red.opacity(0.75))
        .accessibilityLabel("\(title)，快撥 \(number)")
    }

    private func infoCard(_ title: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func dial(_ number: String) {
        let cleaned = number.replacingOccurrences(of: " ", with: "")
        guard let url = URL(string: "tel://\(cleaned)") else { return }
        UIApplication.shared.open(url)
    }
}
