// File: Shared/Components/TabBarView.swift
// The app's five main tabs.

import SwiftUI

/// The app's main tabs, in display order.
enum AppTab: Hashable {
    case home
    case search
    case portfolio
    case communities
    case profile
}

/// App-wide tab selection. Injected by TabBarView as an environment object so
/// any screen can switch tabs (e.g. "Discover Traders" -> Search).
final class TabRouter: ObservableObject {
    @Published var selected: AppTab = .home
}

struct TabBarView: View {
    @StateObject private var tabRouter = TabRouter()

    var body: some View {
        TabView(selection: $tabRouter.selected) {
            HomeView()
                .tabItem { Label("Home", systemImage: tabRouter.selected == .home ? "house.fill" : "house") }
                .tag(AppTab.home)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(AppTab.search)

            PortfolioView()
                .tabItem { Label("Portfolio", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.portfolio)

            CommunitiesView()
                .tabItem { Label("Communities", systemImage: tabRouter.selected == .communities ? "person.3.fill" : "person.3") }
                .tag(AppTab.communities)

            ProfileView()
                .tabItem { Label("Profile", systemImage: tabRouter.selected == .profile ? "person.fill" : "person") }
                .tag(AppTab.profile)
        }
        // Brand gold (Resources/assets.xcassets/AccentColor) for the selected tab
        .tint(.accentColor)
        .environmentObject(tabRouter)
    }
}

#Preview {
    TabBarView()
        .environmentObject(FirebaseAuthService.shared)
}
