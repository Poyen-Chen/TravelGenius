import Foundation

@main struct ArtworkRegression {
    static func main() {
        precondition(PackingArtwork.key(catalogID: "passport", name: "renamed", isCustom: false) == "passport")
        precondition(PackingArtwork.key(catalogID: "unknown", name: "護照", isCustom: false) == nil)
        precondition(PackingArtwork.key(catalogID: "passport-copies", name: "護照影本", isCustom: false) == nil)
        precondition(PackingArtwork.key(catalogID: "clothes-change", name: "換洗衣物", isCustom: false) == nil)
        precondition(PackingArtwork.key(catalogID: "regular-medicine", name: "常用藥", isCustom: false) == nil)
        precondition(PackingArtwork.key(catalogID: nil, name: "護照", isCustom: true) == nil)
        precondition(PackingArtwork.key(catalogID: nil, name: "護照影本×2（分開放）", isCustom: false) == nil)
        precondition(PackingArtwork.key(catalogID: nil, name: "護照", isCustom: false) == "passport")
        precondition(PackingArtwork.key(catalogID: "charging-kit", name: "充電線與充電頭", isCustom: false) == "charging-kit")
        precondition(PackingArtwork.key(catalogID: "laptop-charger", name: "筆電充電器", isCustom: false) == "laptop-charger")
        precondition(PackingArtwork.key(catalogID: "camera-charger", name: "相機電池與充電器", isCustom: false) == "camera-charger")
        precondition(PackingArtwork.key(catalogID: "watch-charger", name: "手錶充電器", isCustom: false) == "watch-charger")
        precondition(PackingArtwork.activeCatalogIDs.count == 61)
        precondition(Set(PackingArtwork.activeCatalogIDs).count == 61)
        precondition(PackingArtwork.catalogAssets.count == 61)
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for key in Set(PackingArtwork.catalogAssets.values) {
            precondition(FileManager.default.fileExists(atPath: root.appendingPathComponent("TravelGenius/Assets.xcassets/packing-\(key).imageset/\(key).png").path))
        }
        print("61/61 artwork identities, compatibility/custom fallback, near-synonym distinction and bundled coverage: PASS")
    }
}
