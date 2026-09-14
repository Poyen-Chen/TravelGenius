//
//  ReferenceDataUpdater.swift
//  TravelGenius
//
//  參考資料熱更新：遠端優先、Bundle 保底。
//   ・啟動時在背景對 CDN 送出帶 If-None-Match 的條件請求，304 代表沒變、不下載。
//   ・下載的新檔必須能被這個 App 版本解碼，並通過基本健全檢查，才寫進暫存區。
//   ・下次啟動時暫存區整批升級成正式快取，使用中的資料不會中途變動。
//   ・StaticDataStore 優先讀正式快取；快取不存在、壞掉或屬於其他 App 版本時讀 Bundle。
//  資料在 main 通過 CI 品質閘門後，經 jsDelivr 發布，改資料不需送審。
//

import Foundation

enum ReferenceDataUpdater {
    enum Outcome: String {
        case updated
        case notModified
        case rejected
        case failed
    }

    /// 發布端點：jsDelivr 代理 GitHub main 分支。邊緣快取 12 小時，CI 合併後會主動清除。
    static let defaultBaseURL = URL(string: "https://cdn.jsdelivr.net/gh/Poyen-Chen/TravelGenius@main/TravelGenius/Resources/SeedData/")!

    /// 會熱更新的檔案，與 StaticDataStore 載入的檔名一致
    static let files = ["countries", "cities", "packing_rules", "prohibited_items", "aviation_rules", "etiquette"]

    /// 開發測試用引數：
    ///   `-referenceDataBaseURL <url>` 改用其他端點（例如本機測試伺服器）
    ///   `-disableReferenceDataUpdate` 停用下載
    static var baseURL: URL? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-disableReferenceDataUpdate") { return nil }
        if let index = arguments.firstIndex(of: "-referenceDataBaseURL"), index + 1 < arguments.count {
            return URL(string: arguments[index + 1])
        }
        return defaultBaseURL
    }

    // MARK: - 快取位置（依 App 版本隔離，App 更新後自動改用新 Bundle）

    private static var appBuildID: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version)-\(build)"
    }

    private static var rootDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReferenceData", isDirectory: true)
    }

    private static var activeDirectory: URL {
        rootDirectory.appendingPathComponent(appBuildID, isDirectory: true).appendingPathComponent("active", isDirectory: true)
    }

    private static var stagedDirectory: URL {
        rootDirectory.appendingPathComponent(appBuildID, isDirectory: true).appendingPathComponent("staged", isDirectory: true)
    }

    /// 正式快取中的檔案內容；StaticDataStore 讀取時使用
    static func cachedData(for name: String) -> Data? {
        try? Data(contentsOf: activeDirectory.appendingPathComponent("\(name).json"))
    }

    // MARK: - 啟動時升級暫存區

    /// 必須在任何程式讀取 StaticDataStore 之前呼叫
    static func promoteStagedUpdates() {
        let fileManager = FileManager.default
        removeOtherBuilds()
        guard fileManager.fileExists(atPath: stagedDirectory.path) else { return }
        try? fileManager.createDirectory(at: activeDirectory, withIntermediateDirectories: true)
        for name in files {
            let stagedJSON = stagedDirectory.appendingPathComponent("\(name).json")
            guard fileManager.fileExists(atPath: stagedJSON.path) else { continue }
            let activeJSON = activeDirectory.appendingPathComponent("\(name).json")
            let stagedETag = stagedDirectory.appendingPathComponent("\(name).etag")
            let activeETag = activeDirectory.appendingPathComponent("\(name).etag")
            try? fileManager.removeItem(at: activeJSON)
            try? fileManager.removeItem(at: activeETag)
            try? fileManager.moveItem(at: stagedJSON, to: activeJSON)
            if fileManager.fileExists(atPath: stagedETag.path) {
                try? fileManager.moveItem(at: stagedETag, to: activeETag)
            }
        }
        try? fileManager.removeItem(at: stagedDirectory)
    }

    private static func removeOtherBuilds() {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(at: rootDirectory, includingPropertiesForKeys: nil) else { return }
        for entry in entries where entry.lastPathComponent != appBuildID {
            try? fileManager.removeItem(at: entry)
        }
    }

    // MARK: - 背景下載

    @discardableResult
    static func refresh(session: URLSession = .shared) async -> [String: Outcome] {
        guard let baseURL else { return [:] }
        var root = rootDirectory
        try? FileManager.default.createDirectory(at: stagedDirectory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? root.setResourceValues(values)

        var outcomes: [String: Outcome] = [:]
        for name in files {
            outcomes[name] = await refresh(name, baseURL: baseURL, session: session)
        }
        return outcomes
    }

    private static func refresh(_ name: String, baseURL: URL, session: URLSession) async -> Outcome {
        var request = URLRequest(url: baseURL.appendingPathComponent("\(name).json"))
        // jsDelivr 回應 max-age 7 天；不用系統快取，才能靠 ETag 即時知道有沒有更新
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        if let etag = currentETag(for: name) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed }
            if http.statusCode == 304 { return .notModified }
            guard http.statusCode == 200 else { return .failed }
            guard validate(name, data: data) else { return .rejected }

            let json = stagedDirectory.appendingPathComponent("\(name).json")
            let etagFile = stagedDirectory.appendingPathComponent("\(name).etag")
            try data.write(to: json, options: .atomic)
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                try etag.write(to: etagFile, atomically: true, encoding: .utf8)
            } else {
                try? FileManager.default.removeItem(at: etagFile)
            }
            return .updated
        } catch {
            return .failed
        }
    }

    /// 暫存區較新就用暫存區的 ETag；只有對應的 JSON 還在時才送出
    private static func currentETag(for name: String) -> String? {
        for directory in [stagedDirectory, activeDirectory] {
            let json = directory.appendingPathComponent("\(name).json")
            let etag = directory.appendingPathComponent("\(name).etag")
            if FileManager.default.fileExists(atPath: json.path),
               let value = try? String(contentsOf: etag, encoding: .utf8) {
                return value
            }
        }
        return nil
    }

    // MARK: - 驗證

    /// 下載的檔案必須能被這個 App 版本解碼、不是空的；countries 還必須包含聚焦國家
    static func validate(_ name: String, data: Data) -> Bool {
        switch name {
        case "countries":
            guard let countries = decodeNonEmpty([Country].self, from: data) else { return false }
            return Set(StaticDataStore.focusCountryCodes).isSubset(of: Set(countries.map(\.code)))
        case "cities":
            return decodeNonEmpty([City].self, from: data) != nil
        case "packing_rules":
            return decodeNonEmpty([PackingRule].self, from: data) != nil
        case "prohibited_items":
            return decodeNonEmpty([ProhibitedItem].self, from: data) != nil
        case "aviation_rules":
            return decodeNonEmpty([AviationRule].self, from: data) != nil
        case "etiquette":
            return decodeNonEmpty([EtiquetteCard].self, from: data) != nil
        default:
            return false
        }
    }

    private static func decodeNonEmpty<T: Decodable>(_ type: [T].Type, from data: Data) -> [T]? {
        guard let items = try? JSONDecoder().decode(type, from: data), !items.isEmpty else { return nil }
        return items
    }
}
