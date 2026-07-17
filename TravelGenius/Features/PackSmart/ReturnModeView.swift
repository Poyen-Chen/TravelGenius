//
//  ReturnModeView.swift
//  TravelGenius
//
//  回程模式：同一份清單反向使用，收行李時逐項確認，避免把東西留在住宿處。
//  大字呈現、只列未收回項目。
//

import SwiftUI
import SwiftData

struct ReturnModeView: View {
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @State private var packToggle = false

    private var unpacked: [PackingItem] {
        (trip.packingItems ?? [])
            .filter { !$0.isPacked }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        NavigationStack {
            Group {
                if unpacked.isEmpty {
                    allDone
                } else {
                    List {
                        Section {
                            ForEach(unpacked) { item in
                                Button {
                                    item.isPacked = true
                                    packToggle.toggle()
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "circle")
                                            .font(.title)
                                            .foregroundStyle(.secondary)
                                        Text(item.name)
                                            .font(.title2.weight(.medium))
                                        if item.quantity > 1 {
                                            Text("×\(item.quantity)")
                                                .font(.title3)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text("還剩 \(unpacked.count) 項未收回")
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("回程模式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .sensoryFeedback(.impact, trigger: packToggle)
        .sensoryFeedback(.success, trigger: unpacked.isEmpty)
    }

    private var allDone: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            Text("行李收齊！")
                .font(.largeTitle.weight(.bold))
            Text("沒有東西留在住宿處，安心回家。")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
