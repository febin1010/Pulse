//
//  FederatedTrainer.swift
//  Pulse
//

import Foundation
import UIKit

private struct GradientUpload: Encodable {
    let deviceId: String
    let roundId: String
    let categoryDeltas: [String: Double]
}

private struct GradientResponse: Decodable {
    let id: Int?
    let status: String?
    let roundId: String?
}

@Observable
class FederatedTrainer {
    static let shared = FederatedTrainer()

    private(set) var correctionCount: Int = 0
    private let minCorrectionsToUpload = 5
    private var pendingCorrections: [(category: String, predicted: String)] = []
    private let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"

    init() {
        correctionCount = UserDefaults.standard.integer(forKey: "correctionCount")
    }

    func recordCorrection(transaction: Transaction, correctCategory: String) {
        let predicted = transaction.category ?? "other"
        pendingCorrections.append((category: correctCategory, predicted: predicted))
        correctionCount += 1
        UserDefaults.standard.set(correctionCount, forKey: "correctionCount")
    }

    func uploadIfReady() async {
        guard pendingCorrections.count >= minCorrectionsToUpload else { return }

        let deltas = computeDeltas(corrections: pendingCorrections)
        let roundId = currentRoundId()
        let upload = GradientUpload(deviceId: deviceId, roundId: roundId, categoryDeltas: deltas)

        do {
            let _: GradientResponse = try await APIClient.shared.post("/api/federation/gradient", body: upload)
            pendingCorrections.removeAll()
        } catch {
            // Silent fail — corrections are preserved for next attempt
        }
    }

    // Category delta: how much each correct category was under-predicted
    private func computeDeltas(corrections: [(category: String, predicted: String)]) -> [String: Double] {
        let total = Double(corrections.count)
        var correctCounts: [String: Double] = [:]
        var predictedCounts: [String: Double] = [:]

        for correction in corrections {
            correctCounts[correction.category, default: 0] += 1
            predictedCounts[correction.predicted, default: 0] += 1
        }

        var deltas: [String: Double] = [:]
        let allCategories = Set(correctCounts.keys).union(predictedCounts.keys)
        for cat in allCategories {
            let correctFreq = (correctCounts[cat] ?? 0) / total
            let predictedFreq = (predictedCounts[cat] ?? 0) / total
            let delta = correctFreq - predictedFreq
            if abs(delta) > 0.001 {
                deltas[cat] = delta
            }
        }
        return deltas
    }

    private func currentRoundId() -> String {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.year, from: Date())
        return "\(year)-W\(String(format: "%02d", weekOfYear))"
    }
}
