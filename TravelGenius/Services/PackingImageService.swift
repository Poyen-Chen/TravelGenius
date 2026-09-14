//
//  PackingImageService.swift
//  TravelGenius
//
//  行李打包圖的共用 prompt 與風格預設，供裝置端 OnDeviceImageService 與經同意的 OpenAIImageService 使用。
//  Gemini 路徑已移除：Gemini API 條款禁止用於未滿 18 歲可能使用的 App，
//  且免費方案不得服務歐洲經濟區、瑞士與英國的使用者。
//

import UIKit

/// 生圖風格預設 — 讓 AI「第一次就生出理想構圖」，而非普通排列。
enum PackingImageStyle: String, CaseIterable, Identifiable {
    case softStudio
    case travelMag
    case darkMoody

    var id: String { rawValue }

    var label: String {
        switch self {
        case .softStudio: "柔光棚拍"
        case .travelMag: "旅行雜誌"
        case .darkMoody: "深色質感"
        }
    }

    var basePrompt: String {
        switch self {
        case .softStudio:
            return "A clean top-down flat-lay product photograph with soft diffused studio lighting, gentle pastel palette, subtle soft shadows, on a light neutral background."
        case .travelMag:
            return "A stylish top-down travel flat-lay in the style of a premium travel magazine spread, warm natural window light, a curated cohesive color story, tasteful props, editorial composition."
        case .darkMoody:
            return "A cinematic top-down flat-lay with dramatic moody lighting on a dark slate background, rich shadows and a single soft key light, refined premium look."
        }
    }
}

enum PackingImageService {
    /// 依目的地與清單分類匯總，組出「理想構圖」flat-lay prompt（代表性，非逐件庫存）。
    static func makePrompt(for trip: Trip, style: PackingImageStyle) -> String {
        let country = StaticDataStore.shared.country(code: trip.countryCode)
        let place = "\(country?.nameZh ?? trip.countryCode)\(trip.city.isEmpty ? "" : "・\(trip.city)")"

        let items = (trip.packingItems ?? []).sorted { $0.sortIndex < $1.sortIndex }
        var byCategory: [PackingCategory: [String]] = [:]
        for item in items {
            byCategory[item.category, default: []].append(item.name)
        }
        let summary = PackingCategory.allCases.compactMap { category -> String? in
            guard let names = byCategory[category], !names.isEmpty else { return nil }
            return "\(category.label)：\(names.prefix(6).joined(separator: "、"))"
        }.joined(separator: "；")

        return """
        \(style.basePrompt) The scene shows travel items neatly arranged and ready to pack \
        for a \(trip.totalDays)-day trip to \(place). Representative items (not a literal inventory): \(summary). \
        Balanced overhead composition with clear negative space, every item fully visible and non-overlapping, \
        magazine-quality styling, cozy East-Asia travel mood. \
        Absolutely no text, words, letters, or labels anywhere in the image.
        """
    }
}
