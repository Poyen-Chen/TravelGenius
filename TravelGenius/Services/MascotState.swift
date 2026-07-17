//
//  MascotState.swift
//  TravelGenius
//
//  浮動小史萊姆的共享狀態：各畫面（情境提醒、能帶嗎查詢）把訊息寫進來，
//  右緣浮動 dock 讀取顯示。
//

import Foundation
import Observation

@Observable
final class MascotState {
    var message: String = "嗨！我是小史萊姆 🐾"
    var expression: MascotExpression = .normal
    var isExpanded: Bool = true

    /// 更新訊息並自動展開（有新話要說時跳出來）
    func speak(_ message: String, expression: MascotExpression = .normal) {
        self.message = message
        self.expression = expression
        isExpanded = true
    }
}
