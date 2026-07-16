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
            Text("建立第一個行程，拿到專屬打包清單與當地 Tips。")
        } actions: {
            Button("建立行程", action: onCreate)
                .buttonStyle(.borderedProminent)
        }
    }
}
