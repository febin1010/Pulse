//
//  AnomalyEngine.swift
//  Pulse
//

import CoreML
import Foundation

class AnomalyEngine {
    static let shared = AnomalyEngine()

    private var model: MLModel?

    private init() {
        if let url = Bundle.main.url(forResource: "AnomalyDetector", withExtension: "mlmodelc") {
            model = try? MLModel(contentsOf: url)
        }
    }

    func detect(_ transaction: Transaction) -> (isAnomaly: Bool, score: Double) {
        guard let model else { return (false, 0.0) }

        let hour = Calendar.current.component(.hour, from: transaction.date)
        let dow = Calendar.current.component(.weekday, from: transaction.date)
        let bucket = ClassifierEngine.shared.merchantBucketPublic(transaction.merchantName)
        let categoryEncoded = categoryCode(transaction.displayCategory)

        let input: [String: Any] = [
            "amount": transaction.amount,
            "hour_of_day": Double(hour),
            "day_of_week": Double(dow),
            "merchant_bucket": Double(bucket),
            "category_encoded": Double(categoryEncoded)
        ]

        guard let provider = try? MLDictionaryFeatureProvider(dictionary: input),
              let output = try? model.prediction(from: provider),
              let result = output.featureValue(for: "is_anomaly")
        else { return (false, 0.0) }

        let isAnomaly = result.int64Value == 1
        return (isAnomaly, isAnomaly ? 1.0 : 0.0)
    }

    private func categoryCode(_ category: String) -> Int {
        switch category {
        case "bills":         return 0
        case "entertainment": return 1
        case "food":          return 2
        case "other":         return 3
        case "transport":     return 4
        default:              return 3
        }
    }
}
