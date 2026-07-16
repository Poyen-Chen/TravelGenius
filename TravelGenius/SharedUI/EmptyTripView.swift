//
//  EmptyTripView.swift
//  TravelGenius
//

import SwiftUI

struct EmptyTripView: View {
    var onCreate: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("尚無行程", systemImage: "airplane")
        } description: {
            Text("建立第一個行程，開始追蹤旅費。")
        } actions: {
            Button("建立行程", action: onCreate)
                .buttonStyle(.borderedProminent)
        }
    }
}
