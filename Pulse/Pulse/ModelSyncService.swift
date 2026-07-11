//
//  ModelSyncService.swift
//  Pulse
//

import Foundation

private struct ModelVersionResponse: Decodable {
    let modelName: String
    let version: String
    let downloadUrl: String
    let createdAt: String
}

@Observable
class ModelSyncService {
    static let shared = ModelSyncService()

    private(set) var latestVersion: String?
    private(set) var lastChecked: Date?
    private(set) var updateAvailable = false

    private let bundledVersion = "1.0.0"

    func checkForUpdates() async {
        do {
            let response: ModelVersionResponse = try await APIClient.shared.get(
                "/api/models/latest",
                query: ["name": "TransactionClassifier"]
            )
            await MainActor.run {
                latestVersion = response.version
                lastChecked = Date()
                updateAvailable = response.version != bundledVersion
            }
        } catch {
            await MainActor.run { lastChecked = Date() }
        }
    }
}
