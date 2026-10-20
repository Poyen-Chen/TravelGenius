//
//  PackingVisuals.swift
//  TravelGenius
//
//  圖片模式的視覺化：原因徽章、「這趟的客製化」篩選列、行李箱進度。
//  徽章只用來顯示，來源是同一個推薦引擎重新計算的結果，不寫回清單。
//

import SwiftUI

extension PackingListGenerator {
    /// 依這趟保存的快照重新計算每個目錄用品的調整原因；快照無效時回傳空集合。
    static func reasonKinds(for trip: Trip) -> [String: Set<PackingReasonKind>] {
        Dictionary(generate(for: trip).map { ($0.catalogItemID, $0.kinds) }, uniquingKeysWith: { $0.union($1) })
    }
}

enum PackingItemArtwork {
    static func image(for item: PackingItem) -> UIImage? {
        guard let definition = StaticDataStore.shared.packingCatalog.definition(
            catalogID: item.catalogItemID,
            name: item.name,
            isCustom: item.isCustom
        ), let artworkKey = definition.artworkKey else { return nil }
        return UIImage(named: "packing-\(artworkKey)")
    }
}

extension PackingReasonKind {
    /// 天氣與常備沒有對應的主題色，使用固定色；徽章上的符號一律白色，兩種外觀都可讀。
    func color(in theme: PackmonTheme) -> Color {
        switch self {
        case .weather: Color(red: 94 / 255, green: 127 / 255, blue: 163 / 255)
        case .trip: theme.colors.secondaryAccent
        case .personal: theme.colors.accent
        case .destination: theme.colors.secondaryText
        case .staple: Color(red: 184 / 255, green: 145 / 255, blue: 58 / 255)
        }
    }
}

struct PackingReasonBadge: View {
    let kind: PackingReasonKind
    var size: CGFloat = 22
    @Environment(\.packmonTheme) private var theme

    var body: some View {
        Image(systemName: kind.symbolName)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(kind.color(in: theme), in: Circle())
            .accessibilityHidden(true)
    }
}

/// 「這趟為你調整了 N 件」：點一個原因，相關物品保持清楚，其他淡出。
struct PackingCustomizationStrip: View {
    let counts: [(kind: PackingReasonKind, count: Int)]
    let tailoredCount: Int
    @Binding var selection: PackingReasonKind?
    @Environment(\.packmonTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("這趟為你調整了 \(tailoredCount) 件").font(.subheadline.weight(.bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(counts, id: \.kind) { entry in
                        let selected = selection == entry.kind
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { selection = selected ? nil : entry.kind }
                        } label: {
                            HStack(spacing: 6) {
                                PackingReasonBadge(kind: entry.kind, size: 20)
                                Text(entry.kind.label).font(.subheadline.weight(.semibold))
                                Text("\(entry.count)").font(.subheadline).monospacedDigit()
                                    .foregroundStyle(theme.colors.secondaryText)
                            }
                            .padding(.horizontal, 10).frame(minHeight: 40)
                            .background(selected ? theme.colors.accentSoft : theme.colors.elevatedSurface, in: Capsule())
                            .overlay(Capsule().strokeBorder(selected ? theme.colors.accent : theme.colors.separator, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain).foregroundStyle(theme.colors.text)
                        .accessibilityLabel("\(entry.kind.label)，\(entry.count) 件")
                        .accessibilityHint(selected ? "取消篩選" : "只突顯這類物品")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
    }
}

/// 打開的行李箱：已打包的物品插圖依序放進箱內，空位代表還沒裝的物品。
struct SuitcaseProgressView: View {
    let items: [PackingItem]
    let startDate: Date
    @Environment(\.packmonTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let slotLimit = 12
    private var packed: [PackingItem] { items.filter(\.isPacked) }
    private var slotCount: Int { max(1, min(items.count, Self.slotLimit)) }

    /// 物品多於格數時依比例換算，但有裝就至少一格、沒裝完就至少留一格空位。
    private var filledSlots: Int {
        guard items.count > Self.slotLimit else { return packed.count }
        guard !packed.isEmpty else { return 0 }
        guard packed.count < items.count else { return slotCount }
        let scaled = Int((Double(packed.count) / Double(items.count) * Double(slotCount)).rounded())
        return min(max(scaled, 1), slotCount - 1)
    }

    private var status: String {
        if !items.isEmpty && packed.count == items.count { return "全部裝好了！" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now),
                                                   to: Calendar.current.startOfDay(for: startDate)).day ?? 0
        return days > 0 ? "還有 \(days) 天出發" : days == 0 ? "今天出發" : "旅途中"
    }

    var body: some View {
        VStack(spacing: 4) {
            lid
            base
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.62), value: packed.map(\.id))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("打包進度")
        .accessibilityValue("\(packed.count) / \(items.count) 項已打包")
    }

    /// 主題強調色加上由上往下的暗部，iOS 17 沒有 Color.mix，所以用疊色。
    private func shell<S: Shape>(_ shape: S) -> some View {
        shape.fill(theme.colors.accent)
            .overlay(shape.fill(LinearGradient(colors: [.clear, .black.opacity(0.22)], startPoint: .top, endPoint: .bottom)))
    }

    private var lid: some View {
        HStack {
            Text(status).font(.subheadline.weight(.bold))
            Spacer(minLength: 8)
            Text("\(packed.count) / \(items.count)").font(.title3.weight(.black)).monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).frame(height: 52)
        .background(shell(UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 6,
                                                 bottomTrailingRadius: 6, topTrailingRadius: 20)))
        .overlay(alignment: .top) {
            let handle = UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10)
            handle.stroke(theme.colors.accent, lineWidth: 4)
                .overlay(handle.stroke(.black.opacity(0.22), lineWidth: 4))
                .frame(width: 64, height: 14).offset(y: -12)
        }
        .padding(.top, 12)
    }

    private var base: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
        let shown = Array(packed.prefix(filledSlots))
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(shown) { item in
                thumbnail(item).transition(.scale(scale: 0.4).combined(with: .move(edge: .top)).combined(with: .opacity))
            }
            ForEach(0..<(slotCount - shown.count), id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(theme.colors.separator, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(10)
        .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: 14))
        .padding(10)
        .background(shell(UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 22,
                                                 bottomTrailingRadius: 22, topTrailingRadius: 6)))
    }

    private func thumbnail(_ item: PackingItem) -> some View {
        Group {
            if let artwork = PackingItemArtwork.image(for: item) {
                Image(uiImage: artwork).resizable().scaledToFit()
            } else {
                Image(systemName: item.category.symbolName).font(.title3)
                    .foregroundStyle(theme.colors.secondaryText)
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
        .background(theme.colors.elevatedSurface, in: RoundedRectangle(cornerRadius: 10))
    }
}
