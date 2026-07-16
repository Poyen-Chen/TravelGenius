//
//  TranslatedCardView.swift
//  TravelGenius
//

import SwiftUI

/// 醫療卡翻譯：固定醫療語句以離線語言包呈現，抵達依行程目的地自動預設語言
struct TranslatedCardView: View {
    let profile: MedicalProfile
    @State private var language: String

    init(profile: MedicalProfile, defaultLanguage: String) {
        self.profile = profile
        _language = State(initialValue: defaultLanguage)
    }

    private var translation: MedicalTranslation? {
        StaticDataStore.shared.medicalTranslations.languages[language]
    }

    var body: some View {
        List {
            if let t = translation {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t.cardTitle)
                            .font(.title3.weight(.bold))
                        Text(t.helpSentence)
                            .font(.body.weight(.medium))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.red)
                    }
                    .padding(.vertical, 4)
                }

                Section(header: bilingualHeader(t.name, "姓名")) {
                    Text(profile.fullName.isEmpty ? "—" : profile.fullName)
                }

                Section(header: bilingualHeader(t.bloodType, "血型")) {
                    Text(profile.bloodType == .unknown ? "—" : profile.bloodType.rawValue)
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                }

                Section(header: bilingualHeader(t.allergies, "過敏")) {
                    if profile.sortedAllergies.isEmpty {
                        Text("—").foregroundStyle(.secondary)
                    }
                    ForEach(profile.sortedAllergies) { allergy in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DrugMapper.translateAllergen(allergy.name, to: language) ?? allergy.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(allergy.severity == .severe ? .red : .primary)
                            Text("\(allergy.name)・\(allergy.type.label)・\(allergy.severity.label)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(header: bilingualHeader(t.medications, "用藥")) {
                    if profile.sortedMedications.isEmpty {
                        Text("—").foregroundStyle(.secondary)
                    }
                    ForEach(profile.sortedMedications) { medication in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(medication.genericName.isEmpty ? medication.brandName : medication.genericName)
                                .font(.body.weight(.medium))
                            Text([medication.brandName, medication.dosage, medication.schedule]
                                .filter { !$0.isEmpty }
                                .joined(separator: "・"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !profile.sortedVaccines.isEmpty {
                    Section(header: bilingualHeader(t.vaccines, "疫苗")) {
                        ForEach(profile.sortedVaccines) { vaccine in
                            LabeledContent(vaccine.name) {
                                Text(vaccine.date.formatted(date: .abbreviated, time: .omitted))
                            }
                        }
                    }
                }

                Section {
                } footer: {
                    Text("固定醫療語句為內建離線語言包（非即時機器翻譯）；過敏原與藥名以 WHO 國際學名對照。")
                }
            }
        }
        .navigationTitle("翻譯卡片")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(DrugMapper.supportedLanguages, id: \.self) { code in
                        Button {
                            language = code
                        } label: {
                            if code == language {
                                Label(DrugMapper.languageLabel(code), systemImage: "checkmark")
                            } else {
                                Text(DrugMapper.languageLabel(code))
                            }
                        }
                    }
                } label: {
                    Label(DrugMapper.languageLabel(language), systemImage: "globe")
                }
            }
        }
    }

    private func bilingualHeader(_ translated: String, _ zh: String) -> some View {
        HStack(spacing: 6) {
            Text(translated)
            Text(zh).foregroundStyle(.tertiary)
        }
    }
}
