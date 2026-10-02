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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("建立新行程時，會帶入這些物品與數量。移除常備不會刪除既有行程的物品。")
                        .foregroundStyle(theme.colors.secondaryText)
                    if items.isEmpty && loaded {
                        PackmonCard {
                            VStack(spacing: 10) {
                                Image(systemName: "backpack").font(.largeTitle)
                                Text("慢慢變成你的清單").font(.headline)
                                Text("在打包物品旁按星號，或直接加入常備物品。")
                                    .font(.subheadline).multilineTextAlignment(.center)
                            }.frame(maxWidth: .infinity).padding(.vertical, 20)
                        }
                    }
                    ForEach(items) { item in
                        PackmonRowCard {
                            HStack(spacing: 12) {
                                Button { editor = item } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: item.category.symbolName).foregroundStyle(theme.colors.accent)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(item.name).font(.headline)
                                            Text("\(item.quantity) 件" + (item.unitWeightKg.map { "・單件 \($0.formatted()) kg" } ?? ""))
                                                .font(.footnote).foregroundStyle(theme.colors.secondaryText)
                                        }
                                        Spacer(minLength: 4)
                                        Image(systemName: "pencil").foregroundStyle(theme.colors.secondaryText)
                                    }.frame(minHeight: 44).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel("編輯 \(item.name)，\(item.quantity) 件")
                                Button { pendingRemoval = item } label: {
                                    Image(systemName: "xmark").frame(width: 44, height: 44)
                                }.buttonStyle(.plain).foregroundStyle(theme.colors.secondaryText)
                                 .accessibilityLabel("移除常備 \(item.name)")
                            }
                        }
                    }
                    Button { editor = .init(name: "", category: .other, quantity: 1) } label: {
                        Label("加入常備物品", systemImage: "plus")
                    }.buttonStyle(PackmonPrimaryButtonStyle()).disabled(!loaded)
                }.padding(20)
            }
            .foregroundStyle(theme.colors.text)
            .background(theme.colors.canvas)
            .navigationTitle("我的常備清單")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
            .onAppear {
                do { items = try PackingStaples.load(); loaded = true }
                catch { errorMessage = error.localizedDescription }
            }
            .sheet(item: $editor) { item in PackingStapleEditor(draft: item, items: $items) }
            .sheet(item: $pendingRemoval) { item in
                PackmonRemovalSheet(title: "移除常備用品？", name: item.name,
                    message: "之後的新行程不再自動帶入；已建立行程中的這項用品會保留。",
                    actionTitle: "移除常備用品") {
                    let updated = items.filter { $0.id != item.id }
                    do { try PackingStaples.save(updated); items = updated }
                    catch { errorMessage = error.localizedDescription }
                }
            }
            .alert("無法更新常備用品", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}

struct PackingStapleEditor: View {
    @State private var draft: PackingStaples.Item
    @Binding var items: [PackingStaples.Item]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.packmonTheme) private var theme
    @State private var weightText: String
    @State private var errorMessage: String?
    @State private var saved = false

    init(draft: PackingStaples.Item, items: Binding<[PackingStaples.Item]>) {
        _draft = State(initialValue: draft)
        _items = items
        _weightText = State(initialValue: draft.unitWeightKg.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("物品名稱") {
                    TextField("例如：耳塞", text: $draft.name).accessibilityLabel("物品名稱")
                }.listRowBackground(theme.colors.elevatedSurface)
                Section {
                    Picker("分類", selection: $draft.category) {
                        ForEach(PackingCategory.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("數量：\(draft.quantity)", value: $draft.quantity, in: 1...99)
                }.listRowBackground(theme.colors.elevatedSurface)
                Section {
                    TextField("不知道可以留空", text: $weightText).keyboardType(.decimalPad)
                        .accessibilityLabel("單件重量，公斤，選填")
                } header: { Text("單件重量（kg，選填）") }
                  footer: { Text("輸入 0–100 kg。重量會隨常備用品帶入新行程，不會回寫舊行程。") }
                  .listRowBackground(theme.colors.elevatedSurface)
                Section {
                    Text("只影響之後建立的新行程。已建立的清單不會跟著變更。")
                        .font(.footnote).foregroundStyle(theme.colors.secondaryText)
                    Button(items.contains(where: { $0.id == draft.id }) ? "儲存常備物品" : "加入常備清單", action: save)
                        .buttonStyle(PackmonPrimaryButtonStyle())
                        .disabled(PackingStaples.normalized(draft.name).isEmpty || saved)
                }.listRowBackground(theme.colors.elevatedSurface)
            }
            .scrollContentBackground(.hidden).background(theme.colors.canvas)
            .navigationTitle(items.contains(where: { $0.id == draft.id }) ? "編輯常備物品" : "新增常備物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .alert("無法儲存", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func save() {
        guard !saved else { return }
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { draft.unitWeightKg = nil }
        else {
            guard let weight = Double(raw.replacingOccurrences(of: ",", with: ".")),
                  weight.isFinite, (0...100).contains(weight) else {
                errorMessage = "請輸入 0–100 kg 的有效重量，或留空。"; return
            }
            draft.unitWeightKg = weight
        }
        var updated = items
        if let index = updated.firstIndex(where: { $0.id == draft.id }) { updated[index] = draft }
        else { updated.append(draft) }
        do { try PackingStaples.save(updated); items = updated; saved = true; dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
}
