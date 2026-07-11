//
//  TransactionListView.swift
//  Pulse
//

import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false
    @State private var correcting: Transaction?

    private let categories = ["food", "transport", "bills", "entertainment", "other"]

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "creditcard",
                        description: Text("Tap + to add your first transaction.")
                    )
                } else {
                    List(transactions) { tx in
                        TransactionRowView(transaction: tx)
                            .contextMenu {
                                Label("Correct Category", systemImage: "pencil")
                                    .onTapGesture { correcting = tx }
                                ForEach(categories, id: \.self) { cat in
                                    Button {
                                        applyCorrection(tx, category: cat)
                                    } label: {
                                        Label(cat.capitalized, systemImage: iconFor(cat))
                                    }
                                }
                            }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(transactions.count) total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddTransactionView()
            }
            .task {
                await classifyAll()
            }
        }
    }

    private func classifyAll() async {
        let unclassified = transactions.filter { $0.category == nil }
        guard !unclassified.isEmpty else { return }
        for tx in unclassified {
            let category = ClassifierEngine.shared.classify(tx)
            let anomaly = AnomalyEngine.shared.detect(tx)
            await MainActor.run {
                tx.category = category
                tx.isAnomaly = anomaly.isAnomaly
                tx.anomalyScore = anomaly.score
            }
        }
        await MainActor.run { try? context.save() }
    }

    private func applyCorrection(_ tx: Transaction, category: String) {
        FederatedTrainer.shared.recordCorrection(transaction: tx, correctCategory: category)
        tx.userCorrectedCategory = category
        try? context.save()
        Task { await FederatedTrainer.shared.uploadIfReady() }
    }

    private func iconFor(_ category: String) -> String {
        switch category {
        case "food":          return "fork.knife"
        case "transport":     return "car.fill"
        case "bills":         return "doc.text.fill"
        case "entertainment": return "play.circle.fill"
        default:              return "creditcard.fill"
        }
    }
}

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Text(transaction.categoryEmoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(.quaternary, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(transaction.merchantName)
                        .font(.body)
                        .fontWeight(.medium)
                    if transaction.isAnomaly {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    if transaction.userCorrectedCategory != nil {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                    }
                }
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("₹\(Int(transaction.amount))")
                    .font(.body)
                    .fontWeight(.semibold)

                if transaction.category != nil {
                    Text(transaction.displayCategory)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                } else {
                    Text("classifying...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
