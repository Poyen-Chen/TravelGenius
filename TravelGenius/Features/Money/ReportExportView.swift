//
//  ReportExportView.swift
//  TravelGenius
//

import SwiftUI

struct ReportExportView: View {
    let trip: Trip

    @State private var reimbursableOnly: Bool
    @State private var includeReceipts = true
    @State private var csvURL: URL?
    @State private var pdfURL: URL?
    @State private var exportFailed = false

    init(trip: Trip) {
        self.trip = trip
        _reimbursableOnly = State(initialValue: trip.tripType == .business)
    }

    /// 匯出內容：依日期由舊到新
    private var selected: [Expense] {
        (trip.expenses ?? [])
            .filter { !reimbursableOnly || $0.isReimbursable }
            .sorted { $0.date < $1.date }
    }

    private var receiptCount: Int {
        selected.filter { $0.receiptImageData != nil }.count
    }

    private var total: Decimal {
        selected.reduce(0) { $0 + $1.amountInHome }
    }

    var body: some View {
        Form {
            Section("內容") {
                Toggle("僅含報帳項目", isOn: $reimbursableOnly)
                Toggle("PDF 含收據附檔", isOn: $includeReceipts)
            }

            Section("摘要") {
                LabeledContent("筆數") { Text("\(selected.count) 筆") }
                LabeledContent("總金額") {
                    MoneyText(amount: total, currencyCode: trip.homeCurrencyCode)
                }
                LabeledContent("收據") { Text("\(receiptCount) 張") }
            }

            Section {
                Button {
                    generate()
                } label: {
                    Label("產出報告", systemImage: "doc.badge.gearshape")
                }
                .disabled(selected.isEmpty)

                if let csvURL {
                    ShareLink(item: csvURL) {
                        Label("分享 CSV", systemImage: "tablecells")
                    }
                }
                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Label("分享 PDF", systemImage: "doc.richtext")
                    }
                }
            } footer: {
                Text("CSV 供財務系統匯入；PDF 供簽核，收據照片依日期排入附檔頁。")
            }
        }
        .navigationTitle("匯出報帳")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if selected.isEmpty {
                ContentUnavailableView(
                    reimbursableOnly ? "沒有報帳項目" : "尚無支出",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(reimbursableOnly ? "記帳時開啟「需報帳」，或關閉上方篩選。" : "先記幾筆支出再來匯出。")
                )
                .background(Color(.systemGroupedBackground))
            }
        }
        .onChange(of: reimbursableOnly) { resetOutputs() }
        .onChange(of: includeReceipts) { resetOutputs() }
        .alert("產出失敗，請再試一次。", isPresented: $exportFailed) {
            Button("好", role: .cancel) {}
        }
    }

    private func resetOutputs() {
        csvURL = nil
        pdfURL = nil
    }

    private func generate() {
        do {
            csvURL = try ReportExporter.exportCSV(trip: trip, expenses: selected)
            pdfURL = try ReportExporter.exportPDF(trip: trip, expenses: selected, includeReceipts: includeReceipts)
        } catch {
            resetOutputs()
            exportFailed = true
        }
    }
}
