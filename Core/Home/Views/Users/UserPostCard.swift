// File: Core/Home/Views/Users/UserPostCard.swift
// A post in the Home feeds: author, text, tickers, trade numbers, photos and a quiet action row.
// Also: TradeSummaryCard (shared with Profile) and the feed's short relative dates.

import SwiftUI

struct UserPostCard: View {
    let post: Post
    /// Likes, bookmarks, counts, deletes and reports, shared by every screen
    @ObservedObject private var store = PostStore.shared
    @State private var showOtherUserProfile = false
    @State private var profileUser: User?
    @State private var isLoadingUser = false
    @State private var showComments = false

    // Delete
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    // Sharing and reporting
    @State private var showShareSheet = false
    @State private var shareMessage = ""
    @State private var showShareConfirmation = false
    @State private var showReportSheet = false
    /// Set once a report is sent; the post is hidden when the report sheet closes
    @State private var didReport = false
    @State private var currentImageIndex = 0

    @EnvironmentObject var authService: FirebaseAuthService

    init(post: Post) {
        self.post = post
    }

    // MARK: - Main Body
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            headerRow
            contentSection
            imageSection
            actionRow
        }
        .cardStyle(padding: DS.Spacing.l)
        .overlay(alignment: .top) { shareConfirmationToast }
        .overlay { deletingOverlay }
        .sheet(isPresented: $showOtherUserProfile) { profileSheet }
        .sheet(isPresented: $showComments) { commentsSheet }
        .sheet(isPresented: $showReportSheet, onDismiss: hideIfReported) { reportSheet }
        .confirmationDialog("Share post", isPresented: $showShareSheet, titleVisibility: .visible) { shareDialog }
        .confirmationDialog("Delete this post?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            deleteDialog
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: - Header

    private var isOwnPost: Bool {
        post.authorId == authService.currentUser?.id
    }

    /// The author's name: stored on newer posts; for older ones, known only for your own posts
    /// or once you've opened the author's profile.
    private var authorName: String {
        if isOwnPost, let name = authService.currentUser?.fullName, !name.isEmpty { return name }
        if let name = post.authorFullName, !name.isEmpty { return name }
        if let name = profileUser?.fullName, !name.isEmpty { return name }
        return post.authorUsername
    }

    private var authorImageURL: String? {
        if isOwnPost { return authService.currentUser?.profileImageUrl }
        return post.authorAvatarURL ?? profileUser?.profileImageUrl
    }

    /// "@username · 2h", or just "2h" when the name shown above already is the username.
    private var bylineText: String {
        let time = post.createdAt.feedRelativeText
        return authorName == post.authorUsername ? time : "@\(post.authorUsername) · \(time)"
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            Button(action: handleProfileTap) {
                HStack(spacing: DS.Spacing.m) {
                    ZStack {
                        UserAvatar(username: post.authorUsername, fullName: post.authorFullName, imageURL: authorImageURL, size: 42)
                        if isLoadingUser {
                            Circle().fill(Color.surface.opacity(0.6)).frame(width: 42, height: 42)
                            ProgressView().controlSize(.small)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(authorName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                            if post.postType != .text {
                                Tag(text: post.postType.displayName, systemImage: postTypeIcon)
                            }
                            if let sentiment = post.sentiment {
                                SentimentBadge(sentiment: sentiment)
                            }
                        }
                        Text(bylineText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(isOwnPost ? "" : "Opens profile")

            Spacer(minLength: 0)

            moreMenu
        }
    }

    private var moreMenu: some View {
        Menu {
            if isOwnPost {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete post", systemImage: "trash")
                }
            }

            if !isOwnPost {
                Button {
                    showReportSheet = true
                } label: {
                    Label("Report post", systemImage: "flag")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More")
    }

    private var postTypeIcon: String {
        switch post.postType {
        case .text: return "text.bubble"
        case .tradeResult: return "chart.line.uptrend.xyaxis"
        case .marketAnalysis: return "chart.bar.xaxis"
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
        if !post.displayContent.isEmpty {
            Text(post.displayContent)
                .font(.body)
                .lineSpacing(3)
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }

        if !post.linkableTickers.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // Each opens the ticker's page (needs a NavigationStack above the card)
                    ForEach(post.linkableTickers, id: \.self) { ticker in
                        TickerLink(symbol: ticker)
                    }
                }
            }
            .scrollClipDisabled()
        }

        if let snapshot = post.tradeSnapshot {
            TradeSummaryCard(snapshot: snapshot)
        } else if let trade = post.tradeSummary {
            // Older trade posts with typed-in numbers
            TradeSummaryCard(trade: trade, proof: .selfReported)
        } else if post.postType == .tradeResult {
            // Older trade posts without numbers
            TradeProofBadge(proof: .selfReported)
        }
    }

    @ViewBuilder
    private var imageSection: some View {
        if !post.imageUrls.isEmpty {
            TabView(selection: $currentImageIndex) {
                ForEach(Array(post.imageUrls.enumerated()), id: \.offset) { index, imageUrl in
                    postImage(imageUrl)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: post.imageUrls.count > 1 ? .automatic : .never))
            .frame(height: 260)
            .background(Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .strokeBorder(Color.hairline, lineWidth: 1)
            )
            .accessibilityLabel("\(post.imageUrls.count) photo\(post.imageUrls.count == 1 ? "" : "s")")
        }
    }

    private func postImage(_ imageUrl: String) -> some View {
        AsyncImage(url: URL(string: imageUrl)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else if phase.error != nil {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - Actions

    private var isLiked: Bool { store.isLiked(post.id) }
    private var isBookmarked: Bool { store.isBookmarked(post.id) }

    private var actionRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            PostActionButton(
                systemImage: isLiked ? "heart.fill" : "heart",
                count: store.likesCount(for: post),
                tint: isLiked ? .red : .secondary,
                accessibilityLabel: isLiked ? "Unlike" : "Like",
                effectTrigger: isLiked
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.snappy(duration: 0.25)) {
                    store.toggleLike(post)
                }
            }

            PostActionButton(
                systemImage: "bubble.right",
                count: store.commentsCount(for: post),
                tint: .secondary,
                accessibilityLabel: "Comments"
            ) {
                showComments = true
            }

            Spacer(minLength: 0)

            PostActionButton(
                systemImage: isBookmarked ? "bookmark.fill" : "bookmark",
                tint: isBookmarked ? .goldText : .secondary,
                accessibilityLabel: isBookmarked ? "Remove bookmark" : "Bookmark",
                effectTrigger: isBookmarked
            ) {
                UISelectionFeedbackGenerator().selectionChanged()
                store.toggleBookmark(post)
            }

            PostActionButton(
                systemImage: "square.and.arrow.up",
                tint: .secondary,
                accessibilityLabel: "Share"
            ) {
                showShareSheet = true
            }
        }
        .padding(.horizontal, -DS.Spacing.s)  // let the tap targets reach the card's padding
        .padding(.bottom, -DS.Spacing.xs)
    }

    // MARK: - Overlays and sheets

    @ViewBuilder
    private var deletingOverlay: some View {
        if isDeleting {
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .fill(Color.surface.opacity(0.85))
                .overlay(
                    VStack(spacing: DS.Spacing.s) {
                        ProgressView()
                        Text("Deleting…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                )
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var profileSheet: some View {
        if let profileUser = profileUser {
            OtherUserProfileView(user: profileUser)
                .environmentObject(authService)
        } else {
            EmptyStateView(
                systemImage: "person.crop.circle.badge.exclamationmark",
                title: "Couldn't load profile",
                message: "@\(post.authorUsername)",
                actionTitle: "Close"
            ) {
                showOtherUserProfile = false
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var commentsSheet: some View {
        CommentsView(postId: post.id)
        .environmentObject(authService)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.surface)
        .presentationCornerRadius(DS.Radius.xl)
    }

    private var reportSheet: some View {
        ReportSheet(target: .post(id: post.id, ownerId: post.authorId)) {
            didReport = true
        }
    }

    /// Hides a reported post from the reporter's lists everywhere (after the sheet has closed,
    /// since this card goes away)
    private func hideIfReported() {
        guard didReport else { return }
        didReport = false
        store.markRemoved(post.id)
    }

    @ViewBuilder
    private var shareDialog: some View {
        Button("Copy post text") {
            copyPostContent()
        }

        Button("Share…") {
            shareViaIOS()
        }

        Button("Cancel", role: .cancel) { }
    }

    @ViewBuilder
    private var deleteDialog: some View {
        Button("Delete post", role: .destructive) {
            Task {
                await deletePost()
            }
        }

        Button("Cancel", role: .cancel) { }
    }

    @ViewBuilder
    private var shareConfirmationToast: some View {
        if showShareConfirmation {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.marketGreen)
                Text(shareMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, DS.Spacing.s)
            .background(Capsule().fill(Color.surfaceRaised))
            .overlay(Capsule().strokeBorder(Color.hairline, lineWidth: 1))
            .padding(.top, DS.Spacing.s)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Delete

    private func deletePost() async {
        guard let currentUserId = authService.currentUser?.id,
              currentUserId == post.authorId else {
            showShareMessage("You can only delete your own posts")
            return
        }

        withAnimation { isDeleting = true }

        do {
            // Removes the post from every list (PostStore); the toast is shown by the screen,
            // since this card goes away
            try await FirebaseServices.shared.deletePost(postId: post.id)
            store.showToast("Post deleted")
        } catch {
            showShareMessage("Couldn't delete post. Try again.")
        }

        withAnimation { isDeleting = false }
    }

    // MARK: - Sharing

    private func copyPostContent() {
        UIPasteboard.general.string = shareText
        showShareMessage("Copied")
    }

    /// The text used when copying or sharing a post (there are no web links to posts).
    private var shareText: String {
        """
        @\(post.authorUsername): \(post.displayContent)

        — shared from Arkad
        """
    }

    private func shareViaIOS() {
        let content = shareText

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            showShareMessage("Unable to share")
            return
        }

        let activityController = UIActivityViewController(
            activityItems: [content],
            applicationActivities: nil
        )

        // For iPad support
        if let popover = activityController.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        // Present from the top-most controller so it works while a sheet is showing
        var presenter = window.rootViewController
        while let presented = presenter?.presentedViewController {
            presenter = presented
        }
        presenter?.present(activityController, animated: true)
    }

    private func showShareMessage(_ message: String) {
        shareMessage = message
        withAnimation(.snappy(duration: 0.3)) {
            showShareConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.snappy(duration: 0.3)) {
                showShareConfirmation = false
            }
        }
    }

    // MARK: - Profile navigation

    private func handleProfileTap() {
        // Your own post: nothing to open
        guard !isOwnPost else { return }
        Task { await loadUserProfile() }
    }

    private func loadUserProfile() async {
        if profileUser != nil {
            showOtherUserProfile = true
            return
        }
        isLoadingUser = true
        let user = try? await authService.getUserById(userId: post.authorId)
        profileUser = user ?? createMinimalUser()
        isLoadingUser = false
        showOtherUserProfile = true
    }

    private func createMinimalUser() -> User {
        // Built only from what the post itself tells us; no invented details.
        var user = User(
            id: post.authorId,
            email: "",
            username: post.authorUsername,
            fullName: post.authorFullName ?? post.authorUsername
        )
        user.profileImageUrl = post.authorAvatarURL

        user.bio = nil
        user.followersCount = 0
        user.followingCount = 0
        user.totalProfitLoss = 0.0
        user.winRate = 0.0

        return user
    }
}

// MARK: - Action button

/// Icon (+ optional count) in the post card's action row.
private struct PostActionButton: View {
    let systemImage: String
    var count: Int? = nil
    let tint: Color
    let accessibilityLabel: String
    var effectTrigger: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: effectTrigger)
                if let count, count > 0 {
                    Text(count.formatted(.number.notation(.compactName)))
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .contentTransition(.numericText(value: Double(count)))
                }
            }
            .foregroundStyle(tint)
            .frame(minWidth: 44, minHeight: 36)
            .padding(.horizontal, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(count.map { "\($0)" } ?? "")
    }
}

#Preview {
    let samplePost = Post(content: "Just made a great trade on $AAPL! Took profits into the close.", authorId: "1", authorUsername: "trader1")

    ScrollView {
        UserPostCard(post: samplePost)
            .padding()
    }
    .screenBackground()
    .environmentObject(FirebaseAuthService.shared)
}

// MARK: - Trade summary

/// The numbers from a trade post: P&L, ticker, entry → exit, size and the proof label. Also used on
/// Profile and in the composer. New posts render from the post's `tradeSnapshot`; older posts with
/// typed-in numbers render from `TradingData` and are labelled self-reported.
struct TradeSummaryCard: View {
    let trade: TradingData
    var proof: TradeProof = .selfReported
    /// "Stock", "Option"… for snapshots; older posts use TradingData's own type
    private var assetLabel: String? = nil
    private var priceTerms: AssetTerms? = nil

    init(trade: TradingData, proof: TradeProof = .selfReported) {
        self.trade = trade
        self.proof = proof
    }

    /// From a trade-result post's snapshot: P&L computed from its entry, exit and size.
    init(snapshot: TradeSnapshot) {
        var data = TradingData()
        data.ticker = snapshot.ticker
        data.entryPrice = snapshot.entryPrice
        data.exitPrice = snapshot.exitPrice
        data.profitLoss = snapshot.profitLoss
        let type = snapshot.assetType ?? .stock
        let terms = AssetTerms(type)
        data.positionSize = terms.quantityText(snapshot.quantity, symbol: snapshot.ticker)
        self.trade = data
        self.proof = snapshot.proof
        self.assetLabel = type == .stock ? nil : type.displayName
        self.priceTerms = terms
    }

    private var tint: Color { trade.isProfitable ? .marketGreen : .marketRed }

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(
                systemName: trade.isProfitable ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                tint: tint,
                size: 38
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(titleText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    if let typeText {
                        Text(typeText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if let details {
                    Text(details)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                TradeProofBadge(proof: proof, compact: true)
            }

            Spacer(minLength: DS.Spacing.s)

            Text(trade.formattedProfitLoss)
                .arkadNumber(18)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(Color.surfaceRaised)
        )
        .accessibilityElement(children: .combine)
    }

    private var titleText: String {
        if let ticker = trade.ticker, !ticker.isEmpty { return "$\(ticker)" }
        return "Trade result"
    }

    private var typeText: String? {
        assetLabel ?? trade.tradeType?.displayName
    }

    /// "$200.00 → $250.00 · 10 shares"
    private var details: String? {
        var parts: [String] = []
        if let entry = trade.entryPrice, let exit = trade.exitPrice {
            if let priceTerms {
                parts.append("\(priceTerms.price(entry)) → \(priceTerms.price(exit))")
            } else {
                parts.append("\(entry.formatted(.currency(code: "USD"))) → \(exit.formatted(.currency(code: "USD")))")
            }
        }
        if let size = trade.positionSize, !size.isEmpty {
            parts.append(size)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Feed dates

extension Date {
    /// Compact feed timestamp: "now", "5m", "3h", "2d", then "Nov 3" (with the year if it isn't this year).
    var feedRelativeText: String {
        let seconds = max(0, Date().timeIntervalSince(self))
        switch seconds {
        case ..<60:
            return "now"
        case ..<3600:
            return "\(Int(seconds / 60))m"
        case ..<86_400:
            return "\(Int(seconds / 3600))h"
        case ..<(7 * 86_400):
            return "\(Int(seconds / 86_400))d"
        default:
            let sameYear = Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
            return sameYear
                ? formatted(.dateTime.month(.abbreviated).day())
                : formatted(.dateTime.month(.abbreviated).day().year())
        }
    }
}
