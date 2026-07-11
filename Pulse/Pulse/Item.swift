//
//  Transaction.swift
//  Pulse
//
//  Created by Febin Cherian on 27/06/26.
//

import SwiftData
import Foundation

@Model
class Transaction {
    var id: UUID
    var amount: Double
    var merchantName: String
    var date: Date
    var category: String?
    var isAnomaly: Bool
    var anomalyScore: Double
    var userCorrectedCategory: String?

    init(amount: Double, merchantName: String, date: Date) {
        self.id = UUID()
        self.amount = amount
        self.merchantName = merchantName
        self.date = date
        self.isAnomaly = false
        self.anomalyScore = 0.0
    }

    var displayCategory: String {
        userCorrectedCategory ?? category ?? "other"
    }

    var categoryEmoji: String {
        switch displayCategory {
        case "food":          return "🍔"
        case "transport":     return "🚗"
        case "bills":         return "📄"
        case "entertainment": return "🎬"
        default:              return "💳"
        }
    }
}
