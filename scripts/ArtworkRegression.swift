import Foundation
import ImageIO

private struct CatalogFile: Decodable {
    struct Item: Decodable {
        let id: String
        let artworkKey: String?
    }

    let items: [Item]
}

private struct AssetContents: Decodable {
    struct Image: Decodable { let filename: String? }
    let images: [Image]
}

@main struct ArtworkRegression {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let catalogURL = root.appendingPathComponent("TravelGenius/Resources/SeedData/packing_items.json")
        let catalog = try JSONDecoder().decode(CatalogFile.self, from: Data(contentsOf: catalogURL))
        precondition(catalog.items.count == 61)
        precondition(Set(catalog.items.map(\.id)).count == 61)
        let artworkKeys = catalog.items.compactMap(\.artworkKey)
        precondition(artworkKeys.count == 61)
        precondition(Set(artworkKeys).count == 61)

        for item in catalog.items {
            guard let key = item.artworkKey else { fatalError("Missing artworkKey for \(item.id)") }
            let assetDirectory = root.appendingPathComponent("TravelGenius/Assets.xcassets/packing-\(key).imageset")
            let contents = try JSONDecoder().decode(
                AssetContents.self,
                from: Data(contentsOf: assetDirectory.appendingPathComponent("Contents.json"))
            )
            precondition(contents.images.contains { $0.filename == "\(key).png" })

            let imageURL = assetDirectory.appendingPathComponent("\(key).png") as CFURL
            guard let source = CGImageSourceCreateWithURL(imageURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                fatalError("Unreadable artwork for \(item.id)")
            }
            precondition(image.width == 1024 && image.height == 1024)
            switch image.alphaInfo {
            case .first, .last, .premultipliedFirst, .premultipliedLast:
                break
            default:
                fatalError("Artwork lacks alpha for \(item.id)")
            }
        }

        print("61/61 item-owned artwork keys, asset catalogs, 1024×1024 PNGs and alpha channels: PASS")
    }
}
