//
//  OnDeviceImageService.swift
//  TravelGenius
//
//  裝置端開源生圖：以 Apple ml-stable-diffusion（Core ML）在本機跑 Stable Diffusion。
//  開源、免金鑰、免費、離線 —— 但需實機（有 Neural Engine）＋約 1GB 模型檔，模擬器跑不動。
//
//  使用前提（見專案 README 或本檔尾說明）：
//    1. Xcode 加入 Swift Package: https://github.com/apple/ml-stable-diffusion（產品 StableDiffusion）
//    2. 下載 Apple 轉好的輕量模型（建議 SD 2.1-base 6-bit palettized, split_einsum），
//       把整個模型資料夾命名為 "StableDiffusionModel"，加入 App bundle（藍色 folder reference），
//       或推到裝置的 Documents/StableDiffusionModel。
//  套件未加入時，本檔會編譯成回傳 nil 的空殼，UI 自動退回原生排版卡 —— build 不受影響。
//

import UIKit

#if canImport(StableDiffusion)

import StableDiffusion
import CoreML

/// actor 序列化生成並快取 pipeline，避免同時載入 ~1GB 模型造成記憶體爆掉。
actor OnDeviceImageService {
    static let shared = OnDeviceImageService()

    private var pipeline: StableDiffusionPipeline?

    /// 是否已就緒（模型資料夾存在）；供 UI 判斷要不要嘗試裝置端路徑。
    static var isAvailable: Bool { modelResourcesURL() != nil }

    func image(forPrompt prompt: String) async -> UIImage? {
        guard let url = Self.modelResourcesURL() else { return nil }
        do {
            let pipeline = try loadPipeline(at: url)
            var config = StableDiffusionPipeline.Configuration(prompt: prompt)
            config.negativePrompt = "text, words, letters, watermark, low quality, blurry"
            config.stepCount = 20
            config.imageCount = 1
            config.guidanceScale = 7.5
            config.seed = UInt32.random(in: 0...UInt32.max)
            let images = try pipeline.generateImages(configuration: config) { _ in true }
            guard let cgImage = images.compactMap({ $0 }).first else { return nil }
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    private func loadPipeline(at url: URL) throws -> StableDiffusionPipeline {
        if let pipeline { return pipeline }
        let config = MLModelConfiguration()
        // split_einsum 模型走 ANE；若下載的是 original 版，改成 .cpuAndGPU
        config.computeUnits = .cpuAndNeuralEngine
        let created = try StableDiffusionPipeline(
            resourcesAt: url,
            controlNet: [],
            configuration: config,
            disableSafety: true,
            reduceMemory: true
        )
        try created.loadResources()
        pipeline = created
        return created
    }

    /// 模型資料夾：先找 App bundle，再找 Documents。
    private static func modelResourcesURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "StableDiffusionModel", withExtension: nil) {
            return bundled
        }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if let candidate = documents?.appendingPathComponent("StableDiffusionModel"),
           FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        return nil
    }
}

#else

/// StableDiffusion 套件尚未加入：空殼，回 nil，讓 UI 退回其他路徑（build 保持綠燈）。
actor OnDeviceImageService {
    static let shared = OnDeviceImageService()
    static var isAvailable: Bool { false }
    func image(forPrompt prompt: String) async -> UIImage? { nil }
}

#endif
