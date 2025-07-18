//
//  Untitled.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/16/25.
//

import SwiftUI

struct FollowingFeedView: View {
    @StateObject private var viewModel = FollowingFeedViewModel()
    @StateObject private var homeViewModel = HomeViewModel()  // ADD THIS LINE
    @EnvironmentObject var authService: FirebaseAuthService

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView("Loading following content...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 50)
                } else if viewModel.followingPosts.isEmpty && viewModel.followingTrades.isEmpty {
                    EmptyFollowingView()
                } else {
                    // Mixed content feed
                    ForEach(combinedFeedItems, id: \.id) { item in
                        FeedItemView(item: item)
                    }
                }
            }
            .padding(.horizontal)
        }
        .refreshable {
            await viewModel.refreshContent()
        }
        .onAppear {
            Task {
                await viewModel.loadFollowingContent()
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.showError = false }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private var combinedFeedItems: [FeedItem] {
        var items: [FeedItem] = []
        
        // Add posts
        items.append(contentsOf: viewModel.followingPosts.map { FeedItem.post($0) })
        
        // Add trades
        items.append(contentsOf: viewModel.followingTrades.map { FeedItem.trade($0) })
        
        // Add activities
        items.append(contentsOf: viewModel.followingActivity.map { FeedItem.activity($0) })
        
        // Sort by creation date
        return items.sorted { $0.createdAt > $1.createdAt }
    }
}

enum FeedItem: Identifiable {
    case post(Post)
    case trade(Trade)
    case activity(ActivityItem)
    
    var id: String {
        switch self {
        case .post(let post): return "post_\(post.id)"
        case .trade(let trade): return "trade_\(trade.id)"
        case .activity(let activity): return "activity_\(activity.id)"
        }
    }
    
    var createdAt: Date {
        switch self {
        case .post(let post): return post.createdAt
        case .trade(let trade): return trade.entryDate
        case .activity(let activity): return activity.createdAt
        }
    }
}

struct FeedItemView: View {
    let item: FeedItem
    
    var body: some View {
        switch item {
        case .post(let post):
            UserPostCard(post: post, homeViewModel:HomeViewModel())  // CHANGE THIS LINE
        case .trade(let trade):
            TradeCardView(trade: trade)
        case .activity(let activity):
            ActivityCardView(activity: activity)
        }
    }
}


