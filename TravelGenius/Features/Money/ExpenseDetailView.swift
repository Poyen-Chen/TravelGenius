//
//  ExpenseDetailView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData
import PhotosUI

struct ExpenseDetailView: View {
    @Bindable var expense: Expense
    @State private var amountText = ""
    @FocusState private var amountFocused: Bool
    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingReceipt = false

    var body: some View {
        Form {
            Section {
                TextField("金額", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                Picker("幣別", selection: $expense.currencyCode) {
                    ForEach(StaticDataStore.shared.currencies) { currency in
                        Text("\(currency.code)　\(currency.nameZh)").tag(currency.code)
                    }
                }
                if let trip = expense.trip, expense.currencyCode != trip.homeCurrencyCode {
                    LabeledContent("折算本幣") {
                        MoneyText(amount: expense.amountInHome, currencyCode: trip.homeCurrencyCode)
                    }
                }
            } header: {
                Text("金額")
            } footer: {
                let table = StaticDataStore.shared.exchangeRates
                Text("匯率來源：\(table.source ?? "內建匯率")・\(table.asOf)，記帳當下凍結。")
            }

            Section("類別") {
                Picker("類別", selection: $expense.categoryRaw) {
                    ForEach(ExpenseCategory.allCases) { category in
                        Label(category.label, systemImage: category.symbolName)
                            .tag(category.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("詳細") {
                DatePicker("日期", selection: $expense.date)
                TextField("註記", text: $expense.note)
            }

            Section("報帳") {
                Toggle("需報帳", isOn: $expense.isReimbursable)

                if let data = expense.receiptImageData, let image = UIImage(data: data) {
                    Button {
                        showingReceipt = true
                    } label: {
                        HStack {
                            Text("收據")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(expense.receiptImageData == nil ? "附上收據" : "更換收據", systemImage: "paperclip")
                }
                if CameraPicker.isAvailable {
                    Button("拍攝收據", systemImage: "camera") { showingCamera = true }
                }
                if expense.receiptImageData != nil {
                    Button("移除收據", systemImage: "trash", role: .destructive) {
                        expense.receiptImageData = nil
                    }
                }
            }
        }
        .navigationTitle("編輯支出")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { amountFocused = false }
            }
        }
        .onAppear {
            amountText = "\(NSDecimalNumber(decimal: expense.amount))"
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    expense.receiptImageData = ReceiptImage.processed(data)
                }
                photoItem = nil
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { data in
                expense.receiptImageData = ReceiptImage.processed(data)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingReceipt) {
            if let data = expense.receiptImageData {
                ReceiptViewer(imageData: data)
            }
        }
        .onChange(of: amountText) { _, newValue in
            if let value = Decimal.fromUserInput(newValue), value >= 0 {
                expense.amount = value
            }
        }
        .onChange(of: expense.currencyCode) { _, newValue in
            if let trip = expense.trip {
                expense.rateToHome = CurrencyService.shared.rate(from: newValue, to: trip.homeCurrencyCode)
            }
        }
    }
}
