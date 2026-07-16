//
//  RunwayDashboardView.swift
//  TravelGenius
//

import SwiftUI

struct RunwayDashboardView: View {
    let trip: Trip
    @State private var showingEntry = false
    @State private var showingBudgetEdit = false

    private var calc: RunwayCalculator { RunwayCalculator(trip: trip) }

    var body: some View {
        let calc = self.calc
        ScrollView {
            VStack(spacing: 14) {
                if trip.totalBudget > 0 {
                    heroCard(calc)
                } else {
                    budgetPromptCard(calc)
                }
                if trip.tripType == .business {
                    PerDiemGaugeView(trip: trip)
                }
                if trip.totalBudget > 0 {
                    todayCard(calc)
                }
                if calc.spent > 0 {
                    chartCard(calc)
                    if !calc.categoryTotals.isEmpty {
                        categoryCard(calc)
                    }
                }
                expensesLink
                exportLink
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            Button {
                showingEntry = true
            } label: {
                Label("記一筆", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .sheet(isPresented: $showingEntry) {
            QuickExpenseEntryView(trip: trip)
        }
        .sheet(isPresented: $showingBudgetEdit) {
            TripFormView(trip: trip)
        }
        .onAppear {
            WidgetSync.update(trip: trip)
        }
    }

    /// 未設定預算：提示補上預算，記帳照常可用
    private func budgetPromptCard(_ calc: RunwayCalculator) -> some View {
        VStack(spacing: 10) {
            Label("尚未設定預算", systemImage: "gauge.with.needle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("設定總預算後，這裡會顯示「還能撐幾天」的跑道倒數。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if calc.spent > 0 {
                HStack(spacing: 3) {
                    Text("已花費")
                    MoneyText(amount: Decimal(calc.spent), currencyCode: trip.homeCurrencyCode)
                }
                .font(.footnote.weight(.medium))
            }
            Button("設定預算") { showingBudgetEdit = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 跑道

    private func heroCard(_ calc: RunwayCalculator) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("跑道")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                StatusBadge(status: calc.status)
            }

            if let runway = calc.runwayDays {
                Text("還能撐 \(runway, format: .number.precision(.fractionLength(1))) 天")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            } else {
                Text("尚無支出")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label {
                    HStack(spacing: 3) {
                        MoneyText(amount: Decimal(calc.burnRatePerDay), currencyCode: trip.homeCurrencyCode)
                        Text("／天")
                    }
                    .font(.footnote)
                } icon: {
                    Image(systemName: "flame")
                        .font(.footnote)
                }
                .foregroundStyle(.secondary)
                Spacer()
                Text("旅程還剩 \(calc.remainingTripDays) 天")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    // MARK: - 今日

    private func todayCard(_ calc: RunwayCalculator) -> some View {
        let ratio = calc.todayCap > 0 ? calc.todaySpent / calc.todayCap : 0
        return VStack(alignment: .leading, spacing: 8) {
            Text("今日建議上限")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Gauge(value: min(calc.todaySpent, calc.todayCap), in: 0...max(calc.todayCap, 1)) {
                EmptyView()
            }
            .gaugeStyle(.linearCapacity)
            .tint(ratio >= 1 ? .red : ratio >= 0.8 ? .orange : .green)
            .accessibilityLabel("今日已用 \(Int(ratio * 100))%")
            HStack {
                HStack(spacing: 3) {
                    Text("已用")
                    MoneyText(amount: Decimal(calc.todaySpent), currencyCode: trip.homeCurrencyCode)
                }
                Spacer()
                HStack(spacing: 3) {
                    Text("上限")
                    MoneyText(amount: Decimal(calc.todayCap), currencyCode: trip.homeCurrencyCode)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 圖表

    private func chartCard(_ calc: RunwayCalculator) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每日支出")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            DailySpendChart(series: calc.dailySeries, dailyBudget: calc.dailyBudget)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func categoryCard(_ calc: RunwayCalculator) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("類別佔比")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            CategoryBreakdownChart(totals: calc.categoryTotals, currencyCode: trip.homeCurrencyCode)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var expensesLink: some View {
        NavigationLink {
            ExpenseListView(trip: trip)
        } label: {
            linkRow(title: "全部支出", systemImage: "list.bullet", detail: "\((trip.expenses ?? []).count) 筆")
        }
        .buttonStyle(.plain)
    }

    private var exportLink: some View {
        NavigationLink {
            ReportExportView(trip: trip)
        } label: {
            linkRow(title: "匯出報帳", systemImage: "square.and.arrow.up", detail: nil)
        }
        .buttonStyle(.plain)
    }

    private func linkRow(title: String, systemImage: String, detail: String?) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
            Spacer()
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
