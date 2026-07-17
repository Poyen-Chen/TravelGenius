//
//  MascotMessenger.swift
//  TravelGenius
//
//  小史萊姆的情境訊息：依距出發天數、打包進度與天氣挑一句話（D-day 行前提醒）。
//

import Foundation

enum MascotMessenger {
    static func message(
        for trip: Trip,
        unpackedCount: Int,
        weather: WeatherSummary?,
        now: Date = .now
    ) -> (text: String, expression: MascotExpression) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: trip.startDate)
        let end = calendar.startOfDay(for: trip.endDate)
        let daysToStart = calendar.dateComponents([.day], from: today, to: start).day ?? 0

        if today > end {
            return ("旅程結束啦！下次出發前記得再來找我 🐾", .happy)
        }
        if today == end {
            return ("今天回家！開「回程模式」逐項檢查，別把東西留在住宿處", .alert)
        }
        if today >= start {
            return ("旅途愉快！買了什麼不確定能不能帶回家，到 Tips 問我「這個能帶嗎」", .happy)
        }
        if daysToStart == 0 {
            return ("今天出發！護照、行動電源、登機證，最後掃一眼", .alert)
        }
        if unpackedCount == 0 {
            return ("全部打包完成，太可靠了！出發前想到什麼隨時回來加", .happy)
        }
        if daysToStart == 1 {
            return ("明天就出發！行動電源充飽了嗎？睡前開「前一晚模式」掃一遍", .alert)
        }
        if daysToStart <= 3 {
            if let weather, weather.rainDays > 0 {
                return ("查了\(weather.cityZh)天氣：\(weather.headline)。傘我加進清單了，記得帶", .alert)
            }
            return ("還剩 \(unpackedCount) 項沒打包，這幾天分批收，別留到最後一晚", .normal)
        }
        if daysToStart <= 7 {
            return ("D-\(daysToStart)！轉接頭、藥品這種要買的先買起來", .normal)
        }
        return ("距離出發還有 \(daysToStart) 天，先把清單看一遍，心裡有底", .normal)
    }
}
