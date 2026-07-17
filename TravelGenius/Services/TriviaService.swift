//
//  TriviaService.swift
//  TravelGenius
//
//  小史萊姆的旅遊冷知識：透過 Claude API 依目的地生成（每 session 批次抓 5 則輪播），
//  無金鑰或離線時退回內建冷知識庫 — demo 永不空手。
//  金鑰放 Resources/Secrets.plist（已 gitignore），正式上架應改走自家後端代理。
//

import Foundation

enum Secrets {
    static let anthropicAPIKey: String? = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let key = plist["ANTHROPIC_API_KEY"] as? String,
              key.hasPrefix("sk-ant-") else { return nil }
        return key
    }()
}

enum TriviaService {
    private static let model = "claude-sonnet-4-6"
    private static var cache: [String: [String]] = [:]
    private static var cursor: [String: Int] = [:]
    private static var inFlight: Set<String> = []

    /// 取得下一則冷知識（首次呼叫會非同步抓一批；抓不到就用內建庫輪播）
    @MainActor
    static func nextFact(for trip: Trip) async -> String {
        let cacheKey = "\(trip.countryCode)-\(trip.city)"

        if cache[cacheKey] == nil, !inFlight.contains(cacheKey) {
            inFlight.insert(cacheKey)
            defer { inFlight.remove(cacheKey) }
            if let fetched = await fetchFacts(for: trip), !fetched.isEmpty {
                cache[cacheKey] = fetched
            }
        }

        let facts = cache[cacheKey] ?? fallbackFacts(countryCode: trip.countryCode)
        guard !facts.isEmpty else { return "打包愉快！有問題隨時戳我 🧳" }
        let index = cursor[cacheKey, default: 0]
        cursor[cacheKey] = index + 1
        return facts[index % facts.count]
    }

    // MARK: - Claude API

    private struct MessagesResponse: Decodable {
        struct Content: Decodable { let text: String? }
        let content: [Content]
    }

    private static func fetchFacts(for trip: Trip) async -> [String]? {
        guard let apiKey = Secrets.anthropicAPIKey else { return nil }
        let country = StaticDataStore.shared.country(code: trip.countryCode)?.nameZh ?? trip.countryCode
        let place = trip.city.isEmpty ? country : "\(country)\(trip.city)"

        let prompt = """
        你是旅遊 App 的吉祥物「小史萊姆」。請提供 5 則關於「\(place)」旅遊的冷知識，\
        主題涵蓋當地文化、交通、食物或習俗，內容要冷門有趣、對旅客實用。\
        每則 20 到 45 個字、繁體中文、語氣口語可愛，不要編號、不要前言。\
        只輸出 JSON 字串陣列，例如：["冷知識一","冷知識二"]
        """

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
            guard let text = decoded.content.first?.text else { return nil }
            return parseFacts(from: text)
        } catch {
            return nil
        }
    }

    /// 從回覆中擷取 JSON 陣列（容忍 code fence 或前後雜訊）
    private static func parseFacts(from text: String) -> [String]? {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]"), start < end else { return nil }
        let json = String(text[start...end])
        guard let data = json.data(using: .utf8),
              let facts = try? JSONDecoder().decode([String].self, from: data) else { return nil }
        return facts.filter { !$0.isEmpty }
    }

    // MARK: - 內建冷知識（離線／無金鑰 fallback）

    private static func fallbackFacts(countryCode: String) -> [String] {
        switch countryCode {
        case "JP":
            [
                "日本的自動販賣機密度世界第一，平均每 23 人就有一台，深山裡也找得到 🍹",
                "東京車站每天約有 4,000 班列車進出，卻幾乎不誤點，平均延誤不到一分鐘",
                "日本很多溫泉旅館的浴衣「左襟在上」才是正確穿法，反過來是壽衣穿法喔",
                "百元店的品質好到日本人自己也天天逛，伴手禮在 Daiso 補貨完全不丟臉",
            ]
        case "KR":
            [
                "韓國地鐵手機訊號滿格，因為全線都有基地台 — 通勤追劇是全民運動 📱",
                "在韓國吃飯碗不端起來才有禮貌，跟台灣日本剛好相反",
                "韓國的「防彈咖啡廳」超多插座，點一杯咖啡坐一下午完全沒問題",
                "首爾的公車顏色有意義：藍色跑幹線、綠色接社區、紅色去郊區",
            ]
        case "TW":
            [
                "台灣的便利商店密度世界前段班，平均每 1,300 人就有一家 🏪",
                "垃圾車放〈少女的祈禱〉是全球少見的「追垃圾車」文化",
                "台北捷運的博愛座讓座文化，連觀光客都感受得到壓力（笑）",
            ]
        default:
            []
        }
    }
}
