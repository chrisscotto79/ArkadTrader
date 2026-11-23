// File: Core/Search/Views/SearchResultView.swift
// One Discover result (trader, post, trade or community) and the sheet it opens.

import SwiftUI

struct SearchResultView: View {
    /// `.row` sits inside a grouped card; `.communityCard` is the larger tile used in Discover's carousel.
    enum Style {
        case row
        case communityCard
    }

    let result: SearchResult
    var style: Style = .row
    /// Called when the result is opened (Discover saves the search then)
    var onOpen: (() -> Void)? = nil
    @EnvironmentObject private var authService: FirebaseAuthService

    // Navigation states
    @State private var showUserProfile = false
    @State private var showPostDetail = false
    @State private var showTradeDetail = false
    @State private var showCommunityDetail = false
    @State private var isLoadingUser = false
    @State private var profileUser: User?

    // Community sheet states
    @State private var isJoiningCommunity = false
    @State private var paidCommunityToOpen: Community?
    @State private var hasJoinedCommunity = false
    @State private var joinErrorMessage: String?
    @State private var showFullCommunity = false

    var body: some View {
        Button(action: handleResultTap) {
            switch style {
            case .row:
                rowLabel
            case .communityCard:
                communityCardLabel
            }
        }
        .buttonStyle(PressableStyle())
        .sheet(isPresented: $showUserProfile) {
            userProfileSheet
        }
        .sheet(isPresented: $showPostDetail) {
            postDetailSheet
        }
        .sheet(isPresented: $showTradeDetail) {
            tradeDetailSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCommunityDetail) {
            communityDetailSheet
        }
    }

    // MARK: - Row

    private var rowLabel: some View {
        HStack(spacing: DS.Spacing.m) {
            resultIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(primaryText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(result.type == .post ? 2 : 1)
                        .multilineTextAlignment(.leading)
                    if result.type == .user, result.user?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Color.goldText)
                            .accessibilityLabel("Verified")
                    }
                    if result.type == .group, result.community?.isPrivate == true {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Private")
                    }
                }

                Text(secondaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DS.Spacing.s)

            trailingAccessory
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if isLoadingUser && result.type == .user {
            ProgressView().controlSize(.small)
        } else if result.type == .trade, let trade = result.trade, !trade.isOpen {
            ChangePill(
                text: String(format: "%+.1f%%", trade.profitLossPercentage),
                isPositive: trade.profitLossPercentage >= 0
            )
        } else if result.type == .trade {
            Tag(text: "Open", tint: .goldText)
        } else {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Community card (Discover carousel)

    private var communityCardLabel: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(alignment: .top) {
                if let community = result.community {
                    DiscoverCommunityAvatar(community: community, size: 48)
                }
                Spacer(minLength: 0)
                if let community = result.community, isCommunityMember(community) {
                    Tag(text: "Joined", systemImage: "checkmark")
                } else if result.community?.isPrivate == true {
                    Tag(text: "Private", systemImage: "lock.fill", tint: .secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(result.community?.name ?? "Community")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Text(communityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }

            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                Text(memberCountText)
                    .font(.caption.weight(.semibold).monospacedDigit())
                if let type = result.community?.type {
                    Text("· \(type.shortDisplayName)")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
        }
        .frame(width: 220, alignment: .leading)
        .cardStyle(padding: 14)
        .accessibilityElement(children: .combine)
    }

    private var communityDescription: String {
        let text = result.community?.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? (result.community?.type.displayName ?? "") : text
    }

    private var memberCountText: String {
        let count = result.community?.memberCount ?? 0
        return "\(count.formatted(.number.notation(.compactName))) member\(count == 1 ? "" : "s")"
    }

    // MARK: - Result Icon
    @ViewBuilder
    private var resultIcon: some View {
        switch result.type {
        case .user:
            UserAvatar(username: result.user?.username ?? "user", fullName: result.user?.fullName, imageURL: result.user?.profileImageUrl, size: 44)

        case .post:
            IconWell(systemName: "text.bubble.fill", tint: .info, size: 44)

        case .trade:
            IconWell(systemName: tradeIcon, tint: tradeColor, size: 44)

        case .group:
            if let community = result.community {
                DiscoverCommunityAvatar(community: community, size: 44)
            } else {
                IconWell(systemName: "person.3.fill", size: 44)
            }
        }
    }

    // MARK: - Text Content
    private var primaryText: String {
        switch result.type {
        case .user:
            if let user = result.user, !user.fullName.isEmpty { return user.fullName }
            return result.user?.username ?? "Trader"
        case .post:
            return String(result.post?.displayContent.prefix(120) ?? "Post")
        case .trade:
            return "\(result.trade?.ticker ?? "Trade") · \(result.trade?.tradeType.displayName ?? "")"
        case .group:
            return result.community?.name ?? "Community"
        }
    }

    private var secondaryText: String {
        switch result.type {
        case .user:
            guard let user = result.user else { return "" }
            var parts = ["@\(user.username)"]
            parts.append("\(user.followersCount.formatted(.number.notation(.compactName))) follower\(user.followersCount == 1 ? "" : "s")")
            if user.winRate > 0 {
                parts.append("\(String(format: "%.0f%%", user.winRate)) win rate")
            }
            return parts.joined(separator: " · ")

        case .post:
            guard let post = result.post else { return "" }
            var parts = ["@\(post.authorUsername)", post.createdAt.feedRelativeText]
            if post.likesCount > 0 { parts.append("\(post.likesCount) like\(post.likesCount == 1 ? "" : "s")") }
            if post.commentsCount > 0 { parts.append("\(post.commentsCount) comment\(post.commentsCount == 1 ? "" : "s")") }
            return parts.joined(separator: " · ")

        case .trade:
            guard let trade = result.trade else { return "" }
            if trade.isOpen {
                return "Entry \(trade.entryPrice.formatted(.currency(code: "USD"))) · \(trade.entryDate.feedRelativeText)"
            }
            return "Closed \((trade.exitDate ?? trade.entryDate).formatted(date: .abbreviated, time: .omitted)) · \(trade.profitLoss.asCurrencyWithSign)"

        case .group:
            guard let community = result.community else { return "" }
            return "\(community.type.shortDisplayName) · \(memberCountText)"
        }
    }

    // MARK: - Colors
    private var tradeColor: Color {
        if let trade = result.trade, !trade.isOpen {
            return trade.profitLossPercentage >= 0 ? .marketGreen : .marketRed
        }
        return .goldText
    }

    private var tradeIcon: String {
        if let trade = result.trade, !trade.isOpen, trade.profitLossPercentage < 0 {
            return "chart.line.downtrend.xyaxis"
        }
        return "chart.line.uptrend.xyaxis"
    }

    // MARK: - Navigation Actions
    private func handleResultTap() {
        onOpen?()
        switch result.type {
        case .user:
            handleUserTap()
        case .post:
            showPostDetail = true
        case .trade:
            showTradeDetail = true
        case .group:
            showCommunityDetail = true
        }
    }

    private func handleUserTap() {
        guard let user = result.user else { return }

        // Your own profile lives in the Profile tab
        if let currentUser = authService.currentUser, currentUser.id == user.id {
            return
        }

        Task {
            await loadUserProfile()
        }
    }

    private func loadUserProfile() async {
        guard let user = result.user else { return }

        guard profileUser == nil else {
            showUserProfile = true
            return
        }

        isLoadingUser = true

        do {
            if let fullUser = try await authService.getUserById(userId: user.id) {
                profileUser = fullUser
            } else {
                profileUser = createMinimalUser()
            }
        } catch {
            profileUser = createMinimalUser()
        }

        isLoadingUser = false
        showUserProfile = true
    }

    private func createMinimalUser() -> User {
        guard let user = result.user else {
            return User(id: "", email: "", username: "", fullName: "")
        }

        // Built only from the search result itself; no invented details.
        var minimalUser = User(
            id: user.id,
            email: "",
            username: user.username,
            fullName: user.fullName
        )

        minimalUser.bio = user.bio
        minimalUser.profileImageUrl = user.profileImageUrl
        minimalUser.followersCount = user.followersCount
        minimalUser.followingCount = user.followingCount
        minimalUser.totalProfitLoss = user.totalProfitLoss
        minimalUser.winRate = user.winRate

        return minimalUser
    }

    // MARK: - Sheet Views
    @ViewBuilder
    private var userProfileSheet: some View {
        if let profileUser = profileUser {
            OtherUserProfileView(user: profileUser)
                .environmentObject(authService)
        } else {
            EmptyStateView(
                systemImage: "person.crop.circle.badge.exclamationmark",
                title: "Couldn't load profile",
                message: "@\(result.user?.username ?? "unknown")",
                actionTitle: "Close"
            ) {
                showUserProfile = false
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var postDetailSheet: some View {
        NavigationStack {
            ScrollView {
                if let post = result.post {
                    SearchPostDetail(post: post)
                        .environmentObject(authService)
                        .padding(.horizontal, DS.pageMargin)
                        .padding(.vertical, DS.Spacing.s)
                } else {
                    EmptyStateView(
                        systemImage: "text.bubble",
                        title: "Post unavailable",
                        message: "This post couldn't be loaded."
                    )
                }
            }
            .screenBackground()
            .postStoreFeedback()
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showPostDetail = false }
                }
            }
        }
    }

    @ViewBuilder
    private var tradeDetailSheet: some View {
        NavigationStack {
            ScrollView {
                if let trade = result.trade {
                    tradeDetailContent(trade)
                        .padding(.horizontal, DS.pageMargin)
                        .padding(.vertical, DS.Spacing.s)
                } else {
                    EmptyStateView(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "Trade unavailable",
                        message: "This trade couldn't be loaded."
                    )
                }
            }
            .screenBackground()
            .navigationTitle("Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showTradeDetail = false }
                }
            }
        }
    }

    private func tradeDetailContent(_ trade: Trade) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(alignment: .center, spacing: DS.Spacing.m) {
                IconWell(systemName: tradeIcon, tint: tradeColor, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(trade.ticker)
                        .font(.title.weight(.bold))
                    HStack(spacing: 6) {
                        Tag(text: trade.tradeType.displayName, tint: .secondary)
                        Tag(
                            text: trade.isOpen ? "Open" : "Closed",
                            tint: trade.isOpen ? .goldText : .secondary
                        )
                    }
                }
                Spacer(minLength: 0)
            }

            WatchTickerButton(
                symbol: trade.ticker,
                assetType: trade.tradeType == .option ? .stock : trade.tradeType
            )

            // The ticker's page: posts, sentiment and price (cashtag-style symbols only)
            let symbol = TickerFeedService.normalize(trade.ticker)
            if TickerFeedService.isTickerSymbol(symbol) {
                HStack(spacing: DS.Spacing.s) {
                    Text("See what traders are saying")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    TickerLink(symbol: symbol)
                }
            }

            if !trade.isOpen {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Profit / loss")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
                        Text(trade.profitLoss.asCurrencyWithSign)
                            .arkadNumber(30)
                            .foregroundStyle(trade.profitLoss >= 0 ? Color.marketGreen : Color.marketRed)
                        ChangePill(
                            text: String(format: "%+.2f%%", trade.profitLossPercentage),
                            isPositive: trade.profitLoss >= 0
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.m), GridItem(.flexible())], spacing: DS.Spacing.m) {
                StatTile(title: "Entry price", value: trade.entryPrice.formatted(.currency(code: "USD")))
                if let exitPrice = trade.exitPrice, !trade.isOpen {
                    StatTile(title: "Exit price", value: exitPrice.formatted(.currency(code: "USD")))
                }
                StatTile(title: trade.tradeType == .option ? "Contracts" : "Shares", value: trade.quantity.quantityString)
                StatTile(title: "Entry date", value: trade.entryDate.formatted(date: .abbreviated, time: .omitted))
                if let exitDate = trade.exitDate, !trade.isOpen {
                    StatTile(title: "Exit date", value: exitDate.formatted(date: .abbreviated, time: .omitted))
                }
            }

            if let notes = trade.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(notes)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
        }
    }

    @ViewBuilder
    private var communityDetailSheet: some View {
        NavigationStack {
            ScrollView {
                if let community = result.community {
                    communityDetailContent(community)
                        .padding(.horizontal, DS.pageMargin)
                        .padding(.vertical, DS.Spacing.l)
                } else {
                    EmptyStateView(
                        systemImage: "person.3",
                        title: "Community unavailable",
                        message: "This community couldn't be loaded."
                    )
                }
            }
            .screenBackground()
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showCommunityDetail = false }
                }
            }
            .navigationDestination(isPresented: $showFullCommunity) {
                if let community = result.community {
                    CommunityDetailView(community: community)
                        .environmentObject(authService)
                }
            }
        }
    }

    private func communityDetailContent(_ community: Community) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.m) {
                DiscoverCommunityAvatar(community: community, size: 76)

                Text(community.name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    Tag(text: community.type.shortDisplayName, tint: .secondary)
                    Tag(text: memberCountText, systemImage: "person.2.fill", tint: .secondary)
                    Tag(
                        text: community.isPrivate ? "Private" : "Public",
                        systemImage: community.isPrivate ? "lock.fill" : "globe",
                        tint: .secondary
                    )
                }
            }

            if !community.description.isEmpty {
                Text(community.description)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .cardStyle()
            }

            communityActions(community)
        }
    }

    private func communityActions(_ community: Community) -> some View {
        VStack(spacing: DS.Spacing.m) {
            if isCommunityMember(community) {
                Label("You're a member", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.marketGreen)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            } else if community.isPrivate {
                Text("This community is private. Members can invite you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            } else if community.requiresSubscription {
                // Paid communities are joined by subscribing from their page
                Button {
                    paidCommunityToOpen = community
                } label: {
                    Text("View · \(community.priceTagText ?? "Paid")")
                }
                .buttonStyle(PrimaryButtonStyle())
                .sheet(item: $paidCommunityToOpen) { paid in
                    NavigationStack {
                        CommunityDetailView(community: paid)
                    }
                    .environmentObject(authService)
                }
            } else {
                Button {
                    Task { await join(community) }
                } label: {
                    HStack(spacing: DS.Spacing.s) {
                        if isJoiningCommunity {
                            ProgressView().tint(Color.onGold)
                        }
                        Text(isJoiningCommunity ? "Joining…" : "Join community")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isJoiningCommunity)
            }

            if let joinErrorMessage {
                Text(joinErrorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.marketRed)
                    .multilineTextAlignment(.center)
            }

            if !community.isPrivate || isCommunityMember(community) {
                Button("View community") {
                    showFullCommunity = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    // MARK: - Community Actions

    private func isCommunityMember(_ community: Community) -> Bool {
        hasJoinedCommunity || (authService.currentUser?.communityIds.contains(community.id) ?? false)
    }

    @MainActor
    private func join(_ community: Community) async {
        guard let userId = authService.currentUser?.id else {
            joinErrorMessage = "You need to be signed in to join."
            return
        }
        guard !isCommunityMember(community) else { return }

        isJoiningCommunity = true
        joinErrorMessage = nil
        do {
            try await authService.joinCommunity(communityId: community.id, userId: userId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.snappy(duration: 0.25)) {
                hasJoinedCommunity = true
            }
            await authService.refreshCurrentUser()
        } catch {
            joinErrorMessage = "Couldn't join: \(error.localizedDescription)"
        }
        isJoiningCommunity = false
    }
}

// MARK: - Post detail

/// A post opened from Discover. Likes, bookmarks and counts come from PostStore, like every
/// other card; once deleted or reported it shows a note instead.
private struct SearchPostDetail: View {
    let post: Post
    @ObservedObject private var store = PostStore.shared

    var body: some View {
        if store.isVisible(post) {
            UserPostCard(post: post)
                .task { await store.loadIfNeeded() }
        } else {
            EmptyStateView(
                systemImage: "text.bubble",
                title: "Post unavailable",
                message: "This post was deleted or hidden."
            )
        }
    }
}

// MARK: - Watchlist button

/// "Add to watchlist" for a trade's ticker. An option's ticker is its underlying, so callers
/// pass `.stock` for options.
private struct WatchTickerButton: View {
    let symbol: String
    let assetType: TradeType
    @ObservedObject private var watchlist = WatchlistStore.shared
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var normalized: String { WatchlistSymbol.normalize(symbol) }

    var body: some View {
        if WatchlistSymbol.isValid(normalized) {
            let isWatching = watchlist.contains(normalized)
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Button {
                    toggle(isWatching: isWatching)
                } label: {
                    HStack(spacing: DS.Spacing.s) {
                        if isWorking {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: isWatching ? "checkmark" : "star")
                        }
                        Text(isWatching ? "On your watchlist" : "Add \(normalized) to watchlist")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isWorking)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.marketRed)
                }
            }
            .task {
                if !watchlist.hasLoaded { await watchlist.load() }
            }
        }
    }

    private func toggle(isWatching: Bool) {
        isWorking = true
        errorMessage = nil
        Task {
            do {
                if isWatching {
                    if let item = watchlist.items.first(where: { $0.symbol == normalized }) {
                        try await watchlist.remove(item)
                    }
                } else {
                    try await watchlist.add(symbol: normalized, assetType: assetType)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

// MARK: - Community avatar

/// Same avatar as the Communities tab, so a community looks identical everywhere.
private struct DiscoverCommunityAvatar: View {
    let community: Community
    var size: CGFloat = 44

    var body: some View {
        CommunityAvatar(community: community, size: size)
    }
}

#Preview {
    let sampleUser = User(id: "1", email: "test@example.com", username: "testuser", fullName: "Test User")
    let sampleResult = SearchResult(user: sampleUser)

    SearchResultView(result: sampleResult)
        .cardStyle(padding: 0)
        .environmentObject(FirebaseAuthService.shared)
        .padding()
        .screenBackground()
}
