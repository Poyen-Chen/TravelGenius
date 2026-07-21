//
//  PackingImageView.swift
//  TravelGenius
//
//  行李打包圖分享頁（Firstgram「第一次就拍到理想畫面」風格）：
//   ・理想構圖 AI 圖：風格預設 → OpenAI / Gemini 一次生出構圖漂亮的 flat-lay
//   ・完成度評分徽章：仿 Firstgram 分數，把「打包完成度 X%」烤進圖裡
//   ・深色電影感呈現：深色底＋觀景窗構圖框
//  無金鑰／離線／失敗時，以 ImageRenderer 把清單渲成原生排版卡（深色）— 永遠有圖可分享。
//

import SwiftUI

struct PackingImageView: View {
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    private enum Phase {
        case loading
        case ready(image: UIImage, isAI: Bool)
    }

    @State private var phase: Phase = .loading
    @State private var style: PackingImageStyle = .softStudio

    private static let slime = Color(red: 0.36, green: 0.78, blue: 0.42)
    private var packedCount: Int { (trip.packingItems ?? []).filter(\.isPacked).count }
    private var totalCount: Int { (trip.packingItems ?? []).count }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(white: 0.09), Color(white: 0.03)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                switch phase {
                case .loading:
                    loadingView
                case .ready(let image, let isAI):
                    readyView(image: image, isAI: isAI)
                }
            }
            .navigationTitle("行李打包圖")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task(id: style) { await load() }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text("正在生成理想打包圖…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Text("AI 生成約需 10–25 秒")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func readyView(image: UIImage, isAI: Bool) -> some View {
        VStack(spacing: 16) {
            Picker("風格", selection: $style) {
                ForEach(PackingImageStyle.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    ViewfinderFrame(color: Self.slime.opacity(0.9))
                        .padding(-8)
                )
                .padding(.horizontal, 24)

            Text(isAI ? "由 AI 依你的清單一次生成 · 切換風格會重生一張" : "TravelGenius 打包卡")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview("\(trip.name) 行李打包圖", image: Image(uiImage: image))
            ) {
                Label("分享打包圖", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Self.slime)
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
    }

    @MainActor
    private func load() async {
        phase = .loading
        let styledPrompt = PackingImageService.makePrompt(for: trip, style: style)

        // 1. 裝置端開源模型（有加套件＋模型才會啟用）
        if OnDeviceImageService.isAvailable,
           let onDevice = await OnDeviceImageService.shared.image(forPrompt: styledPrompt) {
            phase = .ready(image: badged(onDevice), isAI: true)
            return
        }
        // 2. OpenAI（gpt-image-1）優先，其次 Gemini
        if let openAI = await OpenAIImageService.generate(for: trip, style: style) {
            phase = .ready(image: badged(openAI), isAI: true)
            return
        }
        if let gemini = await PackingImageService.generate(for: trip, style: style) {
            phase = .ready(image: badged(gemini), isAI: true)
            return
        }
        // 3. 保底：原生排版卡（深色），已含完成度
        let renderer = ImageRenderer(content: PackingImageCard(trip: trip).frame(width: 340))
        renderer.scale = displayScale
        if let card = renderer.uiImage {
            phase = .ready(image: card, isAI: false)
        }
    }

    /// 把「打包完成度」徽章烤進 AI 圖右上角。
    @MainActor
    private func badged(_ image: UIImage) -> UIImage {
        let renderer = ImageRenderer(
            content: BadgedImage(uiImage: image, packed: packedCount, total: totalCount)
        )
        renderer.scale = image.scale
        return renderer.uiImage ?? image
    }
}

// MARK: - 完成度徽章（Firstgram 分數風）

struct CompletionBadge: View {
    let packed: Int
    let total: Int
    var size: CGFloat = 120

    private var pct: Double { total == 0 ? 0 : Double(packed) / Double(total) }
    private static let slime = Color(red: 0.36, green: 0.78, blue: 0.42)

    var body: some View {
        ZStack {
            Circle().fill(.black.opacity(0.55))
            Circle()
                .trim(from: 0, to: pct)
                .stroke(Self.slime, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(size * 0.1)
            VStack(spacing: 0) {
                Text("\(Int(pct * 100))%")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("打包完成")
                    .font(.system(size: size * 0.12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
    }
}

/// AI 圖 + 徽章的合成視圖（供 ImageRenderer 烤成可分享的單張圖）。
private struct BadgedImage: View {
    let uiImage: UIImage
    let packed: Int
    let total: Int

    var body: some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
            .frame(width: uiImage.size.width, height: uiImage.size.height)
            .overlay(alignment: .topTrailing) {
                CompletionBadge(packed: packed, total: total, size: uiImage.size.width * 0.2)
                    .padding(uiImage.size.width * 0.035)
            }
    }
}

// MARK: - 觀景窗構圖框（Firstgram 取景框風）

struct ViewfinderFrame: View {
    var color: Color = .white.opacity(0.7)
    var corner: CGFloat = 26
    var lineWidth: CGFloat = 2.5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { path in
                // 左上
                path.move(to: CGPoint(x: 0, y: corner)); path.addLine(to: .zero); path.addLine(to: CGPoint(x: corner, y: 0))
                // 右上
                path.move(to: CGPoint(x: w - corner, y: 0)); path.addLine(to: CGPoint(x: w, y: 0)); path.addLine(to: CGPoint(x: w, y: corner))
                // 左下
                path.move(to: CGPoint(x: 0, y: h - corner)); path.addLine(to: CGPoint(x: 0, y: h)); path.addLine(to: CGPoint(x: corner, y: h))
                // 右下
                path.move(to: CGPoint(x: w - corner, y: h)); path.addLine(to: CGPoint(x: w, y: h)); path.addLine(to: CGPoint(x: w, y: h - corner))
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 原生排版分享卡（深色保底，也可單獨渲染）

struct PackingImageCard: View {
    let trip: Trip

    private static let slime = Color(red: 0.36, green: 0.78, blue: 0.42)
    private static let columns = 4

    private var items: [PackingItem] {
        (trip.packingItems ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }
    private var packedCount: Int { items.filter(\.isPacked).count }

    private var rows: [[PackingItem]] {
        stride(from: 0, to: items.count, by: Self.columns).map {
            Array(items[$0..<min($0 + Self.columns, items.count)])
        }
    }

    private var subtitle: String {
        let country = StaticDataStore.shared.country(code: trip.countryCode)
        let place = "\(country?.flagEmoji ?? "") \(country?.nameZh ?? trip.countryCode)\(trip.city.isEmpty ? "" : "・\(trip.city)")"
        let dates = "\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))"
        return "\(place)　\(dates)"
    }

    @ViewBuilder
    private func itemTile(_ item: PackingItem) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(item.isPacked ? Self.slime.opacity(0.28) : Color.white.opacity(0.08))
                    .frame(width: 52, height: 52)
                Text(PackingGlyph.emoji(for: item))
                    .font(.system(size: 28))
                    .opacity(item.isPacked ? 1 : 0.45)
                if item.isPacked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Self.slime)
                        .background(Circle().fill(Color(white: 0.08)))
                        .offset(x: 19, y: -19)
                }
            }
            Text(item.name)
                .font(.system(size: 9))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(item.isPacked ? .white : .white.opacity(0.45))
        }
        .frame(width: 76, height: 84, alignment: .top)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                CompletionBadge(packed: packedCount, total: items.count, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.name)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("已打包 \(packedCount) / \(items.count)")
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("預估行李重量 約 \(PackingWeight.format(grams: trip.estimatedTotalGrams))／上限 \(Int(trip.baggageAllowanceKg)) kg")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
            }

            VStack(spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(row) { item in
                            itemTile(item)
                        }
                        ForEach(0..<(Self.columns - row.count), id: \.self) { _ in
                            Color.clear.frame(width: 76, height: 84)
                        }
                    }
                }
            }

            Divider().overlay(Color.white.opacity(0.15))

            Text("— 由 TravelGenius 產生 🧳")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(white: 0.11), Color(white: 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - 物品 → 圖示（emoji）對照

/// 依物品名稱關鍵字挑代表 emoji，找不到就退回分類 emoji。
/// 讓打包圖真的畫出「每一件物品」，且離線／免金鑰／模擬器可跑。
enum PackingGlyph {
    static func emoji(for item: PackingItem) -> String {
        let name = item.name
        for (keywords, glyph) in keywordMap where keywords.contains(where: name.contains) {
            return glyph
        }
        return categoryFallback[item.category] ?? "🧳"
    }

    // 順序：具體在前、通用在後（例如「外套/褲/鞋」先於「衣」）
    private static let keywordMap: [([String], String)] = [
        (["護照", "簽證"], "🛂"),
        (["機票", "登機", "車票", "票券", "票"], "🎫"),
        (["錢包", "皮夾"], "👛"),
        (["現金", "鈔", "信用卡", "金融卡", "卡片"], "💳"),
        (["外套", "大衣", "羽絨", "雨衣"], "🧥"),
        (["褲"], "👖"),
        (["拖鞋"], "🩴"),
        (["鞋"], "👟"),
        (["襪"], "🧦"),
        (["帽"], "🧢"),
        (["泳"], "🩱"),
        (["內衣", "貼身", "內著"], "🩲"),
        (["衣", "上衣", "服", "T恤"], "👕"),
        (["傘", "雨具"], "☂️"),
        (["行動電源", "充電寶", "電池"], "🔋"),
        (["轉接", "插座", "變壓", "充電", "傳輸線", "線材", "線"], "🔌"),
        (["相機"], "📷"),
        (["耳機"], "🎧"),
        (["手機"], "📱"),
        (["筆電", "電腦", "平板"], "💻"),
        (["牙"], "🪥"),
        (["刮鬍"], "🪒"),
        (["洗髮", "沐浴", "洗面", "洗顏", "肥皂", "毛巾", "盥洗"], "🧼"),
        (["防曬", "保養", "化妝", "乳液", "面膜", "保濕"], "🧴"),
        (["口罩"], "😷"),
        (["OK繃", "創可貼", "繃帶", "急救"], "🩹"),
        (["體溫", "溫度計"], "🌡️"),
        (["太陽眼鏡", "墨鏡"], "🕶️"),
        (["眼鏡", "隱形"], "👓"),
        (["藥", "止痛", "腸胃", "感冒", "暈車"], "💊"),
        (["水瓶", "水壺", "保溫瓶"], "🧴"),
        (["面紙", "衛生紙", "濕紙巾", "紙巾"], "🧻"),
        (["零食", "餅乾", "糖果"], "🍪"),
        (["書", "雜誌"], "📖"),
        (["筆"], "🖊️"),
        (["鑰匙"], "🔑"),
    ]

    private static let categoryFallback: [PackingCategory: String] = [
        .clothing: "👕",
        .electronics: "🔌",
        .documents: "🛂",
        .toiletries: "🧴",
        .health: "💊",
        .other: "🧳",
    ]
}
