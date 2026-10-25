import Foundation
import SwiftData

/// 記憶體裡的雲端，規則照 supabase/migrations：revision 比對、mutation 冪等、健康類需同意。
@MainActor final class FakeCloud {
    var documents: [CloudDocumentKey: RemoteCloudDocument] = [:]
    var mutations: [CloudDocumentKey: UUID] = [:]
    var offline = false

    func write(_ change: CloudWrite) throws -> CloudWriteResult {
        if offline { throw SupabaseError.offline }
        let key = CloudDocumentKey(kind: change.kind, id: change.id)
        if let payload = change.payload, payload.healthSyncConsent != true {
            let items = payload.trip?.packingItems ?? []
            precondition(!items.contains(where: \.isHealth) && payload.library?.isHealth != true,
                         "健康類物品在沒有同意時被上傳")
        }
        if change.expectedRevision == 0, documents[key] == nil {
            documents[key] = .init(kind: change.kind, id: change.id, revision: 1, payload: change.payload, deleted: change.deleted)
            mutations[key] = change.mutationID
            return .init(status: "applied", document: documents[key]!)
        }
        guard let current = documents[key] else { preconditionFailure("document missing") }
        if mutations[key] == change.mutationID { return .init(status: "applied", document: current) }
        guard current.revision == change.expectedRevision else { return .init(status: "conflict", document: current) }
        documents[key] = .init(kind: change.kind, id: change.id, revision: current.revision + 1, payload: change.payload, deleted: change.deleted)
        mutations[key] = change.mutationID
        return .init(status: "applied", document: documents[key]!)
    }
}

@MainActor struct FakeTransport: CloudTransport {
    let cloud: FakeCloud
    func fetchDocuments() async throws -> [RemoteCloudDocument] {
        if cloud.offline { throw SupabaseError.offline }
        return Array(cloud.documents.values)
    }
    func write(_ change: CloudWrite) async throws -> CloudWriteResult { try cloud.write(change) }
}

/// 一台模擬的手機：自己的 SwiftData、常備用品庫與同步狀態檔。
@MainActor final class Device {
    let container: ModelContainer
    let library: PackingLibraryStore
    let stateURL: URL
    var context: ModelContext { container.mainContext }

    init(_ name: String, root: URL) throws {
        let schema = Schema([Trip.self, Expense.self, PackingItem.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let librarySchema = Schema([PackingLibraryItem.self, PackingLibraryMigration.self])
        let defaults = UserDefaults(suiteName: "cloud-sync-\(name)-\(UUID().uuidString)")!
        library = PackingLibraryStore(container: try ModelContainer(for: librarySchema, configurations: [
            ModelConfiguration(schema: librarySchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]), defaults: defaults)
        stateURL = root.appending(path: "\(name)-state.json")
    }

    func engine(_ cloud: FakeCloud, realm: String = "test|alice", health: Bool = false) -> CloudSyncEngine {
        CloudSyncEngine(context: context, library: library, transport: FakeTransport(cloud: cloud),
                        realm: realm, includeHealth: health, stateURL: stateURL)
    }

    var trips: [Trip] { (try? context.fetch(FetchDescriptor<Trip>())) ?? [] }
    func trip(_ id: UUID) -> Trip? { trips.first { $0.id == id } }
}

@main struct CloudSyncRegression {
    static func check(_ value: Bool, _ message: String) { precondition(value, message) }

    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let cloud = FakeCloud()
        let a = try Device("a", root: root)
        let b = try Device("b", root: root)

        // 1. A 建立行程：襪子＋常備藥；沒有同意時藥品不上傳。
        let trip = Trip(name: "東京", countryCode: "JP", startDate: .now, endDate: .now.addingTimeInterval(4 * 86_400),
                        homeCurrencyCode: "TWD", localCurrencyCode: "JPY", totalBudget: 30_000, tripType: .leisure)
        trip.packingPreferencesRaw = #"{"style":"normal"}"#
        a.context.insert(trip)
        let socks = PackingItem(name: "襪子", category: .clothing, reasonKey: "基本必備", quantity: 5, trip: trip)
        socks.catalogItemID = "socks"
        let medicine = PackingItem(name: "常備藥", category: .health, reasonKey: "自訂", isCustom: true, trip: trip)
        a.context.insert(socks); a.context.insert(medicine)
        try a.context.save()
        var summary = try await a.engine(cloud).synchronize()
        check(summary.uploaded == 1, "A 上傳 1 趟行程")
        let uploaded = cloud.documents[CloudDocumentKey(kind: .trip, id: trip.id)]!.payload!
        check(uploaded.trip!.packingItems.map(\.name) == ["襪子"], "健康類物品不應上傳")
        check(uploaded.omittedPrivateCount == 1, "記錄沒有上傳的私密物品數量")
        check(uploaded.trip!.packingPreferencesRaw == #"{"style":"normal"}"#, "快照原樣上傳")
        summary = try await a.engine(cloud).synchronize()
        check(summary.uploaded == 0 && summary.downloaded == 0, "沒有變更時不重複上傳")

        // 2. B（新手機）下載：拿到行程，但沒有藥品，預算不同步。
        summary = try await b.engine(cloud).synchronize()
        check(summary.downloaded == 1, "B 下載 1 趟行程")
        let onB = b.trip(trip.id)!
        check(onB.name == "東京" && onB.packingItems?.map(\.name) == ["襪子"], "B 的行程內容正確")
        check(onB.totalBudget == 0, "預算不上傳")
        check(onB.packingItems?.first?.catalogItemID == "socks", "catalogItemID 保留")

        // 3. B 打包襪子 → A 收到，而且 A 的藥品還在。
        onB.packingItems?.first?.isPacked = true
        try b.context.save()
        summary = try await b.engine(cloud).synchronize()
        check(summary.uploaded == 1, "B 上傳打包狀態")
        summary = try await a.engine(cloud).synchronize()
        check(summary.downloaded == 1, "A 下載 B 的修改")
        let onA = a.trip(trip.id)!
        check(onA.packingItems?.first(where: { $0.name == "襪子" })?.isPacked == true, "A 看到襪子已打包")
        check(onA.packingItems?.contains(where: { $0.name == "常備藥" }) == true, "A 的私密物品不能被雲端版本刪掉")

        // 4. 衝突：兩台都改名，後同步的 B 收到衝突；選雲端版本後兩台一致。
        onA.name = "東京（A）"; try a.context.save()
        onB.name = "東京（B）"; try b.context.save()
        _ = try await a.engine(cloud).synchronize()
        summary = try await b.engine(cloud).synchronize()
        check(summary.conflicts.count == 1, "兩台都改了同一趟應該回報衝突")
        check(b.trip(trip.id)!.name == "東京（B）", "衝突時不自動覆蓋")
        _ = try await b.engine(cloud).resolve(summary.conflicts[0], keepLocal: false)
        check(b.trip(trip.id)!.name == "東京（A）", "選擇雲端版本")
        summary = try await b.engine(cloud).synchronize()
        check(summary.conflicts.isEmpty && summary.uploaded == 0, "解決後不再衝突")

        // 5. 再次衝突，這次保留本機版本。
        a.trip(trip.id)!.name = "東京 v2（A）"; try a.context.save()
        b.trip(trip.id)!.name = "東京 v2（B）"; try b.context.save()
        _ = try await a.engine(cloud).synchronize()
        summary = try await b.engine(cloud).synchronize()
        _ = try await b.engine(cloud).resolve(summary.conflicts[0], keepLocal: true)
        _ = try await a.engine(cloud).synchronize()
        check(a.trip(trip.id)!.name == "東京 v2（B）", "保留本機版本後另一台收到")

        // 6. 離線修改：失敗後下次同步補上。
        b.trip(trip.id)!.city = "東京"; try b.context.save()
        cloud.offline = true
        do { _ = try await b.engine(cloud).synchronize(); check(false, "離線時應該失敗") } catch {}
        cloud.offline = false
        summary = try await b.engine(cloud).synchronize()
        check(summary.uploaded == 1, "恢復連線後補上傳")

        // 7. 常備用品同步。
        try a.library.saveEssentials([.init(name: "眼罩", category: .other, quantity: 1)])
        _ = try await a.engine(cloud).synchronize()
        _ = try await b.engine(cloud).synchronize()
        check(try b.library.essentials().map(\.name) == ["眼罩"], "B 收到常備用品")
        // 健康類常備用品不上傳
        try a.library.saveEssentials([.init(name: "眼罩", category: .other, quantity: 1), .init(name: "胃藥", category: .health, quantity: 1)])
        _ = try await a.engine(cloud).synchronize()
        check(!cloud.documents.values.contains { $0.payload?.library?.name == "胃藥" }, "健康類常備用品不上傳")

        // 8. 同意同步健康類後才上傳；撤回同意後下次同步從雲端移除。
        _ = try await a.engine(cloud, health: true).synchronize()
        check(cloud.documents[CloudDocumentKey(kind: .trip, id: trip.id)]!.payload!.trip!.packingItems.contains { $0.name == "常備藥" },
              "同意後上傳藥品")
        _ = try await b.engine(cloud, health: true).synchronize()
        check(b.trip(trip.id)!.packingItems?.contains { $0.name == "常備藥" } == true, "同意的另一台也收到藥品")
        _ = try await a.engine(cloud).synchronize()
        let revoked = cloud.documents[CloudDocumentKey(kind: .trip, id: trip.id)]!.payload!
        check(!revoked.trip!.packingItems.contains(where: \.isHealth), "撤回同意後雲端不再有藥品")
        check(!cloud.documents.values.contains { !$0.deleted && $0.payload?.library?.name == "胃藥" }, "撤回同意後常備藥從雲端刪除")
        check(a.trip(trip.id)!.packingItems?.contains { $0.name == "常備藥" } == true, "本機藥品仍在")

        // 9. 刪除：A 刪除行程，B 同步後也刪除。
        a.context.delete(a.trip(trip.id)!); try a.context.save()
        summary = try await a.engine(cloud).synchronize()
        check(cloud.documents[CloudDocumentKey(kind: .trip, id: trip.id)]!.deleted, "刪除上傳為 tombstone")
        summary = try await b.engine(cloud, health: true).synchronize()
        check(b.trip(trip.id) == nil && summary.deleted >= 1, "B 也刪除這趟行程")

        // 10. 帳號綁定：同一台手機換另一個帳號登入要擋下。
        do {
            _ = try await a.engine(cloud, realm: "test|bob").synchronize()
            check(false, "不同帳號應被擋下")
        } catch CloudSyncError.differentAccount {}

        // 11. 設定檔不接受 server key。
        check(SupabaseConfiguration(url: URL(string: "https://x.supabase.co")!, publishableKey: "sb_secret_abc") == nil, "拒絕 secret key")
        check(SupabaseConfiguration(url: URL(string: "https://x.supabase.co")!, publishableKey: "sb_publishable_abc") != nil, "接受 publishable key")

        print("跨裝置同步、健康類剔除與保留、同意與撤回、衝突（兩種選擇）、離線重試、常備用品、刪除、帳號綁定、拒絕 secret key：PASS")
    }
}
