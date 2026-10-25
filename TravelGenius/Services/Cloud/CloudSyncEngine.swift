import Foundation
import SwiftData

protocol CloudTransport {
    @MainActor func fetchDocuments() async throws -> [RemoteCloudDocument]
    @MainActor func write(_ change: CloudWrite) async throws -> CloudWriteResult
}

extension SupabaseClient: CloudTransport {}

/// 兩台裝置都改了同一份資料；讓使用者選擇保留哪一版，不自動覆蓋。
struct CloudSyncConflict: Identifiable, Equatable {
    let key: CloudDocumentKey
    let localTitle: String?
    let remote: RemoteCloudDocument
    var id: String { key.description }
    var title: String { localTitle ?? remote.payload?.title ?? "" }
    var remoteDeleted: Bool { remote.deleted }
    var localDeleted: Bool { localTitle == nil }
}

enum CloudSyncError: LocalizedError, Equatable {
    case differentAccount
    case corruptState

    var errorDescription: String? {
        switch self {
        case .differentAccount: "這台手機的資料已經和另一個帳號同步過。第一版不支援切換帳號，請用原本的帳號登入。"
        case .corruptState: "同步紀錄損毀，為了避免覆蓋資料已暫停同步。"
        }
    }
}

struct CloudSyncSummary: Equatable {
    var uploaded = 0
    var downloaded = 0
    var deleted = 0
    var conflicts: [CloudSyncConflict] = []
}

/// 每份文件上次同步時的 revision 與內容雜湊，以及這台裝置綁定的帳號。
struct CloudSyncState: Codable, Equatable {
    struct Record: Codable, Equatable {
        var revision: Int64
        var hash: String
    }
    var realm: String?
    var records: [String: Record] = [:]

    static let deletedHash = "deleted"
}

/// 同步的觸發時機：啟動、回到前景、使用者按「立即同步」（docs/supabase-plan.md「同步規則」）。
@MainActor
final class CloudSyncEngine {
    private let context: ModelContext
    private let library: PackingLibraryStore?
    private let transport: CloudTransport
    private let stateURL: URL
    private let realm: String
    private let includeHealth: Bool

    init(context: ModelContext, library: PackingLibraryStore?, transport: CloudTransport,
         realm: String, includeHealth: Bool, stateURL: URL = CloudSyncEngine.defaultStateURL) {
        self.context = context; self.library = library; self.transport = transport
        self.realm = realm; self.includeHealth = includeHealth; self.stateURL = stateURL
    }

    nonisolated static var defaultStateURL: URL {
        URL.applicationSupportDirectory.appending(path: "PackSmartCloudSync.json")
    }

    static func resetState(at url: URL = defaultStateURL) { try? FileManager.default.removeItem(at: url) }

    // MARK: 同步

    func synchronize() async throws -> CloudSyncSummary {
        var state = try loadState()
        if let bound = state.realm, bound != realm { throw CloudSyncError.differentAccount }

        let remote = Dictionary(try await transport.fetchDocuments().map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        let local = try localDocuments()
        let keys = Set(local.keys).union(remote.keys).union(state.records.keys.compactMap(Self.key(from:)))
        var summary = CloudSyncSummary()

        for key in keys.sorted(by: { $0.description < $1.description }) {
            let localPayload = local[key]
            let remoteDocument = remote[key]
            let record = state.records[key.description]
            let localHash = localPayload?.hash ?? CloudSyncState.deletedHash
            let localChanged = record.map { $0.hash != localHash } ?? (localPayload != nil)
            let remoteChanged: Bool = {
                guard let record else { return remoteDocument != nil }
                guard let remoteDocument else { return false }
                return remoteDocument.revision != record.revision
            }()

            switch (localChanged, remoteChanged) {
            case (false, false):
                continue
            case (true, false):
                if remoteDocument == nil, localPayload == nil { state.records[key.description] = nil; continue }
                // 雲端沒有這份（例如帳號資料被清空）時從 revision 0 重新建立。
                try await push(key, payload: localPayload, expected: remoteDocument == nil ? 0 : record?.revision ?? 0,
                               state: &state, summary: &summary)
            case (false, true):
                try apply(remoteDocument, for: key, state: &state, summary: &summary)
            case (true, true):
                let remoteHash = remoteDocument.map { $0.deleted ? CloudSyncState.deletedHash : ($0.payload?.hash ?? "") }
                if let remoteDocument, remoteHash == localHash {
                    state.records[key.description] = .init(revision: remoteDocument.revision, hash: localHash)
                } else if let remoteDocument {
                    summary.conflicts.append(CloudSyncConflict(key: key, localTitle: localPayload?.title, remote: remoteDocument))
                }
            }
        }

        state.realm = realm
        try context.save()
        try saveState(state)
        return summary
    }

    /// 使用者選擇保留哪一版之後重新寫入。保留本機版本時以雲端目前的 revision 為基準。
    func resolve(_ conflict: CloudSyncConflict, keepLocal: Bool) async throws -> CloudSyncSummary {
        var state = try loadState()
        var summary = CloudSyncSummary()
        if keepLocal {
            let payload = try localDocuments()[conflict.key]
            try await push(conflict.key, payload: payload, expected: conflict.remote.revision, state: &state, summary: &summary)
        } else {
            try apply(conflict.remote, for: conflict.key, state: &state, summary: &summary)
        }
        try context.save()
        try saveState(state)
        return summary
    }

    private func push(_ key: CloudDocumentKey, payload: CloudPayload?, expected: Int64,
                      state: inout CloudSyncState, summary: inout CloudSyncSummary) async throws {
        let result = try await transport.write(CloudWrite(kind: key.kind, id: key.id, expectedRevision: expected,
                                                          payload: payload, deleted: payload == nil, mutationID: UUID()))
        if result.status == "applied" {
            state.records[key.description] = .init(revision: result.document.revision, hash: payload?.hash ?? CloudSyncState.deletedHash)
            summary.uploaded += 1
        } else {
            summary.conflicts.append(CloudSyncConflict(key: key, localTitle: payload?.title, remote: result.document))
        }
    }

    // MARK: 本機資料

    private func localDocuments() throws -> [CloudDocumentKey: CloudPayload] {
        var documents: [CloudDocumentKey: CloudPayload] = [:]
        for trip in try context.fetch(FetchDescriptor<Trip>()) {
            let cloud = CloudTrip(trip, includeHealth: includeHealth)
            let omitted = (trip.packingItems?.count ?? 0) - cloud.packingItems.count
            documents[CloudDocumentKey(kind: .trip, id: trip.id)] = CloudPayload(
                trip: cloud, healthSyncConsent: includeHealth ? true : nil, omittedPrivateCount: omitted > 0 ? omitted : nil)
        }
        for item in try libraryItems() where includeHealth || item.categoryRaw != PackingCategory.health.rawValue {
            documents[CloudDocumentKey(kind: .library, id: item.id)] = CloudPayload(
                library: CloudLibraryItem(item), healthSyncConsent: includeHealth ? true : nil)
        }
        return documents
    }

    private var libraryContext: ModelContext?
    private func libraryItems() throws -> [PackingLibraryItem] {
        guard let library else { return [] }
        if libraryContext == nil {
            _ = try library.essentials() // 先完成 UserDefaults → SwiftData 的一次性遷移
            libraryContext = ModelContext(library.container)
        }
        return try libraryContext!.fetch(FetchDescriptor<PackingLibraryItem>())
    }

    private func apply(_ remote: RemoteCloudDocument?, for key: CloudDocumentKey,
                       state: inout CloudSyncState, summary: inout CloudSyncSummary) throws {
        guard let remote, !remote.deleted, let payload = remote.payload else {
            try deleteLocal(key)
            if let remote { state.records[key.description] = .init(revision: remote.revision, hash: CloudSyncState.deletedHash) }
            else { state.records[key.description] = nil }
            summary.deleted += 1
            return
        }
        switch key.kind {
        case .trip:
            guard let cloud = payload.trip else { throw CloudSyncError.corruptState }
            let id = key.id
            let trip = try context.fetch(FetchDescriptor<Trip>(predicate: #Predicate { $0.id == id })).first ?? {
                let trip = Trip(name: cloud.name, countryCode: cloud.countryCode, startDate: cloud.startDate, endDate: cloud.endDate,
                                homeCurrencyCode: cloud.homeCurrencyCode, localCurrencyCode: cloud.localCurrencyCode,
                                totalBudget: 0, tripType: TripType(rawValue: cloud.tripTypeRaw) ?? .leisure)
                context.insert(trip)
                return trip
            }()
            cloud.apply(to: trip, in: context, includeHealth: includeHealth)
        case .library:
            guard let cloud = payload.library else { throw CloudSyncError.corruptState }
            _ = try libraryItems()
            guard let libraryContext else { return }
            let records = try libraryContext.fetch(FetchDescriptor<PackingLibraryItem>())
            // 兩台裝置離線各自新增同名用品時保留雲端那一份；本機那份已上傳的話，下次同步會送出刪除。
            for duplicate in records where duplicate.id != cloud.id && duplicate.normalizedName == PackingStaples.normalized(cloud.name) {
                libraryContext.delete(duplicate)
            }
            let record = records.first { $0.id == cloud.id } ?? {
                let record = PackingLibraryItem(.init(id: cloud.id, name: cloud.name, category: .other, quantity: 1))
                libraryContext.insert(record)
                return record
            }()
            cloud.apply(to: record)
            try libraryContext.save()
        }
        let applied = try localDocuments()[key]
        state.records[key.description] = .init(revision: remote.revision, hash: applied?.hash ?? payload.hash)
        summary.downloaded += 1
    }

    private func deleteLocal(_ key: CloudDocumentKey) throws {
        switch key.kind {
        case .trip:
            let id = key.id
            for trip in try context.fetch(FetchDescriptor<Trip>(predicate: #Predicate { $0.id == id })) { context.delete(trip) }
        case .library:
            _ = try libraryItems()
            guard let libraryContext else { return }
            for item in try libraryContext.fetch(FetchDescriptor<PackingLibraryItem>()) where item.id == key.id {
                if !includeHealth && item.categoryRaw == PackingCategory.health.rawValue { continue }
                libraryContext.delete(item)
            }
            try libraryContext.save()
        }
    }

    // MARK: 狀態檔

    private static func key(from raw: String) -> CloudDocumentKey? {
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let kind = CloudDocumentKind(rawValue: parts[0]), let id = UUID(uuidString: parts[1]) else { return nil }
        return CloudDocumentKey(kind: kind, id: id)
    }

    private func loadState() throws -> CloudSyncState {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return CloudSyncState() }
        do { return try JSONDecoder().decode(CloudSyncState.self, from: Data(contentsOf: stateURL)) }
        catch { throw CloudSyncError.corruptState }
    }

    private func saveState(_ state: CloudSyncState) throws {
        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
    }
}
