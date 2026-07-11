//
//  AddTransactionView.swift
//  Pulse
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var merchantName = ""
    @State private var amountText = ""
    @State private var selectedDate = Date()
    @State private var isClassifying = false

    private var isValid: Bool {
        !merchantName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(amountText) != nil &&
        Double(amountText)! > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction Details") {
                    HStack {
                        Text("₹")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)

                    TextField("Merchant (e.g. Swiggy, Ola)", text: $merchantName)

                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }

                Section {
                    HStack {
                        Image(systemName: "cpu.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Text("Category will be detected automatically by Core ML")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isClassifying {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(!isValid || isClassifying)
                }
            }
        }
    }

    private func save() {
        guard let amount = Double(amountText) else { return }
        isClassifying = true

        let tx = Transaction(
            amount: amount,
            merchantName: merchantName.trimmingCharacters(in: .whitespaces),
            date: selectedDate
        )
        context.insert(tx)

        Task {
            let category = ClassifierEngine.shared.classify(tx)
            let anomaly = AnomalyEngine.shared.detect(tx)
            await MainActor.run {
                tx.category = category
                tx.isAnomaly = anomaly.isAnomaly
                tx.anomalyScore = anomaly.score
                try? context.save()
                dismiss()
            }
        }
    }
}
