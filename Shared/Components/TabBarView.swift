// File: Shared/Components/TabBarView.swift
// The app's five main tabs. Communities sits next to Home because it's the heart of Arkad.

import SwiftUI

/// The app's main tabs, in display order.
enum AppTab: Hashable {
    case home
    case communities
    case portfolio
    case search
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
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)

            CommunitiesView()
                .tabItem { Label("Communities", systemImage: "person.3.fill") }
                .tag(AppTab.communities)

            PortfolioView()
                .tabItem { Label("Portfolio", systemImage: "chart.pie.fill") }
                .tag(AppTab.portfolio)

            SearchView()
                .tabItem { Label("Discover", systemImage: "magnifyingglass") }
                .tag(AppTab.search)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
        // Readable gold for the selected tab in both light and dark mode
        .tint(.goldText)
        .environmentObject(tabRouter)
    }
}

#Preview {
    TabBarView()
        .environmentObject(FirebaseAuthService.shared)
}
