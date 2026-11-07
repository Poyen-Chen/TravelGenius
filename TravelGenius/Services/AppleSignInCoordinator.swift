import AuthenticationServices
import SwiftUI
import UIKit

/// 用系統的 Sign in with Apple 畫面取得 identity token（PD-068）。Apple 的畫面本身會用 Face ID 或密碼確認。
/// 只用 identity token；不使用 authorization code（換 code 需要 Apple client secret，不能放在 App 裡）。
@MainActor
final class AppleSignInCoordinator: NSObject, AppleIdentityProviding {
    private var continuation: CheckedContinuation<AppleIdentity, Error>?
    private var nonce: AppleNonce?
    private var controller: ASAuthorizationController?

    func requestIdentity() async throws -> AppleIdentity {
        // 每次都產生新的 nonce；上一個還沒完成的請求視為失敗。
        finish(.failure(AppleIdentityError.failed))
        let nonce: AppleNonce
        do { nonce = try AppleNonceMaker.make() } catch { throw AppleIdentityError.failed }
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonce.hashed
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.nonce = nonce
            self.controller = controller
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<AppleIdentity, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        nonce = nil
        controller = nil
        continuation.resume(with: result)
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        // 姓名與 Email 不保存：Email 以 Supabase 回傳的 session 為準。
        let token = (authorization.credential as? ASAuthorizationAppleIDCredential)?.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        MainActor.assumeIsolated {
            guard let token, let nonce else { return finish(.failure(AppleIdentityError.failed)) }
            finish(.success(AppleIdentity(idToken: token, rawNonce: nonce.raw)))
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let canceled = (error as? ASAuthorizationError)?.code == .canceled
        MainActor.assumeIsolated {
            finish(.failure(canceled ? AppleIdentityError.canceled : AppleIdentityError.failed))
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}

/// Apple 官方的「使用 Apple 登入」按鈕，不改顏色、不做成 Packmon 樣式。
struct AppleSignInButton: View {
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AppleIDButton(style: colorScheme == .dark ? .white : .black, action: action)
            .id(colorScheme)
            .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
            .accessibilityLabel("使用 Apple 登入")
    }
}

private struct AppleIDButton: UIViewRepresentable {
    var style: ASAuthorizationAppleIDButton.Style
    var action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: style)
        button.cornerRadius = 12
        button.addTarget(context.coordinator, action: #selector(Coordinator.tap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ button: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tap() { action() }
    }
}
