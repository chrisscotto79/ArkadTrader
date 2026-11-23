// File: Core/Home/Views/Feeds/FollowingFeedView.swift
// Posts, public trades and activity from people the user follows.

import SwiftUI

/// The Home tab's Following feed. HomeView owns the view model and the
/// surrounding ScrollView / pull-to-refresh.
struct FollowingFeedView: View {
    @ObservedObject var viewModel: FollowingFeedViewModel
    @ObservedObject private var postStore = PostStore.shared
    @ObservedObject private var blockStore = BlockStore.shared
    @EnvironmentObject var authService: FirebaseAuthService

    var body: some View {
        let items = combinedFeedItems

        LazyVStack(spacing: DS.Spacing.m) {
            if viewModel.isLoading && !viewModel.hasLoaded {
                HomeFeedLoadingView(message: "Loading people you follow…")
            } else if let loadError = viewModel.loadError, items.isEmpty {
                EmptyStateView(
                    systemImage: "wifi.exclamationmark",
                    title: "Couldn't load Following",
                    message: loadError,
                    actionTitle: "Try again"
                ) {
                    Task { await viewModel.refreshContent() }
                }
            } else if items.isEmpty {
                EmptyFollowingView()
            } else {
                ForEach(items, id: \.id) { item in
                    FeedItemView(item: item)
                }
            }
        }
        .padding(.horizontal, DS.pageMargin)
        .task {
            if !viewModel.hasLoaded {
                await viewModel.loadFollowingContent()
            }
        }
    }

    /// Posts, trades and activity mixed together, newest first. Deleted, reported and blocked
    /// posts are left out.
    private var combinedFeedItems: [FeedItem] {
        var items: [FeedItem] = []
        items.append(contentsOf: postStore.visible(viewModel.followingPosts).map { FeedItem.post($0) })
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

    var body: some View {
        switch item {
        case .post(let post):
            UserPostCard(post: post)
        case .trade(let trade):
            TradeCardView(trade: trade)
        case .activity(let activity):
            ActivityCardView(activity: activity)
        }
    }
}
