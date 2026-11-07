import SwiftUI

/// 新安裝的第一頁：Email 驗證碼，可略過先試用。已完成 onboarding 的安裝不會看到（PD-066）。
struct AccountGateView: View {
    var onComplete: () -> Void

    @Environment(CloudAccount.self) private var account
    @Environment(\.packmonTheme) private var theme
    @State private var email = ""
    @State private var code = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            MascotView(expression: .happy, size: 110)
            content
            if let message = account.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(theme.colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            actions
        }
        .padding(24)
        .foregroundStyle(theme.colors.text)
        .background(theme.colors.canvas)
        .disabled(account.isWorking)
        .overlay { if account.isWorking { ProgressView().controlSize(.large) } }
    }

    @ViewBuilder private var content: some View {
        switch account.phase {
        case .unconfigured:
            Text("先在這台手機試用")
                .font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
            Text("可以先在這台裝置離線使用。")
                .foregroundStyle(theme.colors.secondaryText).multilineTextAlignment(.center)
        case .signedOut:
            Text("先建立你的帳號")
                .font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
            // Apple 按鈕顯示時才改這句（PD-068）。
            Text(account.showsAppleSignIn ? "用 Apple 或 Email 登入，換手機也能找回行程。" : "用 Email 收驗證碼，換手機也能找回行程。")
                .foregroundStyle(theme.colors.secondaryText).multilineTextAlignment(.center)
            if account.showsAppleSignIn {
                AppleSignInButton { Task { await account.signInWithApple() } }
            }
            field("Email", text: $email, contentType: .emailAddress, keyboard: .emailAddress)
        case .awaitingCode:
            Text("輸入驗證碼")
                .font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
            Text("驗證碼已寄到這封信。")
                .foregroundStyle(theme.colors.secondaryText).multilineTextAlignment(.center)
            field("驗證碼", text: $code, contentType: .oneTimeCode, keyboard: .numberPad)
        case .signedIn:
            Text("開啟雲端同步？")
                .font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
            Text("開啟後，行程和行李會在手機與網頁版之間同步。")
                .foregroundStyle(theme.colors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private var actions: some View {
        switch account.phase {
        case .unconfigured:
            Button("繼續", action: onComplete).buttonStyle(PackmonPrimaryButtonStyle())
        case .signedOut:
            Button("寄送驗證碼") { Task { await account.sendCode(to: email) } }
                .buttonStyle(PackmonPrimaryButtonStyle())
                .disabled(!email.contains("@"))
            skipButton
        case .awaitingCode(let sent):
            Button("登入") { Task { await account.verify(code: code) } }
                .buttonStyle(PackmonPrimaryButtonStyle())
                .disabled(code.count < 6)
            Button("重新寄送") { Task { await account.sendCode(to: sent) } }
                .frame(minHeight: 44)
            Button("改用其他 Email") { code = ""; account.cancelCode() }
                .frame(minHeight: 44)
            if account.showsAppleSignIn {
                Button("改用 Apple 登入") { code = ""; account.cancelCode(); Task { await account.signInWithApple() } }
                    .frame(minHeight: 44)
            }
            skipButton
        case .signedIn:
            Button("同意並開啟") {
                account.syncEnabled = true
                Task {
                    await account.synchronize()
                    if account.message == nil { onComplete() }
                }
            }
            .buttonStyle(PackmonPrimaryButtonStyle())
            Button("先登入，稍後再同步", action: onComplete).frame(minHeight: 44)
        }
    }

    private var skipButton: some View {
        Button("先略過，試用看看", action: onComplete).frame(minHeight: 44)
    }

    private func field(_ title: String, text: Binding<String>, contentType: UITextContentType, keyboard: UIKeyboardType) -> some View {
        TextField(title, text: text)
            .textContentType(contentType)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(14)
            .background(theme.colors.elevatedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
