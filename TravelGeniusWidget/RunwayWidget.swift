//
//  RunwayWidget.swift
//  TravelGeniusWidgetExtension
//
//  出發倒數小工具：D-n 大字＋打包進度。
//  資料由主 App 寫入 App Group（見 WidgetSync.swift），倒數以日期即時計算。
//

import WidgetKit
import SwiftUI

// MARK: - 共享快照（與主 App 的 WidgetSync.Snapshot 對應）

struct DepartureSnapshot: Codable {
    var tripName: String
    var startDate: Date
    var endDate: Date
    var packedCount: Int
    var packingTotal: Int
    var updatedAt: Date

    static let appGroupID = "group.com.example.TravelGenius"
    static let defaultsKey = "departureSnapshot"

    static func load() -> DepartureSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(DepartureSnapshot.self, from: data)
    }

    static var preview: DepartureSnapshot {
        DepartureSnapshot(
            tripName: "東京 5 天",
            startDate: Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now,
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
            packedCount: 11,
            packingTotal: 16,
            updatedAt: .now
        )
    }

    enum Phase {
        case before(days: Int)
        case departure
        case during
        case returnDay
        case after
    }

    func phase(on date: Date) -> Phase {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        if today > end { return .after }
        if today == end { return .returnDay }
        if today >= start { return today == start ? .departure : .during }
        let days = calendar.dateComponents([.day], from: today, to: start).day ?? 0
        return days == 0 ? .departure : .before(days: days)
    }
}

// MARK: - Timeline

struct DepartureEntry: TimelineEntry {
    let date: Date
    let snapshot: DepartureSnapshot?
}

struct DepartureProvider: TimelineProvider {
    func placeholder(in context: Context) -> DepartureEntry {
        DepartureEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (DepartureEntry) -> Void) {
        let snapshot = context.isPreview ? (DepartureSnapshot.load() ?? .preview) : DepartureSnapshot.load()
        completion(DepartureEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DepartureEntry>) -> Void) {
        let entry = DepartureEntry(date: .now, snapshot: DepartureSnapshot.load())
        // 倒數由日期即時計算，午夜刷新即自動翻頁
        let calendar = Calendar.current
        let nextMidnight = calendar.startOfDay(for: .now).addingTimeInterval(24 * 3600 + 60)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

// MARK: - Views

struct DepartureWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DepartureEntry

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
            Image(systemName: "pawprint.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("開啟 TravelGenius\n建立行程開始倒數")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private func headline(_ snapshot: DepartureSnapshot) -> (big: String, label: String) {
        switch snapshot.phase(on: entry.date) {
        case .before(let days): ("D-\(days)", "出發倒數")
        case .departure: ("今天", "出發日")
        case .during: ("旅途中", "玩得開心")
        case .returnDay: ("回家日", "別留東西")
        case .after: ("已結束", "下次再出發")
        }
    }

    private func packingLine(_ snapshot: DepartureSnapshot) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "suitcase")
            Text("\(snapshot.packedCount)/\(snapshot.packingTotal)")
                .monospacedDigit()
            if snapshot.packingTotal > 0 && snapshot.packedCount == snapshot.packingTotal {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func smallView(_ snapshot: DepartureSnapshot) -> some View {
        let head = headline(snapshot)
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(head.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "pawprint.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer(minLength: 0)
            Text(head.big)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(snapshot.tripName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            packingLine(snapshot)
        }
    }

    private func mediumView(_ snapshot: DepartureSnapshot) -> some View {
        let head = headline(snapshot)
        let progress = snapshot.packingTotal > 0
            ? Double(snapshot.packedCount) / Double(snapshot.packingTotal) : 0
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(head.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "pawprint.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(head.big)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(snapshot.tripName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("打包進度")
                    .font(.footnote.weight(.semibold))
                ProgressView(value: progress)
                    .tint(progress >= 1 ? .green : .blue)
                packingLine(snapshot)
                Spacer(minLength: 0)
                Text("\(snapshot.startDate.formatted(.dateTime.month().day())) – \(snapshot.endDate.formatted(.dateTime.month().day()))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Widget

struct RunwayWidget: Widget {
    let kind = "DepartureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DepartureProvider()) { entry in
            DepartureWidgetView(entry: entry)
        }
        .configurationDisplayName("出發倒數")
        .description("還有幾天出發、行李打包進度，一眼看到。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
