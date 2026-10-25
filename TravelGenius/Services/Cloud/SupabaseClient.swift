import Foundation
import Security

/// Project URL 與 publishable key，來自 App 內的 `Supabase.plist`（gitignore；範本在 Config/）。
/// 公開 key 本來就會放在 App 裡，資料保護靠登入身分與 RLS；service_role／secret key 一律拒絕（PD-062）。
struct SupabaseConfiguration: Equatable {
    let url: URL
    let publishableKey: String
    /// 顯示在同意說明裡的資料地區，例如「新加坡」；沒填時顯示主機名稱。
    let region: String

    static func load(bundle: Bundle = .main) -> SupabaseConfiguration? {
        guard let file = bundle.url(forResource: "Supabase", withExtension: "plist"),
              let values = NSDictionary(contentsOf: file) as? [String: String],
              let raw = values["URL"], let url = URL(string: raw), let key = values["PublishableKey"] else { return nil }
        return SupabaseConfiguration(url: url, publishableKey: key, region: values["Region"])
    }

    init?(url: URL, publishableKey: String, region: String? = nil) {
        guard ["https", "http"].contains(url.scheme ?? ""), !publishableKey.isEmpty,
              !Self.isServerKey(publishableKey) else { return nil }
        self.url = url
        self.publishableKey = publishableKey
        self.region = region ?? url.host ?? url.absoluteString
    }

    static func isServerKey(_ key: String) -> Bool {
        if key.hasPrefix("sb_secret_") { return true }
        let parts = key.split(separator: ".")
        guard parts.count == 3 else { return false }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return claims["role"] as? String == "service_role"
    }

    /// 本機資料綁定的範圍：同一個專案的同一個帳號。
    func realm(for userID: UUID) -> String { "\(url.host ?? url.absoluteString)|\(userID.uuidString.lowercased())" }
}

struct SupabaseSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userID: UUID
    var email: String
}

enum SupabaseError: LocalizedError, Equatable {
    case notSignedIn
    case invalidCode
    case rateLimited
    case server(Int, String)
    case offline

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "請先登入。"
        case .invalidCode: "驗證碼錯誤或已過期，請重新輸入或重新寄送。"
        case .rateLimited: "寄送太頻繁，請稍後再試。"
        case .server(let status, _): "雲端服務暫時無法使用（\(status)），請稍後再試。"
        case .offline: "目前沒有網路連線，資料先保存在這台手機。"
        }
    }
}

/// 只用 URLSession 呼叫 Supabase 的 Auth、PostgREST 與 Edge Functions，不另外依賴 SDK。
@MainActor
final class SupabaseClient {
    let configuration: SupabaseConfiguration
    private let session: URLSession
    private let keychain: SupabaseSessionStore
    private(set) var current: SupabaseSession?

    init(configuration: SupabaseConfiguration, session: URLSession = .shared, keychain: SupabaseSessionStore? = nil) {
        self.configuration = configuration
        self.session = session
        self.keychain = keychain ?? SupabaseSessionStore(account: configuration.url.host ?? "supabase")
        current = self.keychain.load()
    }

    // MARK: Auth（Email 驗證碼）

    func sendCode(to email: String) async throws {
        _ = try await request("auth/v1/otp", json: ["email": email, "create_user": true], authorized: false)
    }

    func verify(email: String, code: String) async throws {
        do {
            let data = try await request("auth/v1/verify", json: ["type": "email", "email": email, "token": code], authorized: false)
            try store(data)
        } catch SupabaseError.server(let status, _) where [400, 401, 403, 422].contains(status) {
            throw SupabaseError.invalidCode
        }
    }

    func signOut() async {
        if current != nil { _ = try? await request("auth/v1/logout", json: [:], authorized: true) }
        current = nil
        keychain.save(nil)
    }

    /// 刪除雲端帳號與全部雲端資料（delete-account Edge Function）；本機資料保留。
    func deleteAccount() async throws {
        _ = try await request("functions/v1/delete-account", json: [:], authorized: true)
        current = nil
        keychain.save(nil)
    }

    // MARK: 帳號層級的設定

    /// 「同步健康類物品」的同意存在帳號上（user metadata），每台手機讀同一個值。
    /// 若各台手機各自設定，沒同意的手機上傳時會剔除藥品，導致同意的手機收到後被刪掉。
    func healthSyncConsent() async throws -> Bool {
        struct User: Decodable { let user_metadata: [String: Bool]? }
        let data = try await request("auth/v1/user", method: "GET", authorized: true)
        return (try? JSONDecoder().decode(User.self, from: data))?.user_metadata?["health_sync_consent"] ?? false
    }

    func setHealthSyncConsent(_ value: Bool) async throws {
        _ = try await request("auth/v1/user", method: "PUT", json: ["data": ["health_sync_consent": value]], authorized: true)
    }

    // MARK: 資料

    func fetchDocuments() async throws -> [RemoteCloudDocument] {
        let data = try await request("rest/v1/user_documents?select=kind,id,revision,payload,deleted", method: "GET", authorized: true)
        return try CloudCoding.decoder.decode([RemoteCloudDocument].self, from: data)
    }

    func write(_ change: CloudWrite) async throws -> CloudWriteResult {
        let data = try await request("rest/v1/rpc/sync_document", rawBody: try CloudCoding.encoder.encode(change), authorized: true)
        return try CloudCoding.decoder.decode(CloudWriteResult.self, from: data)
    }

    // MARK: 內部

    private func store(_ data: Data) throws {
        struct Response: Decodable {
            struct User: Decodable { let id: UUID; let email: String? }
            let access_token: String
            let refresh_token: String
            let expires_in: Double
            let user: User
        }
        let value = try JSONDecoder().decode(Response.self, from: data)
        current = SupabaseSession(accessToken: value.access_token, refreshToken: value.refresh_token,
                                  expiresAt: Date().addingTimeInterval(value.expires_in),
                                  userID: value.user.id, email: value.user.email ?? current?.email ?? "")
        keychain.save(current)
    }

    private func validAccessToken() async throws -> String {
        guard let current else { throw SupabaseError.notSignedIn }
        if current.expiresAt > Date().addingTimeInterval(60) { return current.accessToken }
        do {
            let data = try await request("auth/v1/token?grant_type=refresh_token", json: ["refresh_token": current.refreshToken], authorized: false)
            try store(data)
        } catch SupabaseError.server(let status, _) where (400..<500).contains(status) {
            self.current = nil
            keychain.save(nil)
            throw SupabaseError.notSignedIn
        }
        return self.current!.accessToken
    }

    private func request(_ path: String, method: String = "POST", json: [String: Any], authorized: Bool) async throws -> Data {
        try await request(path, method: method, rawBody: try JSONSerialization.data(withJSONObject: json), authorized: authorized)
    }

    private func request(_ path: String, method: String = "POST", rawBody: Data? = nil, authorized: Bool) async throws -> Data {
        var request = URLRequest(url: URL(string: path, relativeTo: configuration.url.appendingPathComponent("/"))!)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized { request.setValue("Bearer \(try await validAccessToken())", forHTTPHeaderField: "Authorization") }
        request.httpBody = method == "GET" ? nil : rawBody
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost].contains(error.code) {
            throw SupabaseError.offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 429 { throw SupabaseError.rateLimited }
        guard (200..<300).contains(status) else { throw SupabaseError.server(status, String(decoding: data, as: UTF8.self)) }
        return data
    }

}

/// 登入狀態存在 Keychain（只限這台裝置），不放 UserDefaults。
struct SupabaseSessionStore {
    let account: String
    private let service = "PackSmart.SupabaseSession"

    func load() -> SupabaseSession? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: account, kSecReturnData as String: true]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(SupabaseSession.self, from: data)
    }

    func save(_ session: SupabaseSession?) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        guard let session, let data = try? JSONEncoder().encode(session) else { return }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
