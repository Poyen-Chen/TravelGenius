//
//  PackingImageService.swift
//  TravelGenius
//
//  行李打包圖：以行李清單為素材，呼叫 Google Gemini 2.5 Flash Image（俗稱 Nano Banana）
//  生成一張俯視 flat-lay 打包插畫。無金鑰／離線／失敗時回 nil，由 UI 退回原生排版卡 — demo 永不空手。
//  金鑰放 Resources/Secrets.plist（已 gitignore），正式上架應改走自家後端代理。
//  注意：Claude/Anthropic 無生圖能力，故此處是另一個供應商（Gemini）。
//
//  makePrompt 為 OpenAI / Gemini / 裝置端三路共用；風格預設（Firstgram「一次到位」概念）也在這裡。
//

import UIKit

/// 生圖風格預設 — 讓 AI「第一次就生出理想構圖」，而非普通排列。
enum PackingImageStyle: String, CaseIterable, Identifiable {
    case softStudio
    case travelMag
    case darkMoody

    var id: String { rawValue }

    var label: String {
        switch self {
        case .softStudio: "柔光棚拍"
        case .travelMag: "旅行雜誌"
        case .darkMoody: "深色質感"
        }
    }

    var basePrompt: String {
        switch self {
        case .softStudio:
            return "A clean top-down flat-lay product photograph with soft diffused studio lighting, gentle pastel palette, subtle soft shadows, on a light neutral background."
        case .travelMag:
            return "A stylish top-down travel flat-lay in the style of a premium travel magazine spread, warm natural window light, a curated cohesive color story, tasteful props, editorial composition."
        case .darkMoody:
            return "A cinematic top-down flat-lay with dramatic moody lighting on a dark slate background, rich shadows and a single soft key light, refined premium look."
        }
    }
}

enum PackingImageService {
    private static let model = "gemini-2.5-flash-image"
    private static var cache: [String: UIImage] = [:]
    private static var inFlight: Set<String> = []

    /// 產生打包圖；同一份清單＋風格只呼叫一次（快取），生成中重複呼叫回 nil。
    @MainActor
    static func generate(for trip: Trip, style: PackingImageStyle) async -> UIImage? {
        let key = signature(for: trip, style: style)
        if let cached = cache[key] { return cached }
        guard !inFlight.contains(key) else { return nil }

        inFlight.insert(key)
        defer { inFlight.remove(key) }

        guard let image = await fetchImage(prompt: makePrompt(for: trip, style: style)) else { return nil }
        cache[key] = image
        return image
    }

    // MARK: - Prompt（三路共用）

    /// 依目的地與清單分類匯總，組出「理想構圖」flat-lay prompt（代表性，非逐件庫存）。
    static func makePrompt(for trip: Trip, style: PackingImageStyle) -> String {
        let country = StaticDataStore.shared.country(code: trip.countryCode)
        let place = "\(country?.nameZh ?? trip.countryCode)\(trip.city.isEmpty ? "" : "・\(trip.city)")"

        let items = (trip.packingItems ?? []).sorted { $0.sortIndex < $1.sortIndex }
        var byCategory: [PackingCategory: [String]] = [:]
        for item in items {
            byCategory[item.category, default: []].append(item.name)
        }
        let summary = PackingCategory.allCases.compactMap { category -> String? in
            guard let names = byCategory[category], !names.isEmpty else { return nil }
            return "\(category.label)：\(names.prefix(6).joined(separator: "、"))"
        }.joined(separator: "；")

        return """
        \(style.basePrompt) The scene shows travel items neatly arranged and ready to pack \
        for a \(trip.totalDays)-day trip to \(place). Representative items (not a literal inventory): \(summary). \
        Balanced overhead composition with clear negative space, every item fully visible and non-overlapping, \
        magazine-quality styling, cozy East-Asia travel mood. \
        Absolutely no text, words, letters, or labels anywhere in the image.
        """
    }

    // MARK: - Gemini generateContent

    private struct GeminiResponse: Decodable {
        struct Candidate: Decodable { let content: Content? }
        struct Content: Decodable { let parts: [Part]? }
        struct Part: Decodable { let inlineData: InlineData? }
        struct InlineData: Decodable { let data: String? }
        let candidates: [Candidate]?

        /// 取第一個 inline base64 影像資料（欄位為 camelCase inlineData；API 若改版需對照文件）
        var imageBase64: String? {
            candidates?
                .lazy
                .compactMap { $0.content?.parts?.compactMap { $0.inlineData?.data }.first }
                .first
        }
    }

    private static func fetchImage(prompt: String) async -> UIImage? {
        guard let apiKey = Secrets.geminiAPIKey else { return nil }

        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
            guard let base64 = decoded.imageBase64,
                  let imageData = Data(base64Encoded: base64),
                  let image = UIImage(data: imageData) else { return nil }
            return image
        } catch {
            return nil
        }
    }

    // MARK: - 快取簽章

    /// 以行程＋清單內容（項目名稱集合）＋風格為鍵；重新產生清單或換風格後會刷新。
    private static func signature(for trip: Trip, style: PackingImageStyle) -> String {
        let names = (trip.packingItems ?? []).map(\.name).sorted().joined(separator: "|")
        return "\(trip.id.uuidString)#\(style.rawValue)#\(names.hashValue)"
    }
}
