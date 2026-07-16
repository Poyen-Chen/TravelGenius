//
//  MedicalProfileView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

struct MedicalProfileView: View {
    @Bindable var profile: MedicalProfile
    let activeCountryCode: String?

    @Environment(\.modelContext) private var context
    @State private var showingAllergyEditor = false
    @State private var showingMedicationEditor = false
    @State private var showingVaccineEditor = false
    @State private var showingContactEditor = false
    @State private var showingLargePrint = false
    @State private var showingEmergency = false

    private var defaultLanguage: String {
        DrugMapper.defaultLanguage(forCountry: activeCountryCode)
    }

    /// 完成度提示：缺少的關鍵欄位
    private var missingEssentials: [String] {
        var missing: [String] = []
        if profile.bloodType == .unknown { missing.append("血型") }
        if (profile.allergies ?? []).isEmpty { missing.append("過敏") }
        if profile.insurancePolicyNumber.isEmpty { missing.append("保單") }
        return missing
    }

    var body: some View {
        Form {
            if !missingEssentials.isEmpty {
                Section {
                    Label("建議補齊：\(missingEssentials.joined(separator: "、"))", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("基本資料") {
                TextField("姓名", text: $profile.fullName)
                Picker("血型", selection: $profile.bloodTypeRaw) {
                    ForEach(BloodType.allCases) { type in
                        Text(type.label).tag(type.rawValue)
                    }
                }
            }

            Section("過敏") {
                ForEach(profile.sortedAllergies) { allergy in
                    HStack {
                        Text(allergy.name)
                        Spacer()
                        Text("\(allergy.type.label)・\(allergy.severity.label)")
                            .font(.caption)
                            .foregroundStyle(allergy.severity == .severe ? .red : .secondary)
                    }
                }
                .onDelete { offsets in
                    delete(profile.sortedAllergies, at: offsets)
                }
                Button("新增過敏", systemImage: "plus") { showingAllergyEditor = true }
            }

            Section("用藥") {
                ForEach(profile.sortedMedications) { medication in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(medication.brandName)
                            if !medication.genericName.isEmpty {
                                Text(medication.genericName)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.tint.opacity(0.12), in: Capsule())
                                    .foregroundStyle(.tint)
                            }
                        }
                        if !medication.dosage.isEmpty || !medication.schedule.isEmpty {
                            Text([medication.dosage, medication.schedule].filter { !$0.isEmpty }.joined(separator: "・"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    delete(profile.sortedMedications, at: offsets)
                }
                Button("新增用藥", systemImage: "plus") { showingMedicationEditor = true }
            }

            Section("病史") {
                TextField("病史與手術紀錄（選填）", text: $profile.medicalHistoryNotes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("疫苗") {
                ForEach(profile.sortedVaccines) { vaccine in
                    LabeledContent(vaccine.name) {
                        Text(vaccine.date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .onDelete { offsets in
                    delete(profile.sortedVaccines, at: offsets)
                }
                Button("新增疫苗", systemImage: "plus") { showingVaccineEditor = true }
            }

            Section("保險") {
                TextField("保險公司", text: $profile.insuranceProvider)
                TextField("保單號碼", text: $profile.insurancePolicyNumber)
                TextField("24 小時專線", text: $profile.insurancePhone)
                    .keyboardType(.phonePad)
            }

            Section("緊急聯絡人") {
                ForEach(profile.sortedContacts) { contact in
                    LabeledContent("\(contact.name)（\(contact.relationship)）") {
                        Text(contact.phone)
                    }
                }
                .onDelete { offsets in
                    delete(profile.sortedContacts, at: offsets)
                }
                Button("新增聯絡人", systemImage: "plus") { showingContactEditor = true }
            }
        }
        .navigationTitle("醫療卡")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                NavigationLink {
                    TranslatedCardView(profile: profile, defaultLanguage: defaultLanguage)
                } label: {
                    Label("翻譯卡片", systemImage: "globe")
                }
                Button("大字模式", systemImage: "textformat.size") { showingLargePrint = true }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showingEmergency = true
            } label: {
                Label("緊急資訊", systemImage: "cross.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .sheet(isPresented: $showingAllergyEditor) { AllergyEditorView(profile: profile) }
        .sheet(isPresented: $showingMedicationEditor) { MedicationEditorView(profile: profile) }
        .sheet(isPresented: $showingVaccineEditor) { VaccineEditorView(profile: profile) }
        .sheet(isPresented: $showingContactEditor) { ContactEditorView(profile: profile) }
        .fullScreenCover(isPresented: $showingLargePrint) {
            LargePrintCardView(profile: profile, language: defaultLanguage)
        }
        .fullScreenCover(isPresented: $showingEmergency) {
            EmergencyScreenView(profile: profile, countryCode: activeCountryCode ?? "TW")
        }
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-showEmergency") { showingEmergency = true }
            if arguments.contains("-showLargePrint") { showingLargePrint = true }
        }
    }

    private func delete<T: PersistentModel>(_ items: [T], at offsets: IndexSet) {
        for index in offsets {
            context.delete(items[index])
        }
    }
}
