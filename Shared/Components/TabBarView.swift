//
//  TabBarView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Shared/Components/TabBarView.swift

// File: Shared/Components/TabBarView.swift

import SwiftUI

struct TabBarView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            PortfolioView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Portfolio")
                }
                .tag(1)
            
            LeaderboardView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("Leaderboard")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(3)
        }
        .accentColor(.arkadGold)
    }
}

#Preview {
    TabBarView()
        .environmentObject(AuthViewModel())
}
