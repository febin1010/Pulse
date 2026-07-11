//
//  BudgetStore.swift
//  Pulse
//

import Foundation
import Combine

class BudgetStore: ObservableObject {
    static let shared = BudgetStore()

    @Published var budgets: [String: Double] {
        didSet { save() }
    }

    private let key = "pulse_budgets"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            budgets = decoded
        } else {
            budgets = [
                "food": 5000,
                "transport": 2000,
                "bills": 8000,
                "entertainment": 3000,
                "other": 4000
            ]
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(budgets) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
