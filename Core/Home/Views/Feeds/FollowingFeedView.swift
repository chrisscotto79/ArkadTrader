// File: Core/Home/Views/Feeds/FollowingFeedView.swift
// Posts, public trades and activity from people the user follows.

import SwiftUI

/// The Home tab's Following feed. HomeView owns the view models and the
/// surrounding ScrollView / pull-to-refresh.
struct FollowingFeedView: View {
    @ObservedObject var viewModel: FollowingFeedViewModel
    @ObservedObject var homeViewModel: HomeViewModel
    @EnvironmentObject var authService: FirebaseAuthService

    var body: some View {
        LazyVStack(spacing: DS.Spacing.m) {
            if viewModel.isLoading && !viewModel.hasLoaded {
                HomeFeedLoadingView(message: "Loading people you follow…")
            } else if viewModel.followingPosts.isEmpty && viewModel.followingTrades.isEmpty && viewModel.followingActivity.isEmpty {
                EmptyFollowingView()
            } else {
                ForEach(combinedFeedItems, id: \.id) { item in
                    FeedItemView(item: item, homeViewModel: homeViewModel)
                }
            }
        }
        .padding(.horizontal, DS.pageMargin)
        .task {
            if !viewModel.hasLoaded {
                await viewModel.loadFollowingContent()
            }
        }
        .alert("Couldn't load Following", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.showError = false }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    /// Posts, trades and activity mixed together, newest first.
    private var combinedFeedItems: [FeedItem] {
        var items: [FeedItem] = []
        items.append(contentsOf: viewModel.followingPosts.map { FeedItem.post($0) })
        items.append(contentsOf: viewModel.followingTrades.map { FeedItem.trade($0) })
        items.append(contentsOf: viewModel.followingActivity.map { FeedItem.activity($0) })
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

/// One item of the Following feed, drawn with the matching card.
struct FeedItemView: View {
    let item: FeedItem
    @ObservedObject var homeViewModel: HomeViewModel

    var body: some View {
        switch item {
        case .post(let post):
            UserPostCard(post: post, homeViewModel: homeViewModel)
        case .trade(let trade):
            TradeCardView(trade: trade)
        case .activity(let activity):
            ActivityCardView(activity: activity)
        }
    }
}
