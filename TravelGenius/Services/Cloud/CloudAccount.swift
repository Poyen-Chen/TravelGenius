import Foundation
import Observation
import SwiftData

/// App 層的帳號與同步狀態。未登入或未開啟同步時，什麼都不上傳，App 行為和以前相同（PD-062）。
/// Apple 與 Email 驗證碼是登入身分。App 不另做 Face ID 鎖定，交給 iOS 的「需要 Face ID」（PD-068）。
@MainActor @Observable
final class CloudAccount {
    enum Phase: Equatable {
        case unconfigured
        case signedOut
        case awaitingCode(email: String)
        case signedIn(email: String)
    }

    private(set) var phase: Phase = .unconfigured
    private(set) var isWorking = false
    private(set) var lastSyncedAt: Date?
    private(set) var conflicts: [CloudSyncConflict] = []
    private(set) var healthConsent = false
    /// nil：還不知道（尚未讀到或讀取失敗），連結按鈕先不顯示。
    private(set) var appleLinked: Bool?
    var message: String?

    /// 每台手機各自決定要不要同步；健康類的同意則跟著帳號（見 SupabaseClient.healthSyncConsent）。
    var syncEnabled: Bool {
        get { access(keyPath: \.syncEnabled); return defaults.bool(forKey: Self.syncKey) }
        set { withMutation(keyPath: \.syncEnabled) { defaults.set(newValue, forKey: Self.syncKey) } }
    }

    private static let syncKey = "cloud.sync.enabled"
    private static let installedKey = "cloud.installed"
    private let container: ModelContainer
    private let defaults: UserDefaults
    private let client: SupabaseClient?
    private let appleProvider: AppleIdentityProviding?

    init(container: ModelContainer, configuration: SupabaseConfiguration? = .load(), defaults: UserDefaults = .standard,
         session: URLSession = .shared, keychain: SessionStoring? = nil, appleProvider: AppleIdentityProviding? = nil) {
        self.container = container
        self.defaults = defaults
        self.appleProvider = appleProvider
        // iOS 移除 App 後 Keychain 仍會保留；重新安裝後的第一次啟動清掉舊的登入，避免「刪了 App 還是登入中」。
        if let configuration, !defaults.bool(forKey: Self.installedKey) {
            (keychain ?? SupabaseSessionStore(account: configuration.keychainAccount)).save(nil)
        }
        defaults.set(true, forKey: Self.installedKey)
        client = configuration.map { SupabaseClient(configuration: $0, session: session, keychain: keychain) }
        lastSyncedAt = defaults.object(forKey: "cloud.sync.lastSyncedAt") as? Date
        refreshPhase()
    }

    var dataRegionNote: String { "資料存放在 Supabase（\(client?.configuration.region ?? "未設定")）" }

    /// 給使用者看的帳號名稱：Apple 的轉寄地址或空白顯示成「Apple 帳號」。
    var accountLabel: String {
        guard case .signedIn(let email) = phase else { return "" }
        return Self.accountLabel(for: email)
    }

    nonisolated static func accountLabel(for email: String) -> String {
        if email.isEmpty || email.lowercased().hasSuffix("@privaterelay.appleid.com") { return "Apple 帳號" }
        return email
    }

    var showsAppleSignIn: Bool { AppleSignInFeature.isEnabled && appleProvider != nil }
    var showsAppleLink: Bool {
        guard showsAppleSignIn, case .signedIn = phase else { return false }
        return appleLinked == false
    }

    private func refreshPhase() {
        guard let client else { phase = .unconfigured; return }
        if let session = client.current { phase = .signedIn(email: session.email) }
        else if case .awaitingCode = phase {} else { phase = .signedOut }
    }

    // MARK: 登入（Email 驗證碼）

    func sendCode(to email: String) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let client, email.contains("@") else { message = "請輸入正確的 Email。"; return }
        await perform {
            try await client.sendCode(to: email)
            phase = .awaitingCode(email: email)
            message = "驗證碼已寄到 \(email)。"
        }
    }

    func verify(code: String) async {
        guard let client, case .awaitingCode(let email) = phase else { return }
        await perform {
            try await client.verify(email: email, code: code.trimmingCharacters(in: .whitespacesAndNewlines))
            didSignIn(email: client.current?.email ?? email)
            healthConsent = (try? await client.healthSyncConsent()) ?? false
            message = nil
        }
    }

    func cancelCode() { phase = .signedOut; message = nil }

    // MARK: 登入（Sign in with Apple）

    func signInWithApple() async {
        guard let client, let appleProvider else { return }
        await perform {
            let identity = try await appleProvider.requestIdentity()
            try await client.signInWithApple(idToken: identity.idToken, nonce: identity.rawNonce)
            didSignIn(email: client.current?.email ?? "")
            healthConsent = (try? await client.healthSyncConsent()) ?? false
            message = nil
        }
    }

    /// 已登入時把 Apple 也綁到這個帳號；失敗時不登出、不刪任何帳號。
    func linkApple() async {
        guard let client, let appleProvider, case .signedIn = phase else { return }
        await perform {
            let identity = try await appleProvider.requestIdentity()
            try await client.linkApple(idToken: identity.idToken, nonce: identity.rawNonce)
            appleLinked = true
            message = "已可以用 Apple 登入這個帳號。"
        }
    }

    func refreshLinkedProviders() async {
        guard showsAppleSignIn, let client, case .signedIn = phase else { return }
        appleLinked = (try? await client.linkedProviders()).map { $0.contains("apple") }
    }

    private func didSignIn(email: String) {
        appleLinked = nil
        phase = .signedIn(email: email)
    }

    func signOut() async {
        await client?.signOut()
        syncEnabled = false
        appleLinked = nil
        conflicts = []
        phase = .signedOut
    }

    /// 刪除雲端帳號與全部雲端資料；這台手機上的資料保留，同步紀錄清空。
    func deleteAccount() async {
        guard let client else { return }
        await perform {
            try await client.deleteAccount()
            CloudSyncEngine.resetState()
            syncEnabled = false
            appleLinked = nil
            conflicts = []
            lastSyncedAt = nil
            defaults.removeObject(forKey: "cloud.sync.lastSyncedAt")
            phase = .signedOut
            message = "雲端帳號與資料已刪除；這台手機上的資料仍保留。"
        }
    }

    // MARK: 同步

    func setHealthConsent(_ value: Bool) async {
        guard let client else { return }
        await perform {
            try await client.setHealthSyncConsent(value)
            healthConsent = value
        }
        if syncEnabled { await synchronize() }
    }

    /// 啟動、回到前景時呼叫；沒有登入或沒有開啟同步時不做任何事。
    func synchronizeIfEnabled() async {
        guard syncEnabled, case .signedIn = phase, !isWorking else { return }
        await synchronize()
    }

    func synchronize() async {
        guard let engine = await makeEngine() else { return }
        await perform {
            let summary = try await engine.synchronize()
            finish(summary)
        }
    }

    func resolve(_ conflict: CloudSyncConflict, keepLocal: Bool) async {
        guard let engine = await makeEngine() else { return }
        await perform {
            _ = try await engine.resolve(conflict, keepLocal: keepLocal)
            conflicts.removeAll { $0.id == conflict.id }
        }
    }

    private func makeEngine() async -> CloudSyncEngine? {
        guard let client, let session = client.current else { return nil }
        if let consent = try? await client.healthSyncConsent() { healthConsent = consent }
        return CloudSyncEngine(context: container.mainContext, library: PackingStaples.library, transport: client,
                               realm: client.configuration.realm(for: session.userID), includeHealth: healthConsent)
    }

    private func finish(_ summary: CloudSyncSummary) {
        conflicts = summary.conflicts
        lastSyncedAt = .now
        defaults.set(lastSyncedAt, forKey: "cloud.sync.lastSyncedAt")
        message = summary.conflicts.isEmpty ? nil : "有 \(summary.conflicts.count) 份資料在兩台裝置都被修改，請選擇要保留的版本。"
    }

    private func perform(_ work: () async throws -> Void) async {
        isWorking = true
        defer { isWorking = false; refreshPhase() }
        do { try await work() }
        catch SupabaseError.notSignedIn { phase = .signedOut; message = SupabaseError.notSignedIn.errorDescription }
        catch { message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
    }
}
