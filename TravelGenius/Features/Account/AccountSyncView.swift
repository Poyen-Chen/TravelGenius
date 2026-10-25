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
                Text("會上傳行程（名稱、目的地、日期、打包偏好與清單、打包狀態）與常備用品，讓你換手機也能使用。支出與預算不會上傳；「健康」分類的物品預設不上傳。\n\n\(account.dataRegionNote)。授權的 PackSmart 管理員在處理你回報的問題時可以查看，每次查看都會留下紀錄。你可以隨時關閉同步或刪除雲端帳號。")
            }
            .alert("同步「健康」分類的物品？", isPresented: $confirmingHealth) {
                Button("同意同步") { Task { await account.setHealthConsent(true) } }
                Button("取消", role: .cancel) {}
            } message: {
                Text("藥品等健康類物品可能屬於敏感個人資料。同意後會上傳到雲端，你登入的每台裝置都會看到，授權管理員處理問題時也可能看到。之後關閉，下一次同步會把它們從雲端移除，手機上的仍保留。")
            }
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
                Label("這個版本尚未設定雲端服務，資料只存在這台手機。", systemImage: "iphone")
            case .signedOut:
                TextField("Email", text: $email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("寄送驗證碼") { Task { await account.sendCode(to: email) } }
                    .disabled(!email.contains("@"))
            case .awaitingCode(let email):
                Text("輸入寄到 \(email) 的 6 位數驗證碼").font(.footnote).foregroundStyle(theme.colors.secondaryText)
                TextField("驗證碼", text: $code).textContentType(.oneTimeCode).keyboardType(.numberPad)
                Button("登入") { Task { await account.verify(code: code); code = "" } }
                    .disabled(code.count < 6)
                Button("重新寄送") { Task { await account.sendCode(to: email) } }
                Button("改用其他 Email", role: .cancel) { account.cancelCode() }
            case .signedIn(let email):
                LabeledContent("已登入", value: email)
                Button("登出") { Task { await account.signOut() } }
            }
        } header: {
            Text("帳號")
        } footer: {
            if case .signedOut = account.phase { Text("不需要密碼。登入不會自動上傳資料，開啟同步後才會上傳。") }
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
            Text("\(account.dataRegionNote)。關閉同步、登出或移除 App 都不會刪除雲端帳號。")
        }
        .listRowBackground(theme.colors.elevatedSurface)
    }
}
