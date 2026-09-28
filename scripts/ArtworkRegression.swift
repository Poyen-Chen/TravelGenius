import Foundation

@main struct ArtworkRegression {
    static func main() {
        precondition(PackingArtwork.key(catalogID: "passport", legacyCatalogID: nil, isCustom: false) == "passport")
        precondition(PackingArtwork.key(catalogID: "unknown", legacyCatalogID: "passport", isCustom: false) == nil)
        precondition(PackingArtwork.key(catalogID: "passport-copies", legacyCatalogID: nil, isCustom: false) == nil)
        precondition(PackingArtwork.key(catalogID: "clothes-change", legacyCatalogID: nil, isCustom: false) == nil)
        precondition(PackingArtwork.key(catalogID: "regular-medicine", legacyCatalogID: nil, isCustom: false) == nil)
        precondition(PackingArtwork.key(catalogID: nil, legacyCatalogID: "passport", isCustom: true) == nil)
        precondition(PackingArtwork.key(catalogID: nil, legacyCatalogID: nil, isCustom: false) == nil)
        precondition(PackingArtwork.key(catalogID: nil, legacyCatalogID: "passport", isCustom: false) == "passport")
        precondition(PackingArtwork.key(catalogID: nil, legacyCatalogID: "tops", isCustom: false) == "tops")
        precondition(PackingArtwork.key(catalogID: nil, legacyCatalogID: "bottoms", isCustom: false) == "bottoms")
        precondition(PackingArtwork.key(catalogID: nil, legacyCatalogID: "underwear", isCustom: false) == "underwear")
        precondition(PackingArtwork.key(catalogID: nil, legacyCatalogID: "socks", isCustom: false) == "socks")
        precondition(PackingArtwork.key(catalogID: "charging-kit", legacyCatalogID: nil, isCustom: false) == "charging-kit")
        precondition(PackingArtwork.key(catalogID: "laptop-charger", legacyCatalogID: nil, isCustom: false) == "laptop-charger")
        precondition(PackingArtwork.key(catalogID: "camera-charger", legacyCatalogID: nil, isCustom: false) == "camera-charger")
        precondition(PackingArtwork.key(catalogID: "watch-charger", legacyCatalogID: nil, isCustom: false) == "watch-charger")
        precondition(PackingArtwork.activeCatalogIDs.count == 61)
        precondition(Set(PackingArtwork.activeCatalogIDs).count == 61)
        precondition(PackingArtwork.catalogAssets.count == 61)
        for id in PackingArtwork.activeCatalogIDs {
            precondition(PackingArtwork.key(catalogID: id, legacyCatalogID: nil, isCustom: false) == id)
        }
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for key in Set(PackingArtwork.catalogAssets.values) {
            precondition(FileManager.default.fileExists(atPath: root.appendingPathComponent("TravelGenius/Assets.xcassets/packing-\(key).imageset/\(key).png").path))
        }
        print("61/61 artwork identities, compatibility/custom fallback, near-synonym distinction and bundled coverage: PASS")
    }
}
