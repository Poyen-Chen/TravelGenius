//
//  PackingLayoutPacker.swift
//  TravelGenius
//
//  行李箱擺位打包器：用每件物品去背 PNG 的 alpha 輪廓（＝現成 segmentation）
//  做貪婪的「形狀佔用格」打包 —— 物品依實際大小與輪廓互相靠攏，非矩形、compact。
//  純運算、無外部相依；結果以格座標回傳，由 View 換算像素擺放。
//

import UIKit

struct PackedItem: Identifiable {
    let id: UUID
    let item: PackingItem
    let x: Int
    let y: Int
    let w: Int
    let h: Int
}

enum PackingLayoutPacker {
    static let cols = 44
    private static let maxRows = 400

    struct Result {
        let placed: [PackedItem]
        let cols: Int
        let rows: Int
    }

    // 每個素材 key 的「最長邊格數」＝真實相對大小
    private static let longestSide: [String: Int] = [
        "laptop": 24, "jacket": 22, "shoes": 20, "clothes": 19, "pants": 19,
        "umbrella": 18, "waterbottle": 18, "hat": 15, "camera": 15, "wallet": 14,
        "toiletries": 14, "documents": 15, "passport": 12, "powerbank": 13,
        "sunscreen": 12, "snack": 12, "tissues": 12, "phone": 11, "charger": 12,
        "medicine": 10, "sunglasses": 12, "mask": 10, "earphones": 9,
        "toothbrush": 12, "socks": 9,
    ]

    // MARK: - 打包

    static func pack(_ items: [PackingItem]) -> Result {
        struct Entry {
            let item: PackingItem
            let w: Int
            let h: Int
            let offsets: [(Int, Int)] // 實體格 (row, col)
        }

        var entries: [Entry] = items.map { item in
            let (mask, w, h) = maskAndSize(for: item)
            var offsets: [(Int, Int)] = []
            for r in 0..<h where r < mask.count {
                for c in 0..<w where c < mask[r].count && mask[r][c] {
                    offsets.append((r, c))
                }
            }
            return Entry(item: item, w: w, h: h, offsets: offsets)
        }
        // 大件先放，打包較緊
        entries.sort { $0.offsets.count > $1.offsets.count }

        var grid = Array(repeating: Array(repeating: false, count: cols), count: maxRows)
        var placed: [PackedItem] = []
        var usedRows = 1

        for entry in entries {
            guard let (px, py) = findSpot(entry.offsets, w: entry.w, h: entry.h, grid: grid) else { continue }
            for (r, c) in entry.offsets { grid[py + r][px + c] = true }
            usedRows = max(usedRows, py + entry.h)
            placed.append(PackedItem(id: entry.item.id, item: entry.item, x: px, y: py, w: entry.w, h: entry.h))
        }
        return Result(placed: placed, cols: cols, rows: usedRows)
    }

    /// 由上到下、由左到右找第一個「實體格不與已填格重疊」的位置（粗步進求快）。
    private static func findSpot(_ offsets: [(Int, Int)], w: Int, h: Int, grid: [[Bool]]) -> (Int, Int)? {
        guard w <= cols, !offsets.isEmpty else { return offsets.isEmpty ? nil : (0, 0) }
        let stepX = max(1, w / 6)
        let stepY = max(1, h / 6)
        var y = 0
        while y + h <= maxRows {
            var x = 0
            while x + w <= cols {
                var fits = true
                for (r, c) in offsets where grid[y + r][x + c] {
                    fits = false
                    break
                }
                if fits { return (x, y) }
                x += stepX
            }
            y += stepY
        }
        return nil
    }

    // MARK: - 遮罩＋尺寸

    private static func maskAndSize(for item: PackingItem) -> ([[Bool]], Int, Int) {
        if let image = PackingItemImage.image(for: item), let cg = image.cgImage {
            let longest = longestSide[PackingItemImage.imageKey(for: item) ?? ""] ?? weightLongest(item)
            let aspect = CGFloat(cg.width) / CGFloat(max(cg.height, 1))
            let w: Int
            let h: Int
            if aspect >= 1 {
                w = longest
                h = max(1, Int((CGFloat(longest) / aspect).rounded()))
            } else {
                h = longest
                w = max(1, Int((CGFloat(longest) * aspect).rounded()))
            }
            return (alphaMask(cg: cg, w: w, h: h), w, h)
        } else {
            // emoji fallback：實心方塊
            let side = weightLongest(item)
            return (Array(repeating: Array(repeating: true, count: side), count: side), side, side)
        }
    }

    private static func weightLongest(_ item: PackingItem) -> Int {
        switch item.estimatedUnitGrams {
        case 400...: 18
        case 120..<400: 13
        default: 10
        }
    }

    /// 把 alpha 降採樣到 w×h 布林格（>0.5 才算實體；濾掉柔陰影）。翻正為上左原點。
    private static func alphaMask(cg: CGImage, w: Int, h: Int) -> [[Bool]] {
        var fallback: [[Bool]] { Array(repeating: Array(repeating: true, count: w), count: h) }
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = buffer.withUnsafeMutableBytes({ raw -> CGContext? in
            CGContext(
                data: raw.baseAddress,
                width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        }) else { return fallback }
        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var mask = Array(repeating: Array(repeating: false, count: w), count: h)
        for row in 0..<h {
            let srcRow = h - 1 - row // CGContext 原點在左下，翻正
            for col in 0..<w {
                mask[row][col] = buffer[(srcRow * w + col) * 4 + 3] > 127
            }
        }
        return mask
    }
}
