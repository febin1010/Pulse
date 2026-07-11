//
//  ModelStatusView.swift
//  Pulse
//

import SwiftUI
import Combine

struct ModelStatusView: View {
    @State private var syncService = ModelSyncService.shared
    @State private var trainer = FederatedTrainer.shared
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var syncStatusText: String {
        guard let checked = syncService.lastChecked else { return "Not checked yet" }
        let elapsed = Int(now.timeIntervalSince(checked))
        if elapsed < 5 { return "Just now" }
        if elapsed < 60 { return "\(elapsed)s ago" }
        if elapsed < 3600 { return "\(elapsed / 60)m ago" }
        return "\(elapsed / 3600)h ago"
    }

    private var versionStatusText: String {
        if syncService.updateAvailable, let latest = syncService.latestVersion {
            return "Update available: v\(latest)"
        }
        return "v1.0.0 (up to date)"
    }

    var body: some View {
        NavigationStack {
            List {

                // MARK: — Active Models
                Section("Active Models") {
                    ModelChipView(name: "TransactionClassifier", status: "Active", color: .green)
                    ModelChipView(name: "AnomalyDetector", status: "Active", color: .green)
                    LabeledContent("Version", value: versionStatusText)
                        .foregroundStyle(syncService.updateAvailable ? .orange : .primary)
                    LabeledContent("Last synced", value: syncStatusText)
                        .monospacedDigit()
                    LabeledContent("Inference", value: "On-Device · Core ML")
                    LabeledContent("Avg latency", value: "< 10ms")

                    if syncService.isDownloading {
                        HStack(spacing: 10) {
                            ProgressView().scaleEffect(0.8)
                            Text("Downloading model update...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if syncService.justUpdated {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Model updated to \(syncService.latestVersion ?? "latest") — now live")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        .padding(.vertical, 2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                // MARK: — AI Features
                Section("How the AI Works") {
                    AIFeatureRow(
                        icon: "brain.head.profile",
                        color: .purple,
                        title: "Transaction Classifier",
                        description: "A Random Forest model trained on 2,000 Indian spending patterns. It runs entirely on your device — no internet needed — and categorises every transaction into Food, Transport, Bills, Entertainment, or Other in under 10ms."
                    )

                    AIFeatureRow(
                        icon: "exclamationmark.triangle.fill",
                        color: .orange,
                        title: "Anomaly Detector",
                        description: "A Gradient Boosting model that flags transactions that look unusual for your spending profile — a ₹15,000 charge when you normally spend ₹300, or a 3am transaction. Flagged transactions appear with a red dot."
                    )

                    AIFeatureRow(
                        icon: "sparkles",
                        color: .yellow,
                        title: "LLM Insights (Groq · Llama 3.1)",
                        description: "When you tap Get Insights, only an anonymised summary — your average weekly spend, top category, anomaly count, spending trend — is sent to the backend. No merchants, no amounts, no dates. Llama 3.1 running on Groq generates two specific, actionable insights in under 2 seconds."
                    )

                    AIFeatureRow(
                        icon: "arrow.triangle.2.circlepath",
                        color: .blue,
                        title: "Federated Learning",
                        description: "When you correct a category (long-press any transaction → Fix Category), the app measures how far the model's prediction was from your correction. After 5 corrections, it computes a gradient delta — the direction the model should shift — and uploads just that delta to the backend. Your raw transactions never leave your device. The backend averages deltas from all users (FedAvg) and can use the signal to improve future model versions."
                    )
                }

                // MARK: — Federated Learning Status
                Section("Your Contribution") {
                    LabeledContent("Corrections submitted", value: "\(trainer.correctionCount)")
                    LabeledContent("Upload threshold", value: "Every 5 corrections")

                    if trainer.correctionCount == 0 {
                        HStack(spacing: 10) {
                            Image(systemName: "hand.point.right")
                                .foregroundStyle(.blue)
                            Text("Long-press any transaction and tap Fix Category to start contributing to model improvement.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        let nextUpload = 5 - (trainer.correctionCount % 5)
                        LabeledContent(
                            "Next upload in",
                            value: nextUpload == 5 ? "Just uploaded!" : "\(nextUpload) more corrections"
                        )
                    }
                }

                // MARK: — Privacy
                Section("Privacy Guarantee") {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.green)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("What stays on your device")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            privacyRow(icon: "checkmark.circle.fill", text: "All transaction amounts, merchants, dates")
                            privacyRow(icon: "checkmark.circle.fill", text: "All ML inference (classification, anomaly detection)")
                            privacyRow(icon: "checkmark.circle.fill", text: "Your spending history and patterns")
                            Divider().padding(.vertical, 2)
                            Text("What leaves your device")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            privacyRow(icon: "arrow.up.circle", text: "Anonymised feature vector for insights (no raw data)", color: .blue)
                            privacyRow(icon: "arrow.up.circle", text: "Category correction deltas (not your transactions)", color: .blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("AI Model")
            .task {
                await ModelSyncService.shared.checkForUpdates()
            }
            .onReceive(timer) { _ in
                now = Date()
            }
        }
    }

    private func privacyRow(icon: String, text: String, color: Color = .green) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)
                .frame(width: 14)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct AIFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.title3)
                        .frame(width: 28)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 38)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
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
