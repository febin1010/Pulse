//
//  DashboardView.swift
//  Pulse
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @ObservedObject private var budgetStore = BudgetStore.shared

    private var thisWeek: [Transaction] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return transactions.filter { $0.date >= cutoff }
    }

    private var lastWeek: [Transaction] {
        let end = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let start = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return transactions.filter { $0.date >= start && $0.date < end }
    }

    private var totalThisWeek: Double { thisWeek.reduce(0) { $0 + $1.amount } }
    private var totalLastWeek: Double { lastWeek.reduce(0) { $0 + $1.amount } }

    private var weekOverWeekChange: Double {
        guard totalLastWeek > 0 else { return 0 }
        return ((totalThisWeek - totalLastWeek) / totalLastWeek) * 100
    }

    private var anomalyCount: Int { thisWeek.filter { $0.isAnomaly }.count }

    private var thisMonthByCategory: [String: Double] {
        let cutoff = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let monthly = transactions.filter { $0.date >= cutoff }
        var totals: [String: Double] = [:]
        for tx in monthly {
            totals[tx.displayCategory, default: 0] += tx.amount
        }
        return totals
    }

    private var categoryTotals: [(String, Double)] {
        let categories = ["food", "transport", "bills", "entertainment", "other"]
        return categories.compactMap { cat in
            let total = thisWeek
                .filter { $0.displayCategory == cat }
                .reduce(0) { $0 + $1.amount }
            return total > 0 ? (cat, total) : nil
        }
        .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Hero spend card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This Week")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .bottom, spacing: 12) {
                            Text("₹\(Int(totalThisWeek))")
                                .font(.system(size: 40, weight: .bold, design: .rounded))

                            if totalLastWeek > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: weekOverWeekChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    Text("\(abs(Int(weekOverWeekChange)))% vs last week")
                                }
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(weekOverWeekChange >= 0 ? .red : .green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    (weekOverWeekChange >= 0 ? Color.red : Color.green).opacity(0.12),
                                    in: Capsule()
                                )
                                .padding(.bottom, 6)
                            }
                        }

                        Text("\(thisWeek.count) transactions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                    // Anomaly banner
                    if anomalyCount > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("\(anomalyCount) unusual transaction\(anomalyCount > 1 ? "s" : "") detected")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Budget progress
                    if !thisMonthByCategory.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Monthly Budget")
                                .font(.headline)

                            ForEach(["food", "transport", "bills", "entertainment", "other"], id: \.self) { cat in
                                let spent = thisMonthByCategory[cat] ?? 0
                                let budget = budgetStore.budgets[cat] ?? 1
                                let pct = min(spent / budget, 1.0)
                                if spent > 0 || budget > 0 {
                                    BudgetRowView(
                                        category: cat,
                                        spent: spent,
                                        budget: budget,
                                        percentage: pct
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                    }

                    // This week category breakdown
                    if !categoryTotals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("This Week by Category")
                                .font(.headline)

                            ForEach(categoryTotals, id: \.0) { category, total in
                                HStack {
                                    Text(emojiFor(category))
                                    Text(category.capitalized)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("₹\(Int(total))")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                    }

                    // AI chip
                    HStack {
                        Image(systemName: "cpu.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("Core ML active — all classification on-device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.08), in: Capsule())
                }
                .padding()
            }
            .navigationTitle("Pulse")
        }
    }

    private func emojiFor(_ category: String) -> String {
        switch category {
        case "food":          return "🍔"
        case "transport":     return "🚗"
        case "bills":         return "📄"
        case "entertainment": return "🎬"
        default:              return "💳"
        }
    }
}

struct BudgetRowView: View {
    let category: String
    let spent: Double
    let budget: Double
    let percentage: Double

    private var emoji: String {
        switch category {
        case "food": return "🍔"
        case "transport": return "🚗"
        case "bills": return "📄"
        case "entertainment": return "🎬"
        default: return "💳"
        }
    }

    private var barColor: Color {
        if percentage >= 0.9 { return .red }
        if percentage >= 0.7 { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(emoji)
                Text(category.capitalized)
                    .font(.subheadline)
                Spacer()
                Text("₹\(Int(spent)) / ₹\(Int(budget))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
