//
//  ModelSyncService.swift
//  Pulse
//

import Foundation
import CoreML

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
    private(set) var isDownloading = false
    private(set) var justUpdated = false   // triggers toast in ModelStatusView

    private var activeVersion: String {
        get { UserDefaults.standard.string(forKey: "activeModelVersion") ?? "1.0.0" }
        set { UserDefaults.standard.set(newValue, forKey: "activeModelVersion") }
    }

    func checkForUpdates() async {
        do {
            let response: ModelVersionResponse = try await APIClient.shared.get(
                "/api/models/latest",
                query: ["name": "TransactionClassifier"]
            )
            await MainActor.run {
                latestVersion = response.version
                lastChecked = Date()
                updateAvailable = response.version != activeVersion
            }

            if updateAvailable {
                await downloadAndApply(url: response.downloadUrl, version: response.version)
            }
        } catch {
            await MainActor.run { lastChecked = Date() }
        }
    }

    private func downloadAndApply(url: String, version: String) async {
        await MainActor.run { isDownloading = true }

        do {
            // 1. Download .mlmodel to temp directory
            guard let downloadURL = URL(string: url) else { return }
            let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)

            // 2. Compile to .mlmodelc (required by Core ML)
            let compiledURL = try await MLModel.compileModel(at: tempURL)

            // 3. Move compiled model to permanent app support location
            let permanentURL = try moveToAppSupport(compiledURL, version: version)

            // 4. Hot-swap the live ClassifierEngine — no restart needed
            await MainActor.run {
                ClassifierEngine.shared.loadModel(from: permanentURL)
                activeVersion = version
                latestVersion = version
                updateAvailable = false
                isDownloading = false
                justUpdated = true
            }

            // Clear the toast after 4 seconds
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run { justUpdated = false }

        } catch {
            await MainActor.run { isDownloading = false }
        }
    }

    private func moveToAppSupport(_ compiledURL: URL, version: String) throws -> URL {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw URLError(.fileDoesNotExist)
        }
        let modelsDir = appSupport.appendingPathComponent("Models")
        try fm.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        let destination = modelsDir.appendingPathComponent("TransactionClassifier-\(version).mlmodelc")
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: compiledURL, to: destination)
        return destination
    }
}
