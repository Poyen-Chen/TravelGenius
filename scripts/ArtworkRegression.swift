import Foundation

@main struct ArtworkRegression {
    static func main() {
        precondition(PackingArtwork.key(catalogID: "passport", name: "renamed", isCustom: false) == "passport")
        precondition(PackingArtwork.key(catalogID: "unknown", name: "護照", isCustom: false) == nil)
        precondition(PackingArtwork.key(catalogID: nil, name: "護照", isCustom: true) == nil)
        precondition(PackingArtwork.key(catalogID: nil, name: "護照影本×2（分開放）", isCustom: false) == nil)
        precondition(PackingArtwork.key(catalogID: nil, name: "護照", isCustom: false) == "passport")
        precondition(PackingArtwork.key(catalogID: "charging-kit", name: "充電線與充電頭", isCustom: false) == "charger")
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for key in Set(PackingArtwork.catalogAssets.values) {
            precondition(FileManager.default.fileExists(atPath: root.appendingPathComponent("TravelGenius/Assets.xcassets/packing-\(key).imageset/\(key).png").path))
        }
        print("Artwork exact identity, custom/unknown fallback, kit distinction and bundled coverage: PASS")
    }
}
