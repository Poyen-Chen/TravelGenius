import SwiftUI

/// 「我的 → 帳號與同步」：Email 驗證碼登入、同意後才同步、健康類另外同意、衝突選擇、刪除帳號（PD-062）。
struct AccountSyncView: View {
    @Environment(CloudAccount.self) private var account
    @Environment(\.dismiss) private var dismiss
    @Environment(\.packmonTheme) private var theme
    @State private var email = ""
    @State private var code = ""
    @State private var confirmingSync = false
    @State private var confirmingHealth = false
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                if case .signedIn = account.phase {
                    syncSection
                    if !account.conflicts.isEmpty { conflictSection }
                    privacySection
                }
                if let message = account.message {
                    Section { Text(message).font(.footnote).foregroundStyle(theme.colors.secondaryText) }
                        .listRowBackground(theme.colors.elevatedSurface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.canvas)
            .disabled(account.isWorking)
            .overlay { if account.isWorking { ProgressView().controlSize(.large) } }
            .navigationTitle("帳號與同步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .alert("開啟雲端同步？", isPresented: $confirmingSync) {
                Button("同意並開啟") { account.syncEnabled = true; Task { await account.synchronize() } }
                Button("取消", role: .cancel) {}
            } message: {
                Text("開啟後，行程和行李會在手機與網頁版之間同步。")
            }
            .alert("同步「健康」分類的物品？", isPresented: $confirmingHealth) {
                Button("同意同步") { Task { await account.setHealthConsent(true) } }
                Button("取消", role: .cancel) {}
            } message: {
                Text("藥品等健康物品要另外同意，才會一併同步。")
            }
            .task(id: account.phase) { await account.refreshLinkedProviders() }
            .confirmationDialog("刪除雲端帳號？", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("刪除雲端帳號與資料", role: .destructive) { Task { await account.deleteAccount() } }
            } message: {
                Text("雲端上的帳號、行程與常備用品會立即刪除，無法復原。這台手機上的資料會保留。")
            }
        }
    }

    @ViewBuilder private var accountSection: some View {
        Section {
            switch account.phase {
            case .unconfigured:
                Label("可以先在這台裝置離線使用。", systemImage: "iphone")
            case .signedOut:
                if account.showsAppleSignIn {
                    AppleSignInButton { Task { await account.signInWithApple() } }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                TextField("Email", text: $email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("寄送驗證碼") { Task { await account.sendCode(to: email) } }
                    .disabled(!email.contains("@"))
            case .awaitingCode(let email):
                Text("驗證碼已寄到這封信。").font(.footnote).foregroundStyle(theme.colors.secondaryText)
                TextField("驗證碼", text: $code).textContentType(.oneTimeCode).keyboardType(.numberPad)
                Button("登入") { Task { await account.verify(code: code); code = "" } }
                    .disabled(code.count < 6)
                Button("重新寄送") { Task { await account.sendCode(to: email) } }
                Button("改用其他 Email", role: .cancel) { account.cancelCode() }
            case .signedIn:
                LabeledContent("已登入", value: account.accountLabel)
                if account.showsAppleLink {
                    Button("也用 Apple 登入這個帳號") { Task { await account.linkApple() } }
                }
                Button("登出") { Task { await account.signOut() } }
            }
        } header: {
            Text("帳號")
        } footer: {
            if case .signedOut = account.phase { Text("登入不會自動上傳，開啟同步後才會上傳。") }
        }
        .listRowBackground(theme.colors.elevatedSurface)
    }

    private var syncSection: some View {
        Section {
            Toggle("雲端同步", isOn: Binding(
                get: { account.syncEnabled },
                set: { newValue in if newValue { confirmingSync = true } else { account.syncEnabled = false } }))
            Toggle("同步「健康」分類的物品", isOn: Binding(
                get: { account.healthConsent },
                set: { newValue in if newValue { confirmingHealth = true } else { Task { await account.setHealthConsent(false) } } }))
                .disabled(!account.syncEnabled)
            Button("立即同步") { Task { await account.synchronize() } }
                .disabled(!account.syncEnabled)
            if let last = account.lastSyncedAt {
                LabeledContent("上次同步", value: last.formatted(date: .abbreviated, time: .shortened))
            }
        } header: {
            Text("同步")
        } footer: {
            Text("開啟 App、回到 App 時會自動同步。沒有網路時先存在手機，下次同步補上。")
        }
        .listRowBackground(theme.colors.elevatedSurface)
    }

    private var conflictSection: some View {
        Section {
            ForEach(account.conflicts) { conflict in
                VStack(alignment: .leading, spacing: 8) {
                    Text(conflict.title.isEmpty ? "一份資料" : conflict.title).font(.headline)
                    Text(conflictDetail(conflict)).font(.footnote).foregroundStyle(theme.colors.secondaryText)
                    HStack {
                        Button(conflict.localDeleted ? "刪除" : "保留這台手機的版本") {
                            Task { await account.resolve(conflict, keepLocal: true) }
                        }
                        Spacer()
                        Button(conflict.remoteDeleted ? "刪除" : "使用雲端版本") {
                            Task { await account.resolve(conflict, keepLocal: false) }
                        }
                    }.buttonStyle(.bordered).tint(theme.colors.accent)
                }.padding(.vertical, 4)
            }
        } header: {
            Text("需要你選擇")
        } footer: {
            Text("這些資料在這台手機和另一台裝置都被修改過。選擇後另一個版本會被取代。")
        }
        .listRowBackground(theme.colors.elevatedSurface)
    }

    private func conflictDetail(_ conflict: CloudSyncConflict) -> String {
        if conflict.remoteDeleted { return "另一台裝置刪除了它，這台手機則修改過。" }
        if conflict.localDeleted { return "這台手機刪除了它，另一台裝置則修改過。" }
        return "兩邊都修改過。"
    }

    private var privacySection: some View {
        Section {
            Button("刪除雲端帳號", role: .destructive) { confirmingDelete = true }
        } footer: {
            Text("關閉同步、登出或移除 App 都不會刪除雲端帳號。")
        }
        .listRowBackground(theme.colors.elevatedSurface)
    }
}
