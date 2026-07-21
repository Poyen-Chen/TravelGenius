//
//  OpenAIImageService.swift
//  TravelGenius
//
//  行李打包圖（雲端）：OpenAI Images API（gpt-image-1）。以清單為素材生成氛圍 flat-lay。
//  按張計費、需 OPENAI_API_KEY（放 gitignored Secrets.plist）；模擬器可用（純網路呼叫）。
//  正式上架應改走自家後端代理，別把金鑰包進 App。
//

import UIKit

enum OpenAIImageService {
    private static let model = "gpt-image-1"
    private static var cache: [String: UIImage] = [:]
    private static var inFlight: Set<String> = []

    @MainActor
    static func generate(for trip: Trip, style: PackingImageStyle) async -> UIImage? {
        let key = signature(for: trip, style: style)
        if let cached = cache[key] { return cached }
        guard !inFlight.contains(key) else { return nil }

        inFlight.insert(key)
        defer { inFlight.remove(key) }

        guard let image = await fetchImage(prompt: PackingImageService.makePrompt(for: trip, style: style)) else { return nil }
        cache[key] = image
        return image
    }

    private struct ImagesResponse: Decodable {
        struct Item: Decodable { let b64_json: String? }
        let data: [Item]
    }

    private static func fetchImage(prompt: String) async -> UIImage? {
        guard let apiKey = Secrets.openAIAPIKey else { return nil }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "size": "1024x1024",
            "quality": "low",   // demo 省成本/加速；要更精緻改 "medium"/"high"
            "n": 1,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(ImagesResponse.self, from: data)
            guard let base64 = decoded.data.first?.b64_json,
                  let imageData = Data(base64Encoded: base64),
                  let image = UIImage(data: imageData) else { return nil }
            return image
        } catch {
            return nil
        }
    }

    private static func signature(for trip: Trip, style: PackingImageStyle) -> String {
        let names = (trip.packingItems ?? []).map(\.name).sorted().joined(separator: "|")
        return "\(trip.id.uuidString)#\(style.rawValue)#\(names.hashValue)"
    }
}
