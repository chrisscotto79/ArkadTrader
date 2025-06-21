// File: Core/Home/Views/HomeView.swift

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0 // 0 = Feed, 1 = News
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Feed/News Toggle
                HStack(spacing: 0) {
                    Button(action: { selectedTab = 0 }) {
                        Text("Feed")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedTab == 0 ? Color.arkadGold : Color.clear)
                            .foregroundColor(selectedTab == 0 ? .arkadBlack : .gray)
                    }
                    
                    Button(action: { selectedTab = 1 }) {
                        Text("News")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedTab == 1 ? Color.arkadGold : Color.clear)
                            .foregroundColor(selectedTab == 1 ? .arkadBlack : .gray)
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Content based on selection
                if selectedTab == 0 {
                    // Social Feed
                    SocialFeedView()
                } else {
                    // Market News Feed
                    MarketNewsFeedView()
                }
                
                Spacer()
            }
            .navigationTitle("ArkadTrader")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Market sentiment indicator
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.marketGreen)
                            .font(.title2)
                        Text("Bullish")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.marketGreen)
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
