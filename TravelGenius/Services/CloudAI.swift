//
//  CloudAI.swift
//  TravelGenius
//
//  第三方雲端 AI（OpenAI 打包圖、Anthropic 冷知識）的使用閘門。三個條件都成立才會送出資料：
//   1. 使用者明確同意。App Store 審查指南 5.1.2(i) 要求分享給第三方 AI 前揭露並取得明確許可。
//   2. 年齡層不是 13–17。OpenAI 與 Anthropic 對未滿 18 歲的使用者都有額外保護要求。
//   3. 有可用的服務憑證。只有 Debug 版會讀 Secrets.plist；Release 版不含任何金鑰，
//      要在正式版開放雲端 AI，必須先改走自家後端代理。
//

import Foundation

enum CloudAI {
    enum Provider {
        case openAI
        case anthropic
    }

    static let consentKey = "consent.cloudAI.v1"

    static var hasConsent: Bool {
        get { UserDefaults.standard.bool(forKey: consentKey) }
        set { UserDefaults.standard.set(newValue, forKey: consentKey) }
    }

    static var isMinor: Bool { UserPreferences.load().ageBand == .teen }

    static func isConfigured(_ provider: Provider) -> Bool {
        switch provider {
        case .openAI: Secrets.openAIAPIKey != nil
        case .anthropic: Secrets.anthropicAPIKey != nil
        }
    }

    static var isConfiguredAny: Bool { isConfigured(.openAI) || isConfigured(.anthropic) }

    /// 可以向使用者提出同意請求：非未成年，且服務可用
    static func canOffer(_ provider: Provider) -> Bool { !isMinor && isConfigured(provider) }

    /// 可以實際送出資料
    static func isAllowed(_ provider: Provider) -> Bool { hasConsent && canOffer(provider) }

    static let consentTitle = "使用雲端 AI 功能？"
    static let consentMessage = """
    開啟後，TravelGenius 會把以下資料傳給第三方 AI 服務來產生內容：
    ・行李打包圖：目的地、旅行天數與清單物品名稱，傳給 OpenAI
    ・小史萊姆冷知識：目的地國家與城市，傳給 Anthropic
    不會傳送你的姓名、所在位置、支出或照片。不開啟仍可使用所有核心功能，也可隨時在「偏好設定」關閉。未滿 18 歲無法使用。
    """
}

/// API 金鑰只在 Debug 版讀取，供開發測試。Release 版一律回傳 nil，
/// 且 Secrets.plist 由 Release 設定的 EXCLUDED_SOURCE_FILE_NAMES 排除在 App bundle 之外。
enum Secrets {
    static let anthropicAPIKey: String? = value(forKey: "ANTHROPIC_API_KEY", requiredPrefix: "sk-ant-")
    static let openAIAPIKey: String? = value(forKey: "OPENAI_API_KEY", requiredPrefix: "sk-")

    private static func value(forKey key: String, requiredPrefix: String) -> String? {
        #if DEBUG
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let value = plist[key] as? String,
              value.hasPrefix(requiredPrefix) else { return nil }
        return value
        #else
        return nil
        #endif
    }
}
