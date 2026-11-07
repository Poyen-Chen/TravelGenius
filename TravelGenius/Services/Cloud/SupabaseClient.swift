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

    /// Keychain 裡存登入狀態的 account 名稱。
    var keychainAccount: String { url.host ?? "supabase" }
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
    case appleFailed
    case appleRateLimited
    case emailAlreadyUsed
    case appleIdentityTaken
    case linkingUnavailable

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "請先登入。"
        case .invalidCode: "驗證碼錯誤或已過期，請重新輸入或重新寄送。"
        case .rateLimited: "寄送太頻繁，請稍後再試。"
        case .server(let status, _): "雲端服務暫時無法使用（\(status)），請稍後再試。"
        case .offline: "目前沒有網路連線，資料先保存在這台手機。"
        case .appleFailed: "Apple 登入沒有成功，請再試一次。"
        case .appleRateLimited: "登入太頻繁，請稍後再試。"
        case .emailAlreadyUsed: "這個 Email 已經有 PackSmart 帳號，請改用驗證碼登入。"
        case .appleIdentityTaken: "這個 Apple 帳號已經綁在另一個 PackSmart 帳號上。"
        case .linkingUnavailable: "暫時無法綁定 Apple。"
        }
    }

    /// Supabase Auth 錯誤內容裡的 `error_code`（或舊版的 `code`）與 `msg`。內容本身不顯示給使用者。
    static func authErrorCode(_ body: String) -> (code: String?, message: String?) {
        guard let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any] else { return (nil, nil) }
        let code = object["error_code"] as? String ?? object["code"] as? String
        let message = object["msg"] as? String ?? object["message"] as? String
        return (code, message)
    }
}

/// 只用 URLSession 呼叫 Supabase 的 Auth、PostgREST 與 Edge Functions，不另外依賴 SDK。
@MainActor
final class SupabaseClient {
    let configuration: SupabaseConfiguration
    private let session: URLSession
    private let keychain: SessionStoring
    private(set) var current: SupabaseSession?

    init(configuration: SupabaseConfiguration, session: URLSession = .shared, keychain: SessionStoring? = nil) {
        self.configuration = configuration
        self.session = session
        self.keychain = keychain ?? SupabaseSessionStore(account: configuration.keychainAccount)
        current = self.keychain.load()
    }

    // MARK: Auth（Email 驗證碼）

    func sendCode(to email: String) async throws {
        _ = try await request("auth/v1/otp", json: ["email": email, "create_user": true], authorized: false)
    }

    func verify(email: String, code: String) async throws {
        do {
            let data = try await request("auth/v1/verify", json: ["type": "email", "email": email, "token": code], authorized: false)
            try adoptNewSignIn(data)
        } catch SupabaseError.server(let status, _) where [400, 401, 403, 422].contains(status) {
            throw SupabaseError.invalidCode
        }
    }

    // MARK: Auth（Sign in with Apple，PD-068）

    /// Apple 的 identity token 由 Supabase 驗證（簽章、aud、nonce），App 不自己解碼信任其中的 Email 或 sub。
    func signInWithApple(idToken: String, nonce: String) async throws {
        do {
            let data = try await request("auth/v1/token?grant_type=id_token", json: Self.appleBody(idToken: idToken, nonce: nonce, link: false), authorized: false)
            try adoptNewSignIn(data)
        } catch SupabaseError.rateLimited {
            throw SupabaseError.appleRateLimited
        } catch SupabaseError.server(let status, let body) {
            throw Self.mapAppleError(status: status, body: body, linking: false)
        } catch is DecodingError {
            throw SupabaseError.appleFailed
        }
    }

    /// 把 Apple 綁到目前登入的帳號：同一個 user id，user_documents 的 owner 不變。不會自動合併兩個帳號。
    func linkApple(idToken: String, nonce: String) async throws {
        guard current != nil else { throw SupabaseError.notSignedIn }
        do {
            let data = try await request("auth/v1/token?grant_type=id_token", json: Self.appleBody(idToken: idToken, nonce: nonce, link: true), authorized: true)
            // 回傳的是同一個帳號的新 token；不是同一個帳號就不採用。
            if let linked = try? decodeSession(data), linked.userID == current?.userID { persist(linked) }
        } catch SupabaseError.rateLimited {
            throw SupabaseError.appleRateLimited
        } catch SupabaseError.server(let status, let body) {
            throw Self.mapAppleError(status: status, body: body, linking: true)
        }
    }

    /// 帳號已經綁定的登入方式，例如 ["email", "apple"]。
    func linkedProviders() async throws -> Set<String> {
        struct User: Decodable {
            struct Identity: Decodable { let provider: String }
            let identities: [Identity]?
        }
        let data = try await request("auth/v1/user", method: "GET", authorized: true)
        return Set((try JSONDecoder().decode(User.self, from: data)).identities?.map(\.provider) ?? [])
    }

    nonisolated static func appleBody(idToken: String, nonce: String, link: Bool) -> [String: Any] {
        var body: [String: Any] = ["provider": "apple", "id_token": idToken, "nonce": nonce]
        if link { body["link_identity"] = true }
        return body
    }

    nonisolated static func mapAppleError(status: Int, body: String, linking: Bool) -> SupabaseError {
        let (code, message) = SupabaseError.authErrorCode(body)
        if code == "over_request_rate_limit" { return .appleRateLimited }
        if code == "email_exists" || (status == 500 && message?.localizedCaseInsensitiveContains("multiple accounts with the same email") == true) {
            return .emailAlreadyUsed
        }
        if linking, code == "identity_already_exists" { return .appleIdentityTaken }
        if linking, code == "manual_linking_disabled" { return .linkingUnavailable }
        if (400..<500).contains(status) { return .appleFailed }
        return .server(status, "")
    }

    // MARK: 登出、刪除帳號

    func signOut() async {
        if current != nil { _ = try? await request("auth/v1/logout", json: [:], authorized: true) }
        clearLocalSession()
    }

    /// 刪除雲端帳號與全部雲端資料（delete-account Edge Function）；本機資料保留。
    func deleteAccount() async throws {
        _ = try await request("functions/v1/delete-account", json: [:], authorized: true)
        clearLocalSession()
    }

    private func clearLocalSession() {
        current = nil
        keychain.save(nil)
    }

    // MARK: 帳號層級的設定

    /// 「同步健康類物品」的同意存在帳號上（user metadata），每台手機讀同一個值。
    /// 若各台手機各自設定，沒同意的手機上傳時會剔除藥品，導致同意的手機收到後被刪掉。
    func healthSyncConsent() async throws -> Bool {
        Self.healthConsent(fromUser: try await request("auth/v1/user", method: "GET", authorized: true))
    }

    /// metadata 裡可能有其他字串（例如登入服務寫入的姓名），只看 health_sync_consent 是不是 JSON true。
    nonisolated static func healthConsent(fromUser data: Data) -> Bool {
        guard let user = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let metadata = user["user_metadata"] as? [String: Any],
              let value = metadata["health_sync_consent"] as? NSNumber else { return false }
        return CFGetTypeID(value) == CFBooleanGetTypeID() && value.boolValue
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

    /// token JSON 的唯一解析處。之後的登入沒有回傳 Email 時沿用目前的 Email。
    func decodeSession(_ data: Data) throws -> SupabaseSession {
        struct Response: Decodable {
            struct User: Decodable { let id: UUID; let email: String? }
            let access_token: String
            let refresh_token: String
            let expires_in: Double
            let user: User
        }
        let value = try JSONDecoder().decode(Response.self, from: data)
        let email = value.user.email.flatMap { $0.isEmpty ? nil : $0 } ?? current?.email ?? ""
        return SupabaseSession(accessToken: value.access_token, refreshToken: value.refresh_token,
                               expiresAt: Date().addingTimeInterval(value.expires_in), userID: value.user.id, email: email)
    }

    /// 新的登入（驗證碼或 Apple）與更新 token 都從這裡寫入 Keychain。
    private func adoptNewSignIn(_ data: Data) throws {
        persist(try decodeSession(data))
    }

    private func persist(_ session: SupabaseSession) {
        current = session
        keychain.save(session)
    }

    private func validAccessToken() async throws -> String {
        guard let current else { throw SupabaseError.notSignedIn }
        if current.expiresAt > Date().addingTimeInterval(60) { return current.accessToken }
        do {
            let data = try await request("auth/v1/token?grant_type=refresh_token", json: ["refresh_token": current.refreshToken], authorized: false)
            persist(try decodeSession(data))
        } catch SupabaseError.server(let status, _) where (400..<500).contains(status) {
            clearLocalSession()
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

/// 登入狀態的存放處；測試時換成記憶體版本。
protocol SessionStoring {
    func load() -> SupabaseSession?
    /// nil 代表刪除。
    func save(_ session: SupabaseSession?)
}

/// 登入狀態存在 Keychain（只限這台裝置），不放 UserDefaults，也不放進 App Group（小工具讀不到）。
struct SupabaseSessionStore: SessionStoring {
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
