//
//  ExpenseListView.swift
//  TravelGenius
//

import SwiftUI
import SwiftData

struct ExpenseListView: View {
    let trip: Trip

    @Environment(\.modelContext) private var context
    @State private var searchText = ""

    private struct DayGroup: Identifiable {
        let day: Date
        let items: [Expense]
        let total: Decimal
        var id: Date { day }
    }

    private var filtered: [Expense] {
        let all = trip.sortedExpenses
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.note.localizedStandardContains(searchText) ||
            $0.category.label.localizedStandardContains(searchText)
        }
    }

    private var groups: [DayGroup] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return byDay
            .map { day, items in
                DayGroup(
                    day: day,
                    items: items.sorted { $0.date > $1.date },
                    total: items.reduce(0) { $0 + $1.amountInHome }
                )
            }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.items) { expense in
                        NavigationLink {
                            ExpenseDetailView(expense: expense)
                        } label: {
                            ExpenseRow(expense: expense, homeCurrencyCode: trip.homeCurrencyCode)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            context.delete(group.items[index])
                        }
                    }
                } header: {
                    HStack {
                        Text(group.day, format: .dateTime.month().day().weekday())
                        Spacer()
                        MoneyText(amount: group.total, currencyCode: trip.homeCurrencyCode)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜尋註記或類別")
        .overlay {
            if groups.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView("尚無支出", systemImage: "list.bullet", description: Text("回到儀表板點「記一筆」開始記帳。"))
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .navigationTitle("全部支出")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ExpenseRow: View {
    let expense: Expense
    let homeCurrencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: expense.category)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(expense.note.isEmpty ? expense.category.label : expense.note)
                        .font(.body)
                        .lineLimit(1)
                    if expense.isReimbursable {
                        Image(systemName: "briefcase.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("需報帳")
                    }
                    if expense.receiptImageData != nil {
                        Image(systemName: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("已附收據")
                    }
                }
                Text("\(expense.date.formatted(date: .omitted, time: .shortened))・\(expense.category.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                MoneyText(amount: expense.amount, currencyCode: expense.currencyCode)
                    .font(.body)
                if expense.currencyCode != homeCurrencyCode {
                    MoneyText(amount: expense.amountInHome, currencyCode: homeCurrencyCode)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
