//
//  InsightsView.swift
//  Pulse
//

import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var insights: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Privacy explanation
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Privacy First", systemImage: "lock.shield.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text("Only an anonymized spending summary is sent — no transaction details ever leave your device.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                    if insights.isEmpty && !isLoading {
                        ContentUnavailableView(
                            "No Insights Yet",
                            systemImage: "lightbulb",
                            description: Text("Tap below to get AI-powered insights from your spending patterns.")
                        )
                        .padding(.top, 40)
                    }

                    if let errorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "wifi.slash")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    }

                    if isLoading {
                        ProgressView("Generating insights...")
                            .padding(.top, 40)
                    }

                    ForEach(insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                                .font(.title3)
                            Text(insight)
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if insights.isEmpty {
                        Button {
                            Task { await loadInsights(forceRefresh: false) }
                        } label: {
                            Label("Get Insights", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isLoading)
                    } else {
                        Button {
                            Task { await loadInsights(forceRefresh: true) }
                        } label: {
                            Label("Refresh Insights", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isLoading)
                    }
                }
                .padding()
                .animation(.easeInOut, value: insights)
            }
            .navigationTitle("Insights")
        }
    }

    private func loadInsights(forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil
        do {
            let text = try await InsightsNetworkService.shared.fetchInsights(
                transactions: Array(transactions),
                forceRefresh: forceRefresh
            )
            insights = text.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } catch {
            errorMessage = "Could not load insights. Please try again."
        }
        isLoading = false
    }
}
