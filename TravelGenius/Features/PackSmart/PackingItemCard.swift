import SwiftUI
import SwiftData

struct PackingItemCard: View {
    let item: PackingItem
    let isStaple: Bool
    let onToggle: () -> Void
    let onQuantity: () -> Void
    let onStaple: () -> Void
    let onRemove: () -> Void
    @Environment(\.packmonTheme) private var theme

    private var artwork: UIImage? {
        guard let key = PackingArtwork.key(catalogID: item.catalogItemID, name: item.name, isCustom: item.isCustom) else { return nil }
        return UIImage(named: "packing-\(key)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let artwork {
                    Image(uiImage: artwork).resizable().scaledToFit()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: item.category.symbolName).font(.system(size: 36, weight: .light))
                        Text("分類示意").font(.caption)
                    }.foregroundStyle(theme.colors.secondaryText)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 128).padding(.top, 36)
            .accessibilityHidden(true)
            .overlay(alignment: .top) {
            HStack {
                Button(action: onToggle) {
                    Image(systemName: item.isPacked ? "checkmark.square.fill" : "square")
                        .font(.title2)
                        .foregroundStyle(item.isPacked ? theme.colors.success : theme.colors.secondaryText)
                        .frame(width: 44, height: 44)
                }.buttonStyle(.plain)
                    .accessibilityLabel("\(item.name)，\(item.isPacked ? "已打包，取消" : "標記已打包")")
                    .accessibilityValue(item.isPacked ? "已打包" : "未打包")
                Spacer(minLength: 0)
                Menu {
                    Button("修改數量", systemImage: "number", action: onQuantity)
                    Button(isStaple ? "移除常備" : "加入常備", systemImage: isStaple ? "star.fill" : "star", action: onStaple)
                    Button("移除物品", systemImage: "trash", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }.tint(theme.colors.secondaryText).accessibilityLabel("\(item.name)的操作")
            }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(item.name).font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("×\(item.quantity)", action: onQuantity)
                    .font(.body).frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("\(item.name)數量，\(item.quantity) 件，修改")
            }.foregroundStyle(theme.colors.text)
            if let weight = item.unitWeightKg {
                Text("\(weight.formatted()) kg／件").font(.caption).foregroundStyle(theme.colors.secondaryText)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.colors.elevatedSurface, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
    }
}

struct PackingQuantityEditor: View {
    let item: PackingItem
    @State private var quantity: Int
    @State private var errorMessage: String?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    init(item: PackingItem) {
        self.item = item
        _quantity = State(initialValue: min(99, max(1, item.quantity)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Text(item.name)
                Stepper("數量：\(quantity)", value: $quantity, in: 1...99)
                Text(item.reasonKey).font(.footnote).foregroundStyle(.secondary)
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("修改數量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        let old = item.quantity
                        let autosave = context.autosaveEnabled
                        context.autosaveEnabled = false
                        defer { context.autosaveEnabled = autosave }
                        item.quantity = quantity
                        do { try context.save(); dismiss() }
                        catch { item.quantity = old; errorMessage = "儲存失敗，請重試。" }
                    }
                }
            }
        }.presentationDetents([.medium, .large])
    }
}
