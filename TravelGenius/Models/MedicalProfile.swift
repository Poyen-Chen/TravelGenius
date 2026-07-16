//
//  MedicalProfile.swift
//  TravelGenius
//

import Foundation
import SwiftData

enum BloodType: String, Codable, CaseIterable, Identifiable {
    case aPositive = "A+"
    case aNegative = "A-"
    case bPositive = "B+"
    case bNegative = "B-"
    case oPositive = "O+"
    case oNegative = "O-"
    case abPositive = "AB+"
    case abNegative = "AB-"
    case unknown = "unknown"

    var id: String { rawValue }

    var label: String {
        self == .unknown ? "不確定" : rawValue
    }
}

enum AllergyType: String, Codable, CaseIterable, Identifiable {
    case drug
    case food
    case environment

    var id: String { rawValue }

    var label: String {
        switch self {
        case .drug: "藥物"
        case .food: "食物"
        case .environment: "環境"
        }
    }
}

enum AllergySeverity: String, Codable, CaseIterable, Identifiable {
    case mild
    case severe

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mild: "輕微"
        case .severe: "嚴重"
        }
    }
}

/// 個人醫療卡（單一檔案，不隸屬任何行程）
@Model
final class MedicalProfile {
    var fullName: String = ""
    var bloodTypeRaw: String = BloodType.unknown.rawValue
    var medicalHistoryNotes: String = ""
    var insuranceProvider: String = ""
    var insurancePolicyNumber: String = ""
    var insurancePhone: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Medication.profile)
    var medications: [Medication]? = []

    @Relationship(deleteRule: .cascade, inverse: \AllergyRecord.profile)
    var allergies: [AllergyRecord]? = []

    @Relationship(deleteRule: .cascade, inverse: \VaccineRecord.profile)
    var vaccines: [VaccineRecord]? = []

    @Relationship(deleteRule: .cascade, inverse: \EmergencyContact.profile)
    var contacts: [EmergencyContact]? = []

    init() {}

    var bloodType: BloodType {
        get { BloodType(rawValue: bloodTypeRaw) ?? .unknown }
        set { bloodTypeRaw = newValue.rawValue }
    }

    var sortedMedications: [Medication] { (medications ?? []).sorted { $0.brandName < $1.brandName } }
    var sortedAllergies: [AllergyRecord] {
        (allergies ?? []).sorted {
            ($0.severity == .severe ? 0 : 1, $0.name) < ($1.severity == .severe ? 0 : 1, $1.name)
        }
    }
    var sortedVaccines: [VaccineRecord] { (vaccines ?? []).sorted { $0.date > $1.date } }
    var sortedContacts: [EmergencyContact] { (contacts ?? []).sorted { $0.name < $1.name } }
}

@Model
final class Medication {
    var brandName: String = ""
    /// 國際學名（例如 Paracetamol），海外就醫購藥的共通語言
    var genericName: String = ""
    var dosage: String = ""
    var schedule: String = ""
    var profile: MedicalProfile?

    init(brandName: String, genericName: String, dosage: String = "", schedule: String = "") {
        self.brandName = brandName
        self.genericName = genericName
        self.dosage = dosage
        self.schedule = schedule
    }
}

@Model
final class AllergyRecord {
    var name: String = ""
    var typeRaw: String = AllergyType.drug.rawValue
    var severityRaw: String = AllergySeverity.mild.rawValue
    var profile: MedicalProfile?

    init(name: String, type: AllergyType, severity: AllergySeverity) {
        self.name = name
        self.typeRaw = type.rawValue
        self.severityRaw = severity.rawValue
    }

    var type: AllergyType {
        get { AllergyType(rawValue: typeRaw) ?? .drug }
        set { typeRaw = newValue.rawValue }
    }

    var severity: AllergySeverity {
        get { AllergySeverity(rawValue: severityRaw) ?? .mild }
        set { severityRaw = newValue.rawValue }
    }
}

@Model
final class VaccineRecord {
    var name: String = ""
    var date: Date = Date()
    var profile: MedicalProfile?

    init(name: String, date: Date) {
        self.name = name
        self.date = date
    }
}

@Model
final class EmergencyContact {
    var name: String = ""
    var relationship: String = ""
    var phone: String = ""
    var profile: MedicalProfile?

    init(name: String, relationship: String, phone: String) {
        self.name = name
        self.relationship = relationship
        self.phone = phone
    }
}
