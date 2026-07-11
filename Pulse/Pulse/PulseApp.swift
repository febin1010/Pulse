//
//  PulseApp.swift
//  Pulse
//
//  Created by Febin Cherian on 27/06/26.
//

import SwiftUI
import SwiftData

@main
struct PulseApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Transaction.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    clearSeedDataIfNeeded(container: sharedModelContainer)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await ModelSyncService.shared.checkForUpdates() }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

private func clearSeedDataIfNeeded(container: ModelContainer) {
    let key = "didClearSeedData_v4"
    guard !UserDefaults.standard.bool(forKey: key) else { return }

    let context = container.mainContext
    let descriptor = FetchDescriptor<Transaction>()
    let existing = (try? context.fetch(descriptor)) ?? []

    let seedMerchants: Set<String> = [
        "Swiggy", "Ola", "Amazon", "Zomato", "Jio", "Big Bazaar",
        "Rapido", "HDFC EMI", "Auto Rickshaw", "Netflix", "Electricity Bill",
        "Tea Stall", "Blinkit", "Uber", "Flipkart", "Dunzo",
        "Swiggy Instamart", "Apollo Pharmacy"
    ]

    // Delete every transaction whose merchant is in the seed list
    let toDelete = existing.filter { seedMerchants.contains($0.merchantName) }
    toDelete.forEach { context.delete($0) }
    if !toDelete.isEmpty {
        try? context.save()
        UserDefaults.standard.removeObject(forKey: "cachedInsights")
        UserDefaults.standard.removeObject(forKey: "cachedInsightsDate")
    }

    UserDefaults.standard.set(true, forKey: key)
}
