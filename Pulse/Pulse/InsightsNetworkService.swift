//
//  InsightsNetworkService.swift
//  Pulse
//

import Foundation
import UIKit

struct FeatureVector: Encodable {
    let deviceId: String
    let avgWeeklySpend: Double
    let topCategory: String
    let anomalyCount: Int
    let spendingTrend: String
    let projectedDeficit: Bool
    let deficitAmount: Double
}

private struct InsightsResponse: Decodable {
    let insights: String
}

class InsightsNetworkService {
    static let shared = InsightsNetworkService()

    private let cacheKey = "cachedInsights"
    private let cacheDateKey = "cachedInsightsDate"

    func fetchInsights(transactions: [Transaction], forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh, let cached = cachedInsightsForToday() {
            return cached
        }

        let vector = buildFeatureVector(from: transactions)
        let response: InsightsResponse = try await APIClient.shared.post("/api/insights", body: vector)
        cacheInsights(response.insights)
        return response.insights
    }

    private func buildFeatureVector(from transactions: [Transaction]) -> FeatureVector {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: now)!

        let thisWeek = transactions.filter { $0.date >= sevenDaysAgo }
        let lastWeek = transactions.filter { $0.date >= fourteenDaysAgo && $0.date < sevenDaysAgo }

        let avgWeeklySpend = thisWeek.reduce(0) { $0 + $1.amount }
        let anomalyCount = thisWeek.filter { $0.isAnomaly }.count

        let recentCategories = transactions.prefix(30).compactMap { $0.displayCategory }
        let topCategory = recentCategories
            .reduce(into: [:]) { $0[$1, default: 0] += 1 }
            .max(by: { $0.value < $1.value })?.key ?? "other"

        let thisWeekTotal = thisWeek.reduce(0) { $0 + $1.amount }
        let lastWeekTotal = lastWeek.reduce(0) { $0 + $1.amount }
        let spendingTrend: String
        if lastWeekTotal == 0 {
            spendingTrend = "stable"
        } else {
            let change = (thisWeekTotal - lastWeekTotal) / lastWeekTotal
            spendingTrend = change > 0.1 ? "increasing" : change < -0.1 ? "decreasing" : "stable"
        }

        return FeatureVector(
            deviceId: deviceId,
            avgWeeklySpend: avgWeeklySpend,
            topCategory: topCategory,
            anomalyCount: anomalyCount,
            spendingTrend: spendingTrend,
            projectedDeficit: false,
            deficitAmount: 0
        )
    }

    private func cachedInsightsForToday() -> String? {
        guard let date = UserDefaults.standard.object(forKey: cacheDateKey) as? Date,
              Calendar.current.isDateInToday(date),
              let cached = UserDefaults.standard.string(forKey: cacheKey) else { return nil }
        return cached
    }

    private func cacheInsights(_ text: String) {
        UserDefaults.standard.set(text, forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: cacheDateKey)
    }
}
