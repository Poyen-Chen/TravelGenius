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

        try await appleSignIn(a: a, cloud: cloud)
        print("Apple 登入 nonce／請求內容／錯誤對應、綁定 Apple、健康同意讀取、更新 token、登入不等於同步、登出清除：PASS")
    }

    // MARK: PD-068 Sign in with Apple

    @MainActor static func appleSignIn(a: Device, cloud: FakeCloud) async throws {
        let configuration = SupabaseConfiguration(url: URL(string: "https://x.supabase.co")!, publishableKey: "sb_publishable_abc")!
        let alice = UUID()
        let fixture = tokenJSON(user: alice, email: "alice@example.com")

        // nonce：已知字串的 SHA-256；raw 是 URL-safe；送給 Apple 的是 hash；亂數失敗會丟錯而不是當掉。
        check(AppleNonceMaker.hash("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA-256 hex")
        let nonce = try AppleNonceMaker.make()
        check(nonce.raw.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil, "raw nonce 是 URL-safe")
        check(nonce.hashed == AppleNonceMaker.hash(nonce.raw) && nonce.hashed != nonce.raw, "Apple 收到的是 hash")
        check((try? AppleNonceMaker.make(random: { _ in errSecParam })) == nil, "亂數失敗時丟錯")

        // Apple 登入：路徑、沒有 Authorization、JSON 只有 provider／id_token／nonce；成功後存進 Keychain。
        let store = MemoryStore()
        StubProtocol.reset { _ in (200, fixture) }
        var client = SupabaseClient(configuration: configuration, session: StubProtocol.session, keychain: store)
        try await client.signInWithApple(idToken: "apple-token", nonce: nonce.raw)
        var sent = StubProtocol.requests[0]
        check(sent.url?.path == "/auth/v1/token" && sent.url?.query == "grant_type=id_token", "Apple 登入的路徑")
        check(sent.value(forHTTPHeaderField: "Authorization") == nil, "Apple 登入不帶 Authorization")
        var body = StubProtocol.json(sent)
        check(Set(body.keys) == ["provider", "id_token", "nonce"] && body["provider"] as? String == "apple", "Apple 登入的內容")
        check(body["nonce"] as? String == nonce.raw, "送給 Supabase 的是 raw nonce")
        check(!body.keys.contains { ["secret", "client_secret", "key", "access_token"].contains($0) }, "沒有 secret")
        check(store.saved?.userID == alice && store.saved?.accessToken == "access-alice", "Apple 登入後存進 Keychain")

        // 錯誤對應：Email 已有帳號、綁定衝突只在綁定時、未開啟手動綁定、其他 4xx、5xx。
        let body401 = #"{"error_code":"email_exists","msg":"x"}"#
        check(SupabaseClient.mapAppleError(status: 422, body: body401, linking: false) == .emailAlreadyUsed, "email_exists")
        check(SupabaseClient.mapAppleError(status: 500, body: body401, linking: false) == .emailAlreadyUsed, "500 的 email_exists")
        let taken = #"{"error_code":"identity_already_exists"}"#
        check(SupabaseClient.mapAppleError(status: 422, body: taken, linking: true) == .appleIdentityTaken, "綁定衝突")
        check(SupabaseClient.mapAppleError(status: 422, body: taken, linking: false) == .appleFailed, "登入時不用綁定衝突的句子")
        check(SupabaseClient.mapAppleError(status: 422, body: #"{"error_code":"manual_linking_disabled"}"#, linking: true) == .linkingUnavailable, "未開啟手動綁定")
        check(SupabaseClient.mapAppleError(status: 400, body: #"{"error_code":"bad_jwt"}"#, linking: false) == .appleFailed, "其他 4xx")
        check(SupabaseClient.mapAppleError(status: 503, body: "", linking: false) == .server(503, ""), "5xx")
        check(SupabaseError.appleFailed.errorDescription != SupabaseError.invalidCode.errorDescription, "Apple 失敗不顯示驗證碼錯誤")

        // 失敗不動既有登入。
        let kept = MemoryStore()
        kept.saved = session(alice, "alice@example.com")
        StubProtocol.reset { _ in (400, #"{"error_code":"bad_jwt"}"#) }
        client = SupabaseClient(configuration: configuration, session: StubProtocol.session, keychain: kept)
        do { try await client.signInWithApple(idToken: "t", nonce: "n"); check(false, "400 應失敗") }
        catch SupabaseError.appleFailed {}
        check(kept.saved?.userID == alice, "失敗時保留原本的登入")

        // 綁定：帶目前的 Authorization 與 link_identity；沒有登入時不送出。
        StubProtocol.reset { _ in (200, fixture) }
        try await client.linkApple(idToken: "t", nonce: "n")
        sent = StubProtocol.requests[0]
        body = StubProtocol.json(sent)
        check(sent.value(forHTTPHeaderField: "Authorization") == "Bearer stored", "綁定帶目前的 token")
        check(body["link_identity"] as? Bool == true && body["access_token"] == nil, "綁定的內容")
        StubProtocol.reset { _ in (422, taken) }
        do { try await client.linkApple(idToken: "t", nonce: "n"); check(false, "衝突應失敗") }
        catch SupabaseError.appleIdentityTaken {}
        check(kept.saved?.userID == alice, "綁定失敗不登出")
        let nobody = SupabaseClient(configuration: configuration, session: StubProtocol.session, keychain: MemoryStore())
        StubProtocol.reset { _ in (200, fixture) }
        do { try await nobody.linkApple(idToken: "t", nonce: "n"); check(false, "沒登入不能綁定") } catch SupabaseError.notSignedIn {}
        check(StubProtocol.requests.isEmpty, "沒登入時不送出綁定")

        // 健康同意：metadata 有字串時仍讀到 true，下一次同步不會剔除藥品。
        let mixed = Data(#"{"user_metadata":{"health_sync_consent":true,"full_name":"Alice"}}"#.utf8)
        check(SupabaseClient.healthConsent(fromUser: mixed), "metadata 混有字串仍讀到同意")
        check(!SupabaseClient.healthConsent(fromUser: Data(#"{"user_metadata":{"health_sync_consent":1}}"#.utf8)), "不是 bool 就當沒同意")
        check(!SupabaseClient.healthConsent(fromUser: Data(#"{"user_metadata":{}}"#.utf8)), "沒有就當沒同意")
        let medicineTrip = Trip(name: "大阪", countryCode: "JP", startDate: .now, endDate: .now.addingTimeInterval(86_400),
                                homeCurrencyCode: "TWD", localCurrencyCode: "JPY", totalBudget: 0, tripType: .leisure)
        a.context.insert(medicineTrip)
        a.context.insert(PackingItem(name: "胃藥", category: .health, reasonKey: "自訂", isCustom: true, trip: medicineTrip))
        try a.context.save()
        _ = try await a.engine(cloud, health: SupabaseClient.healthConsent(fromUser: mixed)).synchronize()
        check(cloud.documents[CloudDocumentKey(kind: .trip, id: medicineTrip.id)]!.payload!.trip!.packingItems.contains { $0.name == "胃藥" },
              "同意讀對時藥品照常上傳")

        // 過期時先更新 token，新的 token 存回 Keychain。
        let refreshStore = MemoryStore()
        refreshStore.saved = session(alice, "alice@example.com", expired: true)
        StubProtocol.reset { _ in (200, fixture) }
        client = SupabaseClient(configuration: configuration, session: StubProtocol.session, keychain: refreshStore)
        _ = try await client.linkedProviders()
        check(StubProtocol.requests.first?.url?.query == "grant_type=refresh_token", "過期時先更新 token")
        check(refreshStore.saved?.accessToken == "access-alice", "更新後存回 Keychain")

        // CloudAccount：Apple 登入後問同步前不會開啟同步；登出清除登入。
        let defaults = UserDefaults(suiteName: "cloud-account-\(UUID().uuidString)")!
        defaults.set(true, forKey: "cloud.installed")
        let accountStore = MemoryStore()
        StubProtocol.reset { request in request.url?.path == "/auth/v1/user" ? (200, #"{"user_metadata":{}}"#) : (200, fixture) }
        let account = CloudAccount(container: a.container, configuration: configuration, defaults: defaults,
                                   session: StubProtocol.session, keychain: accountStore, appleProvider: FakeApple())
        check(account.phase == .signedOut, "一開始未登入")
        await account.signInWithApple()
        check(account.phase == .signedIn(email: "alice@example.com") && !account.syncEnabled, "Apple 登入不等於開啟同步")
        check(account.message == nil, "登入成功沒有錯誤訊息")
        await account.signOut()
        check(accountStore.saved == nil && account.phase == .signedOut, "登出清除登入")

        // Apple 的轉寄地址顯示成「Apple 帳號」。
        check(CloudAccount.accountLabel(for: "x@privaterelay.appleid.com") == "Apple 帳號" && CloudAccount.accountLabel(for: "") == "Apple 帳號", "轉寄地址")
        check(CloudAccount.accountLabel(for: "alice@example.com") == "alice@example.com", "一般 Email 照常顯示")
    }

    static func session(_ user: UUID, _ email: String, expired: Bool = false) -> SupabaseSession {
        SupabaseSession(accessToken: "stored", refreshToken: "refresh", expiresAt: expired ? .distantPast : .distantFuture, userID: user, email: email)
    }

    static func tokenJSON(user: UUID, email: String) -> String {
        #"{"access_token":"access-alice","refresh_token":"refresh-alice","expires_in":3600,"user":{"id":"\#(user.uuidString)","email":"\#(email)"}}"#
    }
}

/// 記憶體裡的 Keychain。
final class MemoryStore: SessionStoring {
    var saved: SupabaseSession?
    func load() -> SupabaseSession? { saved }
    func save(_ session: SupabaseSession?) { saved = session }
}

@MainActor struct FakeApple: AppleIdentityProviding {
    func requestIdentity() async throws -> AppleIdentity { AppleIdentity(idToken: "apple-token", rawNonce: "raw") }
}

/// 攔截 URLSession，記錄請求並回傳固定內容。
final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var requests: [URLRequest] = []
    nonisolated(unsafe) static var handler: (URLRequest) -> (Int, String) = { _ in (500, "") }
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: configuration)
    }()

    static func reset(_ handler: @escaping (URLRequest) -> (Int, String)) {
        requests = []
        self.handler = handler
    }

    static func json(_ request: URLRequest) -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(buffer, count: n) }
            stream.close()
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        let (status, body) = Self.handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
