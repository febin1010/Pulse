//
//  ContentView.swift
//  Pulse
//
//  Created by Febin Cherian on 27/06/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }

            TransactionListView()
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }

            InsightsView()
                .tabItem { Label("Insights", systemImage: "lightbulb.fill") }

            CashFlowView()
                .tabItem { Label("Cash Flow", systemImage: "chart.line.uptrend.xyaxis") }

            ModelStatusView()
                .tabItem { Label("AI Model", systemImage: "cpu.fill") }
        }
    }
}
