// File: Core/Search/Views/SearchView.swift

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var selectedSearchType = 0 // 0 = Users, 1 = Trades, 2 = Posts
    
    // Mock data for search results
    @State private var mockUsers: [User] = [
        User(email: "john@example.com", username: "johndoe", fullName: "John Doe"),
        User(email: "jane@example.com", username: "janetrader", fullName: "Jane Smith"),
        User(email: "mike@example.com", username: "mikeinvests", fullName: "Mike Johnson"),
        User(email: "sarah@example.com", username: "sarahstocks", fullName: "Sarah Williams")
    ]
    
    var filteredUsers: [User] {
        if searchText.isEmpty {
            return []
        }
        return mockUsers.filter { user in
            user.username.localizedCaseInsensitiveContains(searchText) ||
            user.fullName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search users, stocks, or traders...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top)
                
                // Search Type Selector
                Picker("Search Type", selection: $selectedSearchType) {
                    Text("Users").tag(0)
                    Text("Trades").tag(1)
                    Text("Posts").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Search Results or Trending
                if searchText.isEmpty {
                    // Show trending when no search
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Trending Stocks
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Trending Stocks")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(["AAPL", "TSLA", "NVDA", "SPY", "QQQ"], id: \.self) { ticker in
                                    TrendingStockRow(ticker: ticker)
                                }
                            }
                            
                            // Popular Traders
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Popular Traders")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(mockUsers.prefix(3)) { user in
                                    PopularTraderRow(user: user)
                                }
                            }
                        }
                        .padding(.top)
                    }
                } else {
                    // Show search results
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if selectedSearchType == 0 {
                                // User search results
                                ForEach(filteredUsers) { user in
                                    UserSearchResultRow(user: user)
                                }
                                
                                if filteredUsers.isEmpty {
                                    Text("No users found")
                                        .foregroundColor(.gray)
                                        .padding(.top, 40)
                                }
                            } else if selectedSearchType == 1 {
                                // Trade search placeholder
                                Text("Trade search coming soon")
                                    .foregroundColor(.gray)
                                    .padding(.top, 40)
                            } else {
                                // Post search placeholder
                                Text("Post search coming soon")
                                    .foregroundColor(.gray)
                                    .padding(.top, 40)
                            }
                        }
                        .padding(.top)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Supporting Views
struct TrendingStockRow: View {
    let ticker: String
    
    var body: some View {
        HStack {
            Text(ticker)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            // Mock price change
            Text("+\(Int.random(in: 1...5)).\(Int.random(in: 0...99))%")
                .font(.subheadline)
                .foregroundColor(.marketGreen)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2)
        .padding(.horizontal)
    }
}

struct PopularTraderRow: View {
    let user: User
    @State private var isFollowing = false
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.arkadGold.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(initials)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName)
                    .font(.headline)
                
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: { isFollowing.toggle() }) {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isFollowing ? Color.gray.opacity(0.2) : Color.arkadGold)
                    .foregroundColor(isFollowing ? .primary : .arkadBlack)
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2)
        .padding(.horizontal)
    }
    
    private var initials: String {
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first ?? Character("") : Character("")
        return String(firstInitial) + String(lastInitial)
    }
}

struct UserSearchResultRow: View {
    let user: User
    @State private var isFollowing = false
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.arkadGold.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(initials)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: { isFollowing.toggle() }) {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isFollowing ? Color.gray.opacity(0.2) : Color.arkadGold)
                    .foregroundColor(isFollowing ? .primary : .arkadBlack)
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var initials: String {
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first ?? Character("") : Character("")
        return String(firstInitial) + String(lastInitial)
    }
}

#Preview {
    SearchView()
}
