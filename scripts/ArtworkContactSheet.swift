import AppKit
import Foundation

struct ContactSheetTheme {
    let background: NSColor
    let card: NSColor
    let text: NSColor
    let name: String
}

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    fputs("usage: ArtworkContactSheet <assets.xcassets> <output-directory> <title>\n", stderr)
    exit(2)
}

let assetsURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: arguments[2], isDirectory: true)
let title = arguments[3]
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let imagesets = try FileManager.default.contentsOfDirectory(
    at: assetsURL,
    includingPropertiesForKeys: nil,
    options: [.skipsHiddenFiles]
).filter { $0.lastPathComponent.hasPrefix("packing-") && $0.pathExtension == "imageset" }
 .sorted { $0.lastPathComponent < $1.lastPathComponent }

let columns = 5
let cellWidth = 210
let cellHeight = 230
let headerHeight = 86
let rows = Int(ceil(Double(imagesets.count) / Double(columns)))
let canvasSize = NSSize(width: columns * cellWidth, height: headerHeight + rows * cellHeight)
let themes = [
    ContactSheetTheme(
        background: NSColor(calibratedRed: 0.96, green: 0.93, blue: 0.86, alpha: 1),
        card: NSColor(calibratedWhite: 1, alpha: 0.78),
        text: NSColor(calibratedWhite: 0.15, alpha: 1),
        name: "cream"
    ),
    ContactSheetTheme(
        background: NSColor(calibratedWhite: 0.10, alpha: 1),
        card: NSColor(calibratedWhite: 0.18, alpha: 1),
        text: NSColor(calibratedWhite: 0.94, alpha: 1),
        name: "dark"
    )
]

for theme in themes {
    let image = NSImage(size: canvasSize)
    image.lockFocus()
    theme.background.setFill()
    NSRect(origin: .zero, size: canvasSize).fill()

    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 24, weight: .bold),
        .foregroundColor: theme.text
    ]
    let subtitleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
        .foregroundColor: theme.text.withAlphaComponent(0.72)
    ]
    (title as NSString).draw(at: NSPoint(x: 24, y: canvasSize.height - 42), withAttributes: titleAttributes)
    ("61 exact stable-ID assets · 96 px card check · transparent PNG" as NSString)
        .draw(at: NSPoint(x: 24, y: canvasSize.height - 66), withAttributes: subtitleAttributes)

    let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
        .foregroundColor: theme.text
    ]

    for (index, imagesetURL) in imagesets.enumerated() {
        let id = imagesetURL.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "packing-", with: "")
        let sourceURL = imagesetURL.appendingPathComponent("\(id).png")
        guard let source = NSImage(contentsOf: sourceURL) else { continue }
        let column = index % columns
        let row = index / columns
        let x = CGFloat(column * cellWidth + 10)
        let y = canvasSize.height - CGFloat(headerHeight + (row + 1) * cellHeight) + 10
        let cardRect = NSRect(x: x, y: y, width: CGFloat(cellWidth - 20), height: CGFloat(cellHeight - 20))
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 18, yRadius: 18)
        theme.card.setFill()
        cardPath.fill()

        let artRect = NSRect(x: cardRect.minX + 47, y: cardRect.minY + 47, width: 96, height: 96)
        source.draw(in: artRect, from: .zero, operation: .sourceOver, fraction: 1)
        let labelRect = NSRect(x: cardRect.minX + 10, y: cardRect.minY + 14, width: cardRect.width - 20, height: 22)
        (id as NSString).draw(in: labelRect, withAttributes: labelAttributes)
    }

    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ArtworkContactSheet", code: 1)
    }
    try png.write(to: outputURL.appendingPathComponent("contact-sheet-\(theme.name).png"))
}
