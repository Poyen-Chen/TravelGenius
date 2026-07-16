//
//  QuickExpenseEntryView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData
import PhotosUI

/// 兩步記帳：第一步輸入金額，第二步點類別即完成儲存
struct QuickExpenseEntryView: View {
    let trip: Trip

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case amount
        case category
    }

    @State private var step: Step = .amount
    @State private var amountText = ""
    @State private var useLocalCurrency = true
    @State private var note = ""
    @State private var saved = false
    @State private var isReimbursable: Bool
    @State private var receiptData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @ScaledMetric(relativeTo: .title2) private var keyHeight: CGFloat = 50

    init(trip: Trip) {
        self.trip = trip
        // 商務行程預設開啟報帳
        _isReimbursable = State(initialValue: trip.tripType == .business)
    }

    private var currencyCode: String {
        useLocalCurrency ? trip.localCurrencyCode : trip.homeCurrencyCode
    }

    private var amount: Decimal? {
        Decimal(string: amountText)
    }

    private var convertedToHome: Decimal? {
        guard let amount, currencyCode != trip.homeCurrencyCode else { return nil }
        return CurrencyService.shared.convert(amount, from: currencyCode, to: trip.homeCurrencyCode)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .amount: amountStep
                case .category: categoryStep
                }
            }
            .navigationTitle("記一筆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.success, trigger: saved)
    }

    // MARK: - 第一步：金額

    private var amountStep: some View {
        VStack(spacing: 12) {
            if trip.localCurrencyCode != trip.homeCurrencyCode {
                Picker("幣別", selection: $useLocalCurrency) {
                    Text(trip.localCurrencyCode).tag(true)
                    Text(trip.homeCurrencyCode).tag(false)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            VStack(spacing: 2) {
                Text("\(StaticDataStore.shared.currency(code: currencyCode)?.symbol ?? currencyCode) \(amountText.isEmpty ? "0" : amountText)")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: amountText)
                if let convertedToHome {
                    HStack(spacing: 3) {
                        Text("自動折算")
                        MoneyText(amount: convertedToHome, currencyCode: trip.homeCurrencyCode)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else {
                    Text(" ")
                        .font(.footnote)
                }
            }

            keypad

            Button {
                step = .category
            } label: {
                Text("下一步：選擇類別")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled((amount ?? 0) <= 0)
        }
        .padding()
    }

    private var keypad: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(keys, id: \.self) { key in
                Button {
                    tap(key)
                } label: {
                    Group {
                        if key == "⌫" {
                            Image(systemName: "delete.left")
                        } else {
                            Text(key)
                        }
                    }
                    .font(.title2.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: keyHeight)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(key == "⌫" ? "刪除" : key)
            }
        }
    }

    private func tap(_ key: String) {
        switch key {
        case "⌫":
            if !amountText.isEmpty { amountText.removeLast() }
        case ".":
            if amountText.isEmpty {
                amountText = "0."
            } else if !amountText.contains(".") {
                amountText.append(".")
            }
        default:
            guard amountText.count < 10 else { return }
            if amountText == "0" {
                amountText = key
            } else {
                amountText.append(key)
            }
        }
    }

    // MARK: - 第二步：類別（點選即儲存）

    private var categoryStep: some View {
        VStack(spacing: 16) {
            Button {
                step = .amount
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.backward")
                        .font(.caption.weight(.semibold))
                    Text("\(StaticDataStore.shared.currency(code: currencyCode)?.symbol ?? currencyCode) \(amountText)")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回修改金額")

            TextField("註記（選填）", text: $note)
                .textFieldStyle(.roundedBorder)

            reimbursementRow

            Text("點選類別即完成記帳")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(ExpenseCategory.allCases) { category in
                    Button {
                        save(category: category)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: category.symbolName)
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(category.color.gradient, in: Circle())
                            Text(category.label)
                                .font(.footnote)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
    }

    /// 報帳選項：需報帳開關 + 收據附檔
    private var reimbursementRow: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $isReimbursable) {
                Label("需報帳", systemImage: "briefcase")
                    .font(.subheadline)
            }
            .fixedSize()

            Spacer()

            if let receiptData, let image = UIImage(data: receiptData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Button {
                    self.receiptData = nil
                    photoItem = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("移除收據")
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("附收據", systemImage: "paperclip")
                        .font(.subheadline)
                }
                if CameraPicker.isAvailable {
                    Button {
                        showingCamera = true
                    } label: {
                        Image(systemName: "camera")
                    }
                    .accessibilityLabel("拍攝收據")
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    receiptData = ReceiptImage.processed(data)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { data in
                receiptData = ReceiptImage.processed(data)
            }
            .ignoresSafeArea()
        }
    }

    private func save(category: ExpenseCategory) {
        guard let amount else { return }
        let rate = CurrencyService.shared.rate(from: currencyCode, to: trip.homeCurrencyCode)
        let expense = Expense(
            amount: amount,
            currencyCode: currencyCode,
            rateToHome: rate,
            category: category,
            note: note.trimmingCharacters(in: .whitespaces),
            trip: trip
        )
        expense.isReimbursable = isReimbursable
        expense.receiptImageData = receiptData
        context.insert(expense)
        WidgetSync.update(trip: trip)
        saved.toggle()
        dismiss()
    }
}
