//
//  PackingItemImage.swift
//  TravelGenius
//
//  物品真實去背照片：依名稱關鍵字對應到 Resources/ItemImages/ 內的 PNG（透明背景）。
//  找不到回 nil，呼叫端退回 emoji（PackingGlyph）。素材由 gpt-image-1 批次生成。
//

import UIKit

enum PackingItemImage {
    /// 物品的真實去背照片；沒有對應素材回 nil。
    static func image(for item: PackingItem) -> UIImage? {
        guard let key = key(for: item.name) else { return nil }
        return loadCached(key)
    }

    static func hasImage(for item: PackingItem) -> Bool {
        key(for: item.name) != nil
    }

    /// 對應到的素材 key（供打包器查真實相對大小）；沒有回 nil。
    static func imageKey(for item: PackingItem) -> String? {
        key(for: item.name)
    }

    // MARK: - 載入＋快取

    private static var cache: [String: UIImage?] = [:]

    private static func loadCached(_ key: String) -> UIImage? {
        if let cached = cache[key] { return cached }
        let image = Bundle.main.url(forResource: key, withExtension: "png")
            .flatMap { UIImage(contentsOfFile: $0.path) }
        cache[key] = image
        return image
    }

    // MARK: - 關鍵字對應（具體在前、通用在後）

    private static func key(for name: String) -> String? {
        for (keywords, key) in keywordMap where keywords.contains(where: name.contains) {
            return key
        }
        return nil
    }

    private static let keywordMap: [([String], String)] = [
        (["護照", "簽證"], "passport"),
        (["機票", "登機", "車票", "票券", "票", "影本", "保單", "聯絡卡", "證件"], "documents"),
        (["錢包", "皮夾", "現金", "鈔", "信用卡", "金融卡", "卡片", "卡"], "wallet"),
        (["外套", "大衣", "羽絨", "雨衣"], "jacket"),
        (["褲"], "pants"),
        (["鞋"], "shoes"),
        (["襪"], "socks"),
        (["帽"], "hat"),
        (["內衣", "貼身", "內著", "泳", "衣", "上衣", "服", "T恤"], "clothes"),
        (["傘", "雨具"], "umbrella"),
        (["行動電源", "充電寶", "電池"], "powerbank"),
        (["轉接", "插座", "變壓", "充電", "傳輸線", "線材", "線", "充電頭"], "charger"),
        (["相機"], "camera"),
        (["耳機"], "earphones"),
        (["手機"], "phone"),
        (["筆電", "電腦", "平板"], "laptop"),
        (["牙"], "toothbrush"),
        (["刮鬍", "洗髮", "沐浴", "洗面", "洗顏", "肥皂", "毛巾", "盥洗"], "toiletries"),
        (["防曬"], "sunscreen"),
        (["保養", "化妝", "乳液", "面膜", "保濕"], "toiletries"),
        (["口罩"], "mask"),
        (["太陽眼鏡", "墨鏡", "眼鏡", "隱形"], "sunglasses"),
        (["藥", "止痛", "腸胃", "感冒", "暈車", "OK繃", "創可貼", "繃帶", "急救", "體溫", "溫度計"], "medicine"),
        (["水瓶", "水壺", "保溫瓶"], "waterbottle"),
        (["面紙", "衛生紙", "濕紙巾", "紙巾", "方巾"], "tissues"),
        (["零食", "餅乾", "糖果", "點心"], "snack"),
        (["書", "雜誌"], "documents"),
    ]
}
