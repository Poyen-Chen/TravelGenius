//
//  ReportExporter.swift
//  TravelGenius
//

import Foundation
import UIKit

/// 產出報帳文件：CSV 供財務系統匯入、PDF 供簽核（可含收據附檔頁）
enum ReportExporter {
    // MARK: - CSV

    static func exportCSV(trip: Trip, expenses: [Expense]) throws -> URL {
        var lines = ["日期,時間,類別,註記,金額,幣別,匯率,折算本幣(\(trip.homeCurrencyCode)),需報帳,收據"]
        let dateFormatter = Date.FormatStyle(date: .numeric, time: .omitted)
        let timeFormatter = Date.FormatStyle(date: .omitted, time: .shortened)
        for expense in expenses {
            let fields = [
                expense.date.formatted(dateFormatter),
                expense.date.formatted(timeFormatter),
                expense.category.label,
                expense.note,
                "\(NSDecimalNumber(decimal: expense.amount))",
                expense.currencyCode,
                "\(NSDecimalNumber(decimal: expense.rateToHome))",
                String(format: "%.2f", expense.amountInHome.doubleValue),
                expense.isReimbursable ? "是" : "否",
                expense.receiptImageData != nil ? "有" : "無",
            ]
            lines.append(fields.map(escapeCSV).joined(separator: ","))
        }
        // UTF-8 BOM：讓 Excel 正確辨識中文
        let content = "\u{FEFF}" + lines.joined(separator: "\r\n")
        let url = temporaryURL(tripName: trip.name, ext: "csv")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }

    // MARK: - PDF

    static func exportPDF(trip: Trip, expenses: [Expense], includeReceipts: Bool) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72dpi
        let margin: CGFloat = 40
        let contentWidth = pageRect.width - margin * 2
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let sectionFont = UIFont.boldSystemFont(ofSize: 12)
        let bodyFont = UIFont.systemFont(ofSize: 10)
        let secondaryColor = UIColor.darkGray

        let total = expenses.reduce(Decimal(0)) { $0 + $1.amountInHome }
        let totalText = total.formatted(.currency(code: trip.homeCurrencyCode).precision(.fractionLength(0...2)))
        let period = "\(trip.startDate.formatted(date: .numeric, time: .omitted)) – \(trip.endDate.formatted(date: .numeric, time: .omitted))"

        // 欄位：日期 75、類別 55、註記 180、金額 105、折算 100
        let columns: [(title: String, width: CGFloat, alignment: NSTextAlignment)] = [
            ("日期", 75, .left),
            ("類別", 55, .left),
            ("註記", 180, .left),
            ("金額", 105, .right),
            ("折算 \(trip.homeCurrencyCode)", 100, .right),
        ]

        func rowValues(_ expense: Expense) -> [String] {
            [
                expense.date.formatted(date: .numeric, time: .omitted),
                expense.category.label,
                expense.note.isEmpty ? "—" : expense.note,
                "\(expense.currencyCode) \(NSDecimalNumber(decimal: expense.amount))",
                String(format: "%.0f", expense.amountInHome.doubleValue),
            ]
        }

        func draw(_ text: String, font: UIFont, color: UIColor = .black, at rect: CGRect, alignment: NSTextAlignment = .left) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = alignment
            paragraph.lineBreakMode = .byTruncatingTail
            (text as NSString).draw(
                in: rect,
                withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
            )
        }

        func drawTableHeader(y: CGFloat) -> CGFloat {
            var x = margin
            for column in columns {
                draw(column.title, font: sectionFont, at: CGRect(x: x, y: y, width: column.width, height: 16), alignment: column.alignment)
                x += column.width
            }
            let context = UIGraphicsGetCurrentContext()
            context?.setStrokeColor(UIColor.lightGray.cgColor)
            context?.setLineWidth(0.5)
            context?.move(to: CGPoint(x: margin, y: y + 18))
            context?.addLine(to: CGPoint(x: pageRect.width - margin, y: y + 18))
            context?.strokePath()
            return y + 24
        }

        let url = temporaryURL(tripName: trip.name, ext: "pdf")
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            var y = margin

            // 標題與摘要
            draw("\(trip.name)・報帳報告", font: titleFont, at: CGRect(x: margin, y: y, width: contentWidth, height: 26))
            y += 32
            let country = StaticDataStore.shared.country(code: trip.countryCode)
            let summaryLines = [
                "目的地：\(country?.nameZh ?? trip.countryCode)　期間：\(period)（\(trip.totalDays) 天）",
                "筆數：\(expenses.count)　總金額：\(totalText)",
                "產出日期：\(Date.now.formatted(date: .numeric, time: .shortened))",
            ]
            for line in summaryLines {
                draw(line, font: bodyFont, color: secondaryColor, at: CGRect(x: margin, y: y, width: contentWidth, height: 14))
                y += 16
            }
            y += 8
            y = drawTableHeader(y: y)

            let rowHeight: CGFloat = 17
            for expense in expenses {
                if y + rowHeight > pageRect.height - margin {
                    context.beginPage()
                    y = margin
                    y = drawTableHeader(y: y)
                }
                var x = margin
                let values = rowValues(expense)
                for (index, column) in columns.enumerated() {
                    draw(values[index], font: bodyFont, at: CGRect(x: x, y: y, width: column.width - 6, height: rowHeight), alignment: column.alignment)
                    x += column.width
                }
                y += rowHeight
            }

            // 收據附檔頁
            guard includeReceipts else { return }
            let withReceipts = expenses.filter { $0.receiptImageData != nil }
            for (index, expense) in withReceipts.enumerated() {
                guard let data = expense.receiptImageData, let image = UIImage(data: data) else { continue }
                context.beginPage()
                let caption = "收據 \(index + 1)／\(withReceipts.count)　\(expense.date.formatted(date: .numeric, time: .omitted))　\(expense.category.label)　\(expense.currencyCode) \(NSDecimalNumber(decimal: expense.amount))\(expense.note.isEmpty ? "" : "　\(expense.note)")"
                draw(caption, font: bodyFont, color: secondaryColor, at: CGRect(x: margin, y: margin, width: contentWidth, height: 14))

                let available = CGRect(x: margin, y: margin + 24, width: contentWidth, height: pageRect.height - margin * 2 - 24)
                let scale = min(available.width / image.size.width, available.height / image.size.height, 1)
                let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let origin = CGPoint(
                    x: available.midX - drawSize.width / 2,
                    y: available.minY
                )
                image.draw(in: CGRect(origin: origin, size: drawSize))
            }
        }
        return url
    }

    // MARK: - 檔案

    private static func temporaryURL(tripName: String, ext: String) -> URL {
        let safeName = tripName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let name = safeName.isEmpty ? "報帳" : safeName
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-報帳")
            .appendingPathExtension(ext)
    }
}
