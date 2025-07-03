// File: Core/Communities/Views/CommunitiesView.swift
// Simple Communities implementation to replace MessagingView

import SwiftUI

struct CommunitiesView: View {
    @State private var searchText = ""
    @State private var selectedTab = 0 // 0 = My Communities, 1 = Discover
    
    // Mock communities for now
    private let mockCommunities = [
        MockCommunity(name: "Day Traders", description: "Fast-paced trading strategies", memberCount: 1247, type: "Day Trading"),
        MockCommunity(name: "Options Masters", description: "Options trading education and strategies", memberCount: 892, type: "Options"),
        MockCommunity(name: "Swing Trading Club", description: "Medium-term position strategies", memberCount: 634, type: "Swing Trading"),
        MockCommunity(name: "Crypto Corner", description: "Digital asset trading community", memberCount: 2156, type: "Crypto"),
        MockCommunity(name: "Stock Analysis Hub", description: "Fundamental and technical analysis", memberCount: 987, type: "Stocks")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                HStack(spacing: 0) {
                    TabButton(title: "My Communities", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabButton(title: "Discover", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding()
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search communities...", text: $searchText)
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
                
                // Communities List
                if selectedTab == 0 {
                    // My Communities (empty for now)
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No Communities Yet")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        
                        Text("Join communities to connect with other traders")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button("Discover Communities") {
                            selectedTab = 1
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadBlack)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.arkadGold)
                        .cornerRadius(8)
                    }
                    .padding(.top, 60)
                } else {
                    // Discover Communities
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredCommunities, id: \.name) { community in
                                CommunityCardView(community: community)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Communities")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.arkadGold)
                    }
                }
            }
        }
    }
    
    private var filteredCommunities: [MockCommunity] {
        if searchText.isEmpty {
            return mockCommunities
        } else {
            return mockCommunities.filter { community in
                community.name.localizedCaseInsensitiveContains(searchText) ||
                community.description.localizedCaseInsensitiveContains(searchText) ||
                community.type.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Mock Community Model
struct MockCommunity {
    let name: String
    let description: String
    let memberCount: Int
    let type: String
}

// MARK: - Community Card View
struct CommunityCardView: View {
    let community: MockCommunity
    @State private var isJoined = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Community Icon
            Circle()
                .fill(Color.arkadGold.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: communityIcon)
                        .font(.title2)
                        .foregroundColor(.arkadGold)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(community.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Spacer()
                }
                
                Text(community.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                
                HStack {
                    Text("\(community.memberCount) members")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(community.type)
                        .font(.caption)
                        .foregroundColor(.arkadGold)
                }
            }
            
            Spacer()
            
            // Join/Leave Button
            Button(action: {
                isJoined.toggle()
            }) {
                Text(isJoined ? "Joined" : "Join")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isJoined ? Color.gray.opacity(0.2) : Color.arkadGold)
                    .foregroundColor(isJoined ? .primary : .arkadBlack)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var communityIcon: String {
        switch community.type {
        case "Day Trading": return "chart.line.uptrend.xyaxis"
        case "Options": return "chart.pie"
        case "Swing Trading": return "chart.bar"
        case "Crypto": return "bitcoinsign.circle"
        case "Stocks": return "building.columns"
        default: return "person.3"
        }
    }
}

// MARK: - Tab Button (Reusable Component)
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? Color.arkadBlack : Color.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.arkadGold : Color.clear)
                .cornerRadius(8)
        }
    }
}

#Preview {
    CommunitiesView()
}
