// File: Shared/Components/TabBarView.swift
// Final fixed version

import SwiftUI

struct TabBarView: View {
    @State private var selectedTab = 0
    @StateObject private var messagingService = MessagingService.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            SearchTabView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .tag(1)
            
            PortfolioView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Portfolio")
                }
                .tag(2)
            
            MessagingTabView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Messages")
                }
                .badge(messagingService.unreadCount > 0 ? "\(messagingService.unreadCount)" : nil)
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(4)
        }
        .accentColor(.arkadGold)
    }
}

// Wrapper views to avoid naming conflicts with existing views
struct SearchTabView: View {
    var body: some View {
        SearchView()
    }
}

struct MessagingTabView: View {
    var body: some View {
        MessagingView()
    }
}

#Preview {
    TabBarView()
        .environmentObject(AuthViewModel())
}
