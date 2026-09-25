import Foundation

/// Bundled representative artwork, never a network lookup or fuzzy name match.
enum PackingArtwork {
    static let catalogAssets = [
        "passport": "passport", "clothes-change": "clothes",
        "charging-kit": "charger", "sunscreen": "sunscreen", "folding-umbrella": "umbrella"
    ]

    static func key(catalogID: String?, name: String, isCustom: Bool) -> String? {
        if let catalogID, !catalogID.isEmpty { return catalogAssets[catalogID] }
        guard !isCustom else { return nil }
        let legacy = ["護照": "passport", "換洗衣物": "clothes", "充電線與充電頭": "charger",
                      "防曬乳": "sunscreen", "摺疊傘": "umbrella"]
        return legacy[name]
    }
}
