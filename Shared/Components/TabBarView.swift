// File: Shared/Components/TabBarView.swift
// Simplified TabBar View

import SwiftUI
struct TabBarView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    VStack {
                        Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                            .font(.title3)
                        Text("Home")
                            .font(.caption2)
                    }
                }
                .tag(0)
            
            SearchView()
                .tabItem {
                    VStack {
                        Image(systemName: selectedTab == 1 ? "magnifyingglass" : "magnifyingglass")
                            .font(.title3)
                        Text("Search")
                            .font(.caption2)
                    }
                }
                .tag(1)
            
            PortfolioView()
                .tabItem {
                    VStack {
                        Image(systemName: selectedTab == 2 ? "chart.line.uptrend.xyaxis" : "chart.line.uptrend.xyaxis")
                            .font(.title3)
                        Text("Portfolio")
                            .font(.caption2)
                    }
                }
                .tag(2)
            
            CommunitiesView()
                .tabItem {
                    VStack {
                        Image(systemName: selectedTab == 3 ? "person.3.fill" : "person.3")
                            .font(.title3)
                        Text("Communities")
                            .font(.caption2)
                    }
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    VStack {
                        Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                            .font(.title3)
                        Text("Profile")
                            .font(.caption2)
                    }
                }
                .tag(4)
        }
        .accentColor(.blue)
        .onAppear {
            // Customize tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            
            // Selected item
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor.systemBlue,
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]
            
            // Unselected item
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor.systemGray,
                .font: UIFont.systemFont(ofSize: 10, weight: .regular)
            ]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    TabBarView()
        .environmentObject(FirebaseAuthService.shared)
}
