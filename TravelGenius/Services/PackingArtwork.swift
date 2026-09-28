import Foundation

/// Bundled representative artwork, never a network lookup or fuzzy name match.
enum PackingArtwork {
    static let activeCatalogIDs = [
        "passport", "payment-card", "tops", "bottoms", "underwear", "socks",
        "walking-shoes", "toothbrush", "toothpaste", "sleepwear", "phone", "laptop",
        "tablet", "camera", "smartwatch", "headphones", "charging-kit", "laptop-charger",
        "camera-charger", "memory-card", "watch-charger", "power-bank", "plug-adapter",
        "skincare", "sanitary-products", "travel-document-backup", "local-cash",
        "driving-documents", "light-jacket", "sweater-fleece", "warm-coat", "scarf",
        "warm-hat", "waterproof-gloves", "folding-umbrella", "rain-jacket", "water-bottle",
        "sunscreen", "sun-hat", "sunglasses", "hand-warmer", "swimsuit", "wet-item-bag",
        "outdoor-shoes", "daypack", "waterproof-nonslip-shoes", "thermal-base-layer",
        "ski-socks", "ski-goggles", "ski-jacket", "ski-pants", "workout-clothes",
        "business-clothes", "business-cards", "formal-clothes", "formal-shoes", "locker-lock",
        "slippers", "quick-dry-towel", "laundry-supplies", "laundry-bag"
    ]

    static let catalogAssets = Dictionary(uniqueKeysWithValues: activeCatalogIDs.map { ($0, $0) })

    static func key(catalogID: String?, legacyCatalogID: String?, isCustom: Bool) -> String? {
        if let catalogID, !catalogID.isEmpty { return catalogAssets[catalogID] }
        guard !isCustom else { return nil }
        guard let legacyCatalogID else { return nil }
        return catalogAssets[legacyCatalogID]
    }
}
