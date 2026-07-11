//
//  ClassifierEngine.swift
//  Pulse
//

import CoreML
import Foundation

class ClassifierEngine {
    static let shared = ClassifierEngine()

    private var model: MLModel?

    private init() {
        // Load from disk (downloaded model) if available, else fall back to bundle
        if let diskModel = loadFromDisk() {
            model = diskModel
        } else if let url = Bundle.main.url(forResource: "TransactionClassifier", withExtension: "mlmodelc") {
            model = try? MLModel(contentsOf: url)
        }
    }

    func classify(_ transaction: Transaction) -> String {
        guard let model else { return "other" }

        let hour = Calendar.current.component(.hour, from: transaction.date)
        let dow = Calendar.current.component(.weekday, from: transaction.date)
        let bucket = merchantBucket(transaction.merchantName)

        let input: [String: Any] = [
            "amount": transaction.amount,
            "hour_of_day": Double(hour),
            "day_of_week": Double(dow),
            "merchant_bucket": Double(bucket)
        ]

        guard let provider = try? MLDictionaryFeatureProvider(dictionary: input),
              let output = try? model.prediction(from: provider),
              let category = output.featureValue(for: "category")?.stringValue
        else { return "other" }

        return category
    }

    // Called by ModelSyncService after a successful download + compile
    func loadModel(from compiledURL: URL) {
        if let newModel = try? MLModel(contentsOf: compiledURL) {
            model = newModel
        }
    }

    func merchantBucketPublic(_ name: String) -> Int { merchantBucket(name) }

    // MARK: - Private

    private func loadFromDisk() -> MLModel? {
        guard let url = downloadedModelURL() else { return nil }
        return try? MLModel(contentsOf: url)
    }

    private func downloadedModelURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let modelsDir = appSupport.appendingPathComponent("Models")
        // Find the most recently downloaded compiled model
        guard let files = try? FileManager.default.contentsOfDirectory(at: modelsDir, includingPropertiesForKeys: [.creationDateKey], options: []) else { return nil }
        return files
            .filter { $0.pathExtension == "mlmodelc" }
            .sorted { l, r in
                let lDate = (try? l.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let rDate = (try? r.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return lDate > rDate
            }
            .first
    }

    private func merchantBucket(_ name: String) -> Int {
        let lower = name.lowercased()
        if lower.contains("swiggy") || lower.contains("zomato") || lower.contains("domino") ||
           lower.contains("kfc") || lower.contains("burger") || lower.contains("pizza") ||
           lower.contains("blinkit") || lower.contains("dunzo") || lower.contains("bigbasket") ||
           lower.contains("chai") || lower.contains("tea") || lower.contains("subway") { return 0 }
        if lower.contains("mcdonald") || lower.contains("haldiram") || lower.contains("instamart") { return 1 }
        if lower.contains("ola") || lower.contains("uber") || lower.contains("rapido") ||
           lower.contains("auto") || lower.contains("bmtc") || lower.contains("metro") { return 2 }
        if lower.contains("rail") || lower.contains("redbus") || lower.contains("indigo") ||
           lower.contains("air india") || lower.contains("electric") { return 3 }
        if lower.contains("jio") || lower.contains("airtel") || lower.contains("bsnl") ||
           lower.contains("electricity") || lower.contains("water bill") || lower.contains("gas bill") { return 4 }
        if lower.contains("emi") || lower.contains("lic") || lower.contains("society") ||
           lower.contains("netflix") || lower.contains("prime") || lower.contains("hotstar") ||
           lower.contains("spotify") || lower.contains("youtube") { return 5 }
        if lower.contains("bookmyshow") || lower.contains("pvr") || lower.contains("inox") ||
           lower.contains("steam") || lower.contains("playstation") { return 6 }
        if lower.contains("myntra") || lower.contains("ajio") || lower.contains("nykaa") ||
           lower.contains("decathlon") || lower.contains("crossword") { return 7 }
        if lower.contains("amazon") || lower.contains("flipkart") || lower.contains("pharmacy") ||
           lower.contains("1mg") || lower.contains("practo") || lower.contains("atm") { return 8 }
        return 9
    }
}
