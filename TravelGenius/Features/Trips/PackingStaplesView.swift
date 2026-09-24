import SwiftUI

struct PackingStaplesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.packmonTheme) private var theme
    @State private var items: [PackingStaples.Item] = []
    @State private var editor: PackingStaples.Item?
    @State private var pendingRemoval: PackingStaples.Item?
    @State private var errorMessage: String?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("只帶入新行程。修改或移除這裡的用品，不會改動已建立的行程；建立時也能移除這趟不需要的用品。")
                        .font(.footnote).foregroundStyle(theme.colors.secondaryText)
                    if items.isEmpty { Text("還沒有常備用品，先加入你每次都會帶的東西。") }
                    ForEach(items) { item in
                        Button { editor = item } label: {
                            HStack {
                                Label(item.name, systemImage: item.category.symbolName)
                                Spacer()
                                Text("×\(item.quantity)")
                                Image(systemName: "chevron.right")
                            }.foregroundStyle(theme.colors.text)
                        }
                        .swipeActions {
                            Button("移除", role: .destructive) { pendingRemoval = item }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.canvas)
            .navigationTitle("常備用品")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("新增", systemImage: "plus") {
                        editor = .init(name: "", category: .other, quantity: 1)
                    }.disabled(!loaded)
                }
            }
            .onAppear {
                do { items = try PackingStaples.load(); loaded = true }
                catch { errorMessage = error.localizedDescription }
            }
            .sheet(item: $editor) { item in PackingStapleEditor(draft: item, items: $items) }
            .confirmationDialog("從常備用品移除？", isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }), titleVisibility: .visible) {
                Button("移除", role: .destructive) {
                    let updated = items.filter { $0.id != pendingRemoval?.id }
                    do { try PackingStaples.save(updated); items = updated }
                    catch { errorMessage = error.localizedDescription }
                    pendingRemoval = nil
                }
                Button("取消", role: .cancel) { pendingRemoval = nil }
            } message: { Text("既有行程中的這項用品不會被刪除。") }
            .alert("無法更新常備用品", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}

private struct PackingStapleEditor: View {
    @State var draft: PackingStaples.Item
    @Binding var items: [PackingStaples.Item]
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("用品名稱", text: $draft.name)
                Picker("分類", selection: $draft.category) {
                    ForEach(PackingCategory.allCases) { Text($0.label).tag($0) }
                }
                Stepper("數量：\(draft.quantity)", value: $draft.quantity, in: 1...99)
                Text("只影響之後建立的新行程。已建立的清單不會跟著變更。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("常備用品設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        var updated = items
                        if let index = updated.firstIndex(where: { $0.id == draft.id }) { updated[index] = draft }
                        else { updated.append(draft) }
                        do { try PackingStaples.save(updated); items = updated; dismiss() }
                        catch { errorMessage = error.localizedDescription }
                    }.disabled(PackingStaples.normalized(draft.name).isEmpty)
                }
            }
            .alert("無法儲存", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}
