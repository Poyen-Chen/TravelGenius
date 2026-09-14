//
//  PrivacyPolicyView.swift
//  TravelGenius
//
//  App 內隱私權政策。App Store 審查指南 5.1.1(i) 要求 App 內可輕易取得。
//  內容來自 Resources/Legal/PrivacyPolicy.md，對外公開的網頁版也用同一份文字。
//

import SwiftUI

struct PrivacyPolicyView: View {
    private let blocks = PolicyDocument.load()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("隱私權政策")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func blockView(_ block: PolicyDocument.Block) -> some View {
        switch block {
        case .title(let text):
            Text(text).font(.title2.bold())
        case .heading(let text):
            Text(text).font(.headline).padding(.top, 8)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                Text(PolicyDocument.inline(text))
            }
            .font(.subheadline)
        case .paragraph(let text):
            Text(PolicyDocument.inline(text)).font(.subheadline)
        }
    }
}

/// 極簡 Markdown 解析：# 標題、## 小節、- 條列、其餘為段落；段落內支援粗體與連結。
enum PolicyDocument {
    enum Block {
        case title(String)
        case heading(String)
        case bullet(String)
        case paragraph(String)
    }

    static func load(resource: String = "PrivacyPolicy") -> [Block] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return [.paragraph("無法載入隱私權政策，請稍後再試。")]
        }
        return parse(text)
    }

    static func parse(_ text: String) -> [Block] {
        text.split(separator: "\n").compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("<!--") { return nil }
            if line.hasPrefix("## ") { return .heading(String(line.dropFirst(3))) }
            if line.hasPrefix("# ") { return .title(String(line.dropFirst(2))) }
            if line.hasPrefix("- ") { return .bullet(String(line.dropFirst(2))) }
            return .paragraph(line)
        }
    }

    static func inline(_ markdown: String) -> AttributedString {
        (try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(markdown)
    }
}
