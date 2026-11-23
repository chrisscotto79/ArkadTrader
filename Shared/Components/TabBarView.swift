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
///
/// Deep links (from notification taps) go through `open(_:)`. It switches tab and, when the
/// tab itself has to show something specific, leaves the link in `pendingDeepLink`. The tab
/// that handles it reads it in `onAppear` and `onChange(of:)`, then sets it back to nil:
/// - `.community`, `.channel`: Communities tab
/// - `.post`: Home tab (HomeView opens the post's comments)
/// - `.learn`, `.watchlist`: Discover tab
/// - `.profile` for another user: TabBarView shows their profile
@MainActor
final class TabRouter: ObservableObject {
    static let shared = TabRouter()

    @Published var selected: AppTab = .home
    @Published var pendingDeepLink: DeepLink?

    func open(_ link: DeepLink) {
        switch link {
        case .community, .channel:
            selected = .communities
            pendingDeepLink = link
        case .post:
            selected = .home
            pendingDeepLink = link
        case .profile(let userId):
            if let userId, userId != FirebaseAuthService.shared.currentUser?.id {
                pendingDeepLink = link
            } else {
                selected = .profile
                pendingDeepLink = nil
            }
        case .portfolio:
            selected = .portfolio
            pendingDeepLink = nil
        case .learn, .watchlist:
            selected = .search
            pendingDeepLink = link
        }
    }

    /// Back to a clean state, for example after signing out.
    func reset() {
        selected = .home
        pendingDeepLink = nil
    }
}

struct TabBarView: View {
    @EnvironmentObject private var authService: FirebaseAuthService
    @ObservedObject private var tabRouter = TabRouter.shared
    @State private var linkedProfile: User?

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
        .sheet(item: $linkedProfile) { user in
            OtherUserProfileView(user: user)
                .environmentObject(authService)
        }
        .onAppear { openLinkedProfile(tabRouter.pendingDeepLink) }
        .onChange(of: tabRouter.pendingDeepLink) { _, link in
            openLinkedProfile(link)
        }
    }

    /// Another user's profile has no tab of its own, so it opens here as a sheet.
    private func openLinkedProfile(_ link: DeepLink?) {
        guard case .profile(let userId?) = link else { return }
        tabRouter.pendingDeepLink = nil
        Task {
            if let user = try? await FirebaseServices.shared.getUserById(userId: userId) {
                linkedProfile = user
            }
        }
    }
}

#Preview {
    TabBarView()
        .environmentObject(FirebaseAuthService.shared)
}
