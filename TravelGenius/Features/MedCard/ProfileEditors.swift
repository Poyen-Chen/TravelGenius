//
//  ProfileEditors.swift
//  TravelGenius
//
//  醫療卡各項目的新增編輯 sheet。
//

import SwiftUI
import SwiftData

struct AllergyEditorView: View {
    let profile: MedicalProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var type: AllergyType = .drug
    @State private var severity: AllergySeverity = .mild

    /// 常見過敏原快選
    private var commonAllergens: [String] {
        StaticDataStore.shared.medicalTranslations.allergens.map(\.zh)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("過敏原（例如：盤尼西林）", text: $name)
                Picker("類型", selection: $type) {
                    ForEach(AllergyType.allCases) { Text($0.label).tag($0) }
                }
                Picker("嚴重度", selection: $severity) {
                    ForEach(AllergySeverity.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                if name.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(commonAllergens, id: \.self) { allergen in
                                    Button(allergen) { name = allergen }
                                        .buttonStyle(.bordered)
                                        .font(.footnote)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    } header: {
                        Text("常見過敏原")
                    }
                }
            }
            .navigationTitle("新增過敏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        let allergy = AllergyRecord(name: name.trimmingCharacters(in: .whitespaces), type: type, severity: severity)
                        allergy.profile = profile
                        context.insert(allergy)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct MedicationEditorView: View {
    let profile: MedicalProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var brandName = ""
    @State private var genericName = ""
    @State private var dosage = ""
    @State private var schedule = ""

    private var suggestions: [DrugEntry] {
        guard genericName.isEmpty else { return [] }
        return Array(DrugMapper.suggestions(for: brandName).prefix(3))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("商品名（例如：普拿疼）", text: $brandName)
                    if !suggestions.isEmpty {
                        ForEach(suggestions) { entry in
                            Button {
                                brandName = entry.brandZh
                                genericName = entry.generic
                            } label: {
                                HStack {
                                    Text("\(entry.brandZh) → \(entry.generic)")
                                        .font(.footnote)
                                    Spacer()
                                    Text(entry.genericZh)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    TextField("國際學名（自動對照，可手動修改）", text: $genericName)
                        .autocorrectionDisabled()
                } header: {
                    Text("藥品")
                } footer: {
                    Text("以學名建檔，海外就醫與購藥不出錯。學名對照參考 WHO 國際非專利藥名（INN）與台灣食藥署藥品許可證資料庫。")
                }

                Section("服用方式") {
                    TextField("劑量（例如：500mg）", text: $dosage)
                    TextField("頻率（例如：每日 2 次）", text: $schedule)
                }
            }
            .navigationTitle("新增用藥")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        let medication = Medication(
                            brandName: brandName.trimmingCharacters(in: .whitespaces),
                            genericName: genericName.trimmingCharacters(in: .whitespaces),
                            dosage: dosage.trimmingCharacters(in: .whitespaces),
                            schedule: schedule.trimmingCharacters(in: .whitespaces)
                        )
                        medication.profile = profile
                        context.insert(medication)
                        dismiss()
                    }
                    .disabled(brandName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct VaccineEditorView: View {
    let profile: MedicalProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                TextField("疫苗名稱（例如：COVID-19）", text: $name)
                DatePicker("接種日期", selection: $date, in: ...Date.now, displayedComponents: .date)
            }
            .navigationTitle("新增疫苗")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        let vaccine = VaccineRecord(name: name.trimmingCharacters(in: .whitespaces), date: date)
                        vaccine.profile = profile
                        context.insert(vaccine)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct ContactEditorView: View {
    let profile: MedicalProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var relationship = ""
    @State private var phone = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("姓名", text: $name)
                TextField("關係（例如：配偶）", text: $relationship)
                TextField("電話（含國碼，例如 +886…）", text: $phone)
                    .keyboardType(.phonePad)
            }
            .navigationTitle("新增聯絡人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        let contact = EmergencyContact(
                            name: name.trimmingCharacters(in: .whitespaces),
                            relationship: relationship.trimmingCharacters(in: .whitespaces),
                            phone: phone.trimmingCharacters(in: .whitespaces)
                        )
                        contact.profile = profile
                        context.insert(contact)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || phone.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
