//
//  CashFlowView.swift
//  Pulse
//

import SwiftUI
import SwiftData
import Charts

struct CashFlowView: View {
    @Query private var transactions: [Transaction]
    @AppStorage("userBalance") private var currentBalance: Double = 0
    @State private var showingBalanceEntry = false

    private var avgDailySpend: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = transactions.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(0) { $0 + $1.amount } / 30.0
    }

    private var projectedPoints: [(day: Int, balance: Double)] {
        (0...14).map { day in
            let projected = currentBalance - (avgDailySpend * Double(day))
            return (day, max(projected, 0))
        }
    }

    private var projectedDeficit: Bool {
        guard let last = projectedPoints.last else { return false }
        return last.balance < currentBalance * 0.2
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Balance card
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Balance")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if currentBalance == 0 {
                                Button("Tap to set balance") { showingBalanceEntry = true }
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            } else {
                                Text("₹\(currentBalance, specifier: "%.0f")")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                        }
                        Spacer()
                        Button { showingBalanceEntry = true } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))

                    // Stats row
                    HStack(spacing: 12) {
                        StatCard(title: "Avg/Day", value: "₹\(Int(avgDailySpend))")
                        StatCard(title: "Projected (14d)", value: projectedDeficit ? "⚠️ Low" : "Stable")
                    }

                    // Chart
                    if currentBalance > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("14-Day Balance Projection")
                                .font(.headline)
                            Text("Based on ₹\(Int(avgDailySpend))/day average spend")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Chart(projectedPoints, id: \.day) { point in
                                LineMark(
                                    x: .value("Day", point.day),
                                    y: .value("Balance", point.balance)
                                )
                                .foregroundStyle(projectedDeficit ? .red : .blue)
                                .lineStyle(StrokeStyle(lineWidth: 2))

                                AreaMark(
                                    x: .value("Day", point.day),
                                    y: .value("Balance", point.balance)
                                )
                                .foregroundStyle(
                                    (projectedDeficit ? Color.red : Color.blue).opacity(0.1)
                                )
                            }
                            .frame(height: 200)
                            .chartXAxis {
                                AxisMarks(values: [0, 7, 14]) { val in
                                    AxisValueLabel {
                                        if let day = val.as(Int.self) {
                                            Text(day == 0 ? "Today" : "Day \(day)")
                                                .font(.caption2)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))

                        if projectedDeficit {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text("Balance projected below 20% in 14 days")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Cash Flow")
            .sheet(isPresented: $showingBalanceEntry) {
                BalanceEntryView(balance: $currentBalance)
                    .presentationDetents([.fraction(0.35)])
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct BalanceEntryView: View {
    @Binding var balance: Double
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Enter your current bank balance") {
                    TextField("e.g. 25000", text: $input)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Set Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let val = Double(input) { balance = val }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
