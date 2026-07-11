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
                    seedSampleDataIfNeeded(container: sharedModelContainer)
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

private func seedSampleDataIfNeeded(container: ModelContainer) {
    let context = container.mainContext
    let descriptor = FetchDescriptor<Transaction>()
    let count = (try? context.fetchCount(descriptor)) ?? 0
    guard count == 0 else { return }

    let samples: [(Double, String, Int)] = [
        (320, "Swiggy", -1),
        (85, "Ola", -3),
        (1200, "Amazon", -2),
        (450, "Zomato", -5),
        (199, "Jio", -10),
        (650, "Big Bazaar", -7),
        (120, "Rapido", -1),
        (2500, "HDFC EMI", -15),
        (380, "Swiggy", -4),
        (95, "Auto Rickshaw", -2),
        (799, "Netflix", -20),
        (270, "Zomato", -6),
        (1500, "Electricity Bill", -8),
        (60, "Tea Stall", -1),
        (340, "Blinkit", -3),
        (180, "Uber", -9),
        (4200, "Flipkart", -12),
        (550, "Dunzo", -2),
        (300, "Swiggy Instamart", -5),
        (890, "Apollo Pharmacy", -11)
    ]

    for (amount, merchant, daysAgo) in samples {
        let date = Calendar.current.date(byAdding: .day, value: daysAgo, to: Date()) ?? Date()
        let tx = Transaction(amount: amount, merchantName: merchant, date: date)
        context.insert(tx)
    }
    try? context.save()
}
