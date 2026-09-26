import Foundation

/// Bundled representative artwork, never a network lookup or fuzzy name match.
enum PackingArtwork {
    static let catalogAssets = [
        "passport": "passport", "tops": "clothes", "bottoms": "clothes",
        "underwear": "clothes", "socks": "clothes", "sleepwear": "clothes",
        "charging-kit": "charger", "sunscreen": "sunscreen", "folding-umbrella": "umbrella"
    ]

    static func key(catalogID: String?) -> String? {
        guard let catalogID, !catalogID.isEmpty else { return nil }
        return catalogAssets[catalogID]
    }
}
