import CryptoKit
import Foundation
import Security

/// Sign in with Apple 的 nonce：raw 送給 Supabase，SHA-256 hex 交給 Apple（PD-068）。兩者對調會讓每次登入都失敗。
struct AppleNonce: Equatable {
    let raw: String
    let hashed: String
}

enum AppleNonceMaker {
    enum AppleNonceError: Error { case rngFailed }

    static func make(random: (inout [UInt8]) -> OSStatus = { bytes in SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) }) throws -> AppleNonce {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard random(&bytes) == errSecSuccess else { throw AppleNonceError.rngFailed }
        let raw = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return AppleNonce(raw: raw, hashed: hash(raw))
    }

    static func hash(_ raw: String) -> String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Apple 回傳給這台裝置的身分。沒有 Email、沒有姓名：顯示用的 Email 來自 Supabase 的 session，姓名直接丟掉。
struct AppleIdentity: Equatable {
    var idToken: String
    var rawNonce: String
}

enum AppleIdentityError: LocalizedError, Equatable {
    case canceled
    case failed

    var errorDescription: String? {
        switch self {
        case .canceled: "已取消 Apple 登入。"
        case .failed: "Apple 登入沒有成功，請再試一次。"
        }
    }
}

/// 實際的 ASAuthorizationController 在 Services/AppleSignInCoordinator.swift（不在 Cloud/ 底下，
/// 所以 scripts/test_cloud_sync.sh 不需要 AuthenticationServices）。測試傳入假的 provider。
@MainActor
protocol AppleIdentityProviding {
    func requestIdentity() async throws -> AppleIdentity
}

/// Apple 登入按鈕預設隱藏，要等真正的 Apple Developer team、bundle id 與 Supabase 設定好才打開（PD-068 PR 6）。
enum AppleSignInFeature {
    static let isEnabled: Bool = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "PackSmartAppleSignInEnabled") as? Bool { return value }
        #if DEBUG
        // 只在開發版用來看畫面；按下去仍會因為沒有 Apple 設定而失敗。
        return ProcessInfo.processInfo.arguments.contains("-appleSignInPreview")
        #else
        return false
        #endif
    }()
}
