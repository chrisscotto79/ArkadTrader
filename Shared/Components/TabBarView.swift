// File: Shared/Components/TabBarView.swift
// The app's five main tabs.

import SwiftUI

struct TabBarView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house") }
                .tag(0)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(1)

            PortfolioView()
                .tabItem { Label("Portfolio", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(2)

            CommunitiesView()
                .tabItem { Label("Communities", systemImage: selectedTab == 3 ? "person.3.fill" : "person.3") }
                .tag(3)

            ProfileView()
                .tabItem { Label("Profile", systemImage: selectedTab == 4 ? "person.fill" : "person") }
                .tag(4)
        }
        // Brand gold (Resources/assets.xcassets/AccentColor) for the selected tab
        .tint(.accentColor)
    }
}

#Preview {
    TabBarView()
        .environmentObject(FirebaseAuthService.shared)
}
