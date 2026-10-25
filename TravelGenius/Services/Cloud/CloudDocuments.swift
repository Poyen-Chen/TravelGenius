import CryptoKit
import Foundation
import SwiftData

/// 雲端文件格式 version 1（`supabase/migrations/202610260001_user_documents.sql`）。
/// 行程連同清單是一份文件；常備用品每項一份。支出、預算不上傳。
enum CloudDocumentKind: String, Codable { case trip, library }

struct CloudDocumentKey: Hashable, Codable, CustomStringConvertible {
    let kind: CloudDocumentKind
    let id: UUID
    var description: String { "\(kind.rawValue):\(id.uuidString.lowercased())" }
}

enum CloudCoding {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }()
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            if let date = formatter.date(from: value) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid date \(value)"))
        }
        return decoder
    }()
}

struct CloudPackingItem: Codable, Equatable {
    var id: UUID
    var name: String
    var catalogItemID: String?
    var categoryRaw: String
    var reasonKey: String
    var quantity: Int
    var unitWeightKg: Double?
    var isPacked: Bool
    var isCustom: Bool
    var sortIndex: Int

    init(_ item: PackingItem) {
        id = item.id; name = item.name; catalogItemID = item.catalogItemID; categoryRaw = item.categoryRaw
        reasonKey = item.reasonKey; quantity = item.quantity; unitWeightKg = item.unitWeightKg
        isPacked = item.isPacked; isCustom = item.isCustom; sortIndex = item.sortIndex
    }

    func apply(to item: PackingItem) {
        item.id = id; item.name = name; item.catalogItemID = catalogItemID; item.categoryRaw = categoryRaw
        item.reasonKey = reasonKey; item.quantity = quantity; item.unitWeightKg = unitWeightKg
        item.isPacked = isPacked; item.isCustom = isCustom; item.sortIndex = sortIndex
    }

    var isHealth: Bool { categoryRaw == PackingCategory.health.rawValue }
}

struct CloudTrip: Codable, Equatable {
    var id: UUID
    var name: String
    var countryCode: String
    var city: String
    var originCountryCode: String
    var originCity: String
    var startDate: Date
    var endDate: Date
    var homeCurrencyCode: String
    var localCurrencyCode: String
    var tripTypeRaw: String
    var isClosed: Bool
    var startedAt: Date?
    var completedAt: Date?
    var hasReviewedTravelRules: Bool
    var excludedPackingNamesRaw: String
    var excludedPackingIDsRaw: String
    /// 偏好、天氣、這趟安排三個快照原樣上傳，另一台裝置的推薦依據才會相同。
    var packingPreferencesRaw: String
    var packingWeatherRaw: String
    var packingContextRaw: String
    var packingReviewPending: Bool
    var createdAt: Date
    var packingItems: [CloudPackingItem]

    init(_ trip: Trip, includeHealth: Bool) {
        id = trip.id; name = trip.name; countryCode = trip.countryCode; city = trip.city
        originCountryCode = trip.originCountryCode; originCity = trip.originCity
        startDate = trip.startDate; endDate = trip.endDate
        homeCurrencyCode = trip.homeCurrencyCode; localCurrencyCode = trip.localCurrencyCode
        tripTypeRaw = trip.tripTypeRaw; isClosed = trip.isClosed; startedAt = trip.startedAt; completedAt = trip.completedAt
        hasReviewedTravelRules = trip.hasReviewedTravelRules
        excludedPackingNamesRaw = trip.excludedPackingNamesRaw; excludedPackingIDsRaw = trip.excludedPackingIDsRaw
        packingPreferencesRaw = trip.packingPreferencesRaw; packingWeatherRaw = trip.packingWeatherRaw
        packingContextRaw = trip.packingContextRaw; packingReviewPending = trip.packingReviewPending
        createdAt = trip.createdAt
        packingItems = (trip.packingItems ?? []).map(CloudPackingItem.init)
            .filter { includeHealth || !$0.isHealth }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    /// 套用雲端版本。沒有同意同步健康類時，保留本機原有的健康類物品，不會被雲端版本刪掉。
    @MainActor func apply(to trip: Trip, in context: ModelContext, includeHealth: Bool) {
        trip.id = id; trip.name = name; trip.countryCode = countryCode; trip.city = city
        trip.originCountryCode = originCountryCode; trip.originCity = originCity
        trip.startDate = startDate; trip.endDate = endDate
        trip.homeCurrencyCode = homeCurrencyCode; trip.localCurrencyCode = localCurrencyCode
        trip.tripTypeRaw = tripTypeRaw; trip.isClosed = isClosed; trip.startedAt = startedAt; trip.completedAt = completedAt
        trip.hasReviewedTravelRules = hasReviewedTravelRules
        trip.excludedPackingNamesRaw = excludedPackingNamesRaw; trip.excludedPackingIDsRaw = excludedPackingIDsRaw
        trip.packingPreferencesRaw = packingPreferencesRaw; trip.packingWeatherRaw = packingWeatherRaw
        trip.packingContextRaw = packingContextRaw; trip.packingReviewPending = packingReviewPending
        trip.createdAt = createdAt

        let existing = trip.packingItems ?? []
        let remoteIDs = Set(packingItems.map(\.id))
        for item in existing where !remoteIDs.contains(item.id) {
            if !includeHealth && item.categoryRaw == PackingCategory.health.rawValue { continue }
            context.delete(item)
        }
        for remote in packingItems {
            if let local = existing.first(where: { $0.id == remote.id }) {
                remote.apply(to: local)
            } else {
                let item = PackingItem(name: remote.name, category: PackingCategory(rawValue: remote.categoryRaw) ?? .other,
                                       reasonKey: remote.reasonKey)
                remote.apply(to: item)
                context.insert(item)
                item.trip = trip
            }
        }
    }
}

struct CloudLibraryItem: Codable, Equatable {
    var id: UUID
    var name: String
    var categoryRaw: String
    var quantity: Int
    var unitWeightKg: Double?
    var isEssential: Bool
    var sortIndex: Int
    var useCount: Int
    var lastUsedAt: Date

    init(_ item: PackingLibraryItem) {
        id = item.id; name = item.name; categoryRaw = item.categoryRaw; quantity = item.quantity
        unitWeightKg = item.unitWeightKg; isEssential = item.isEssential; sortIndex = item.sortIndex
        useCount = item.useCount; lastUsedAt = item.lastUsedAt
    }

    func apply(to item: PackingLibraryItem) {
        item.id = id; item.name = name; item.normalizedName = PackingStaples.normalized(name)
        item.categoryRaw = categoryRaw; item.quantity = quantity; item.unitWeightKg = unitWeightKg
        item.isEssential = isEssential; item.sortIndex = sortIndex; item.useCount = useCount; item.lastUsedAt = lastUsedAt
    }

    var isHealth: Bool { categoryRaw == PackingCategory.health.rawValue }
}

struct CloudPayload: Codable, Equatable {
    var version = 1
    var trip: CloudTrip?
    var library: CloudLibraryItem?
    /// 使用者另外同意同步健康類物品時才為 true；資料庫據此放行健康類物品。
    var healthSyncConsent: Bool?
    /// 沒有上傳的健康類物品數量，讓其他裝置知道這趟還有只存在原本手機的物品。
    var omittedPrivateCount: Int?

    /// 判斷內容是否改變。同意旗標不算內容：切換開關本身不應被當成本機修改，
    /// 真正多上傳或少上傳的健康類物品會反映在 packingItems 裡。
    var hash: String {
        var content = self
        content.healthSyncConsent = nil
        let data = (try? CloudCoding.encoder.encode(content)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    var title: String { trip?.name ?? library?.name ?? "" }
}

struct RemoteCloudDocument: Codable, Equatable {
    var kind: CloudDocumentKind
    var id: UUID
    var revision: Int64
    var payload: CloudPayload?
    var deleted: Bool

    var key: CloudDocumentKey { CloudDocumentKey(kind: kind, id: id) }
}

struct CloudWrite: Encodable {
    let kind: CloudDocumentKind
    let id: UUID
    let expectedRevision: Int64
    let payload: CloudPayload?
    let deleted: Bool
    let mutationID: UUID

    enum CodingKeys: String, CodingKey {
        case kind = "p_kind", id = "p_id", expectedRevision = "p_expected_revision"
        case payload = "p_payload", deleted = "p_deleted", mutationID = "p_mutation_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(id, forKey: .id)
        try container.encode(expectedRevision, forKey: .expectedRevision)
        try container.encode(payload, forKey: .payload) // 刪除時明確送出 null
        try container.encode(deleted, forKey: .deleted)
        try container.encode(mutationID, forKey: .mutationID)
    }
}

struct CloudWriteResult: Decodable {
    let status: String
    let document: RemoteCloudDocument
}
