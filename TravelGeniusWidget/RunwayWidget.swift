//
//  RunwayWidget.swift
//  TravelGeniusWidgetExtension
//
//  跑道小工具：主畫面一眼看到「還能撐幾天」。
//  資料由主 App 寫入 App Group 共享儲存（見 WidgetSync.swift），欄位需保持一致。
//

import WidgetKit
import SwiftUI

// MARK: - 共享快照（與主 App 的 WidgetSync.Snapshot 對應）

struct RunwaySnapshot: Codable {
    var tripName: String
    var runwayDays: Double?
    var burnRatePerDay: Double
    var remainingTripDays: Int
    var statusRaw: String
    var todaySpent: Double
    var todayCap: Double
    var currencyCode: String
    var packedCount: Int
    var packingTotal: Int
    var updatedAt: Date

    static let appGroupID = "group.com.example.TravelGenius"
    static let defaultsKey = "runwaySnapshot"

    static func load() -> RunwaySnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(RunwaySnapshot.self, from: data)
    }

    static let preview = RunwaySnapshot(
        tripName: "東京五日遊",
        runwayDays: 6.2,
        burnRatePerDay: 5480,
        remainingTripDays: 5,
        statusRaw: "safe",
        todaySpent: 1832,
        todayCap: 6000,
        currencyCode: "TWD",
        packedCount: 11,
        packingTotal: 16,
        updatedAt: .now
    )

    var statusColor: Color {
        switch statusRaw {
        case "safe": .green
        case "caution": .orange
        default: .red
        }
    }

    var statusLabel: String {
        switch statusRaw {
        case "safe": "安全"
        case "caution": "注意"
        default: "超支"
        }
    }
}

// MARK: - Timeline

struct RunwayEntry: TimelineEntry {
    let date: Date
    let snapshot: RunwaySnapshot?
}

struct RunwayProvider: TimelineProvider {
    func placeholder(in context: Context) -> RunwayEntry {
        RunwayEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (RunwayEntry) -> Void) {
        let snapshot = context.isPreview ? (RunwaySnapshot.load() ?? .preview) : RunwaySnapshot.load()
        completion(RunwayEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RunwayEntry>) -> Void) {
        let entry = RunwayEntry(date: .now, snapshot: RunwaySnapshot.load())
        // 快照由 App 寫入且「今日」數字凍結於寫入當下；
        // 午夜後重新產生 entry，讓 view 依 updatedAt 判定過期並改顯示提示
        let calendar = Calendar.current
        let nextMidnight = calendar.startOfDay(for: .now).addingTimeInterval(24 * 3600 + 60)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

// MARK: - Views

struct RunwayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RunwayEntry

    /// 快照寫入日 ≠ 顯示日：「今日」相關數字已過期，不能再當今天的呈現
    private var isStale: Bool {
        guard let snapshot = entry.snapshot else { return false }
        return !Calendar.current.isDate(snapshot.updatedAt, inSameDayAs: entry.date)
    }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .systemMedium:
                    mediumView(snapshot)
                default:
                    smallView(snapshot)
                }
            } else {
                emptyView
            }
        }
        .containerBackground(.background, for: .widget)
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "airplane")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("開啟 TravelGenius\n建立行程開始記帳")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private func runwayNumber(_ snapshot: RunwaySnapshot, size: CGFloat) -> some View {
        Group {
            if let runway = snapshot.runwayDays {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(runway, format: .number.precision(.fractionLength(1)))
                        .font(.system(size: size, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("天")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            } else {
                Text("尚無支出")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func smallView(_ snapshot: RunwaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("還能撐")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Circle()
                    .fill(snapshot.statusColor)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("預算狀態：\(snapshot.statusLabel)")
            }
            Spacer(minLength: 0)
            runwayNumber(snapshot, size: 34)
            Spacer(minLength: 0)
            if isStale {
                Text("更新於 \(snapshot.updatedAt.formatted(.dateTime.month().day()))・開啟 App 更新")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "flame")
                    Text(Decimal(snapshot.burnRatePerDay), format: .currency(code: snapshot.currencyCode).precision(.fractionLength(0)))
                        .monospacedDigit()
                    Text("／天")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func mediumView(_ snapshot: RunwaySnapshot) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("還能撐")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(snapshot.statusColor)
                        .frame(width: 8, height: 8)
                    Text(snapshot.statusLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(snapshot.statusColor)
                }
                runwayNumber(snapshot, size: 32)
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    Image(systemName: "flame")
                    Text(Decimal(snapshot.burnRatePerDay), format: .currency(code: snapshot.currencyCode).precision(.fractionLength(0)))
                        .monospacedDigit()
                    Text("／天")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.tripName)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)

                if isStale {
                    Label("開啟 App 更新今日數字", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    let capRatio = snapshot.todayCap > 0 ? snapshot.todaySpent / snapshot.todayCap : 0
                    ProgressView(value: min(snapshot.todaySpent, snapshot.todayCap), total: max(snapshot.todayCap, 1))
                        .tint(capRatio >= 1 ? .red : capRatio >= 0.8 ? .orange : .green)
                    HStack(spacing: 3) {
                        Text("今日")
                        Text(Decimal(snapshot.todaySpent), format: .currency(code: snapshot.currencyCode).precision(.fractionLength(0)))
                            .monospacedDigit()
                        Text("／上限")
                        Text(Decimal(snapshot.todayCap), format: .currency(code: snapshot.currencyCode).precision(.fractionLength(0)))
                            .monospacedDigit()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }

                if snapshot.packingTotal > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "suitcase")
                        Text("行李 \(snapshot.packedCount)/\(snapshot.packingTotal)")
                            .monospacedDigit()
                        if snapshot.packedCount == snapshot.packingTotal {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Widget

struct RunwayWidget: Widget {
    let kind = "RunwayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RunwayProvider()) { entry in
            RunwayWidgetView(entry: entry)
        }
        .configurationDisplayName("旅費跑道")
        .description("一眼看到旅費還能撐幾天，以及今日建議上限。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
