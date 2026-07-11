//
//  ModelStatusView.swift
//  Pulse
//

import SwiftUI

struct ModelStatusView: View {
    @State private var syncService = ModelSyncService.shared
    @State private var trainer = FederatedTrainer.shared

    private var syncStatusText: String {
        guard let checked = syncService.lastChecked else { return "Not checked yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: checked, relativeTo: Date())
    }

    private var versionStatusText: String {
        if syncService.updateAvailable, let latest = syncService.latestVersion {
            return "Update available: v\(latest)"
        }
        return "Up to date (v1.0.0)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Active Models") {
                    ModelChipView(name: "TransactionClassifier", status: "Active", color: .green)
                    ModelChipView(name: "AnomalyDetector", status: "Active", color: .green)
                    LabeledContent("Version", value: versionStatusText)
                        .foregroundStyle(syncService.updateAvailable ? .orange : .primary)
                    LabeledContent("Last checked", value: syncStatusText)
                    LabeledContent("Inference", value: "On-Device (Core ML)")
                    LabeledContent("Latency", value: "< 10ms per transaction")
                }

                Section("Privacy") {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Zero data leaves your device")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Transaction amounts, merchants, and dates are processed entirely on-device. Only anonymized gradient updates are uploaded to improve the global model.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Federated Learning") {
                    LabeledContent("Corrections contributed", value: "\(trainer.correctionCount)")
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("How it works")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("When you correct a category, the app computes the difference from the model prediction. These deltas — not your data — improve the global model for everyone.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("AI Model")
            .task {
                await ModelSyncService.shared.checkForUpdates()
            }
        }
    }
}

struct ModelChipView: View {
    let name: String
    let status: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(name)
                .font(.subheadline)
            Spacer()
            Text(status)
                .font(.caption)
                .foregroundStyle(color)
        }
    }
}
