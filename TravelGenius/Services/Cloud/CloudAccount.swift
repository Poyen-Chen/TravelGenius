import Foundation
import Observation
import SwiftData

/// App 層的帳號與同步狀態。未登入或未開啟同步時，什麼都不上傳，App 行為和以前相同（PD-062）。
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

    init(container: ModelContainer, configuration: SupabaseConfiguration? = .load(), defaults: UserDefaults = .standard) {
        self.container = container
        self.defaults = defaults
        // iOS 移除 App 後 Keychain 仍會保留；重新安裝後的第一次啟動清掉舊的登入，避免「刪了 App 還是登入中」。
        if let configuration, !defaults.bool(forKey: Self.installedKey) {
            SupabaseSessionStore(account: configuration.url.host ?? "supabase").save(nil)
        }
        defaults.set(true, forKey: Self.installedKey)
        client = configuration.map { SupabaseClient(configuration: $0) }
        lastSyncedAt = defaults.object(forKey: "cloud.sync.lastSyncedAt") as? Date
        refreshPhase()
    }

    var dataRegionNote: String { "資料存放在 Supabase（\(client?.configuration.region ?? "未設定")）" }

    private func refreshPhase() {
        guard let client else { phase = .unconfigured; return }
        if let session = client.current { phase = .signedIn(email: session.email) }
        else if case .awaitingCode = phase {} else { phase = .signedOut }
    }

    // MARK: 登入

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
            healthConsent = (try? await client.healthSyncConsent()) ?? false
            phase = .signedIn(email: email)
            message = nil
        }
    }

    func cancelCode() { phase = .signedOut; message = nil }

    func signOut() async {
        await client?.signOut()
        syncEnabled = false
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
        catch { message = error.localizedDescription }
    }
}
