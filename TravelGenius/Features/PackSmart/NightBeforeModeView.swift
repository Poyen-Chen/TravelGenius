//
//  NightBeforeModeView.swift
//  TravelGenius
//
//  前一晚模式：只列未打包項目、大字呈現，睡前快速掃一遍。
//  回程模式：同一份清單反向使用，收行李時逐項確認，避免把東西留在住宿處。
//

import SwiftUI
import SwiftData

struct NightBeforeModeView: View {
    enum Mode {
        case nightBefore
        case returnTrip

        var title: String {
            switch self {
            case .nightBefore: "前一晚模式"
            case .returnTrip: "回程模式"
            }
        }

        func remainingHeader(_ count: Int) -> String {
            switch self {
            case .nightBefore: "還剩 \(count) 項未打包"
            case .returnTrip: "還剩 \(count) 項未收回"
            }
        }

        var doneTitle: String {
            switch self {
            case .nightBefore: "打包完成！"
            case .returnTrip: "行李收齊！"
            }
        }

        var doneSubtitle: String {
            switch self {
            case .nightBefore: "行李都準備好了，安心出發。"
            case .returnTrip: "沒有東西留在住宿處，安心回家。"
            }
        }
    }

    let trip: Trip
    var mode: Mode = .nightBefore

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
                            Text(mode.remainingHeader(unpacked.count))
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
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
            Text(mode.doneTitle)
                .font(.largeTitle.weight(.bold))
            Text(mode.doneSubtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
