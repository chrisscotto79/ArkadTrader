// File: Core/Profile/Views/ProfileCards.swift
// Cards and rows shown in profile tabs: posts, post detail, trades, top trades and communities,
// plus the label that tells portfolio numbers apart from the callout record.

import SwiftUI

// MARK: - Post Card Content (shared by own and other users' profiles)

/// The visual summary of a post: thumbnail, type tag, text and engagement.
struct ProfilePostCardContent: View {
    let post: Post

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            thumbnail

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                if post.postType != .text {
                    HStack(spacing: 6) {
                        Tag(text: post.postType.displayName, systemImage: postTypeIcon)
                        if post.postType == .tradeResult {
                            TradeProofBadge(proof: post.tradeProof, compact: true)
                        }
                    }
                }

                Text(previewText)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                metaRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }

    private var metaRow: some View {
        HStack(spacing: DS.Spacing.l) {
            Label("\(post.likesCount)", systemImage: post.likesCount > 0 ? "heart.fill" : "heart")
            Label("\(post.commentsCount)", systemImage: "bubble.left")
            Spacer(minLength: 0)
            Text(post.createdAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
        }
        .font(.caption.weight(.medium).monospacedDigit())
        .foregroundStyle(.secondary)
        .labelStyle(ProfileCompactLabelStyle())
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let first = post.imageUrls.first, let url = URL(string: first) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.surfaceRaised
                            .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))

                if post.imageUrls.count > 1 {
                    Text("+\(post.imageUrls.count - 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .padding(4)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private var previewText: String {
        let text = post.displayContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return text }
        if let ticker = post.tradeSummary?.ticker, !ticker.isEmpty { return "Trade result: $\(ticker.uppercased())" }
        return post.imageUrls.isEmpty ? "Post" : "Photo"
    }

    private var postTypeIcon: String {
        switch post.postType {
        case .text: return "text.quote"
        case .tradeResult: return "chart.line.uptrend.xyaxis"
        case .marketAnalysis: return "magnifyingglass"
        }
    }
}

/// Icon + title with a tight gap (engagement counts).
struct ProfileCompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}

// MARK: - Own Post Card

/// The signed-in user's post. Tapping opens the detail sheet, where it can be deleted.
struct ProfileUserPostCard: View {
    let post: Post
    let onPostDeleted: (() -> Void)?
    @State private var showFullPost = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @EnvironmentObject var authService: FirebaseAuthService

    init(post: Post, onPostDeleted: (() -> Void)? = nil) {
        self.post = post
        self.onPostDeleted = onPostDeleted
    }

    var body: some View {
        Button {
            showFullPost = true
        } label: {
            ProfilePostCardContent(post: post)
        }
        .buttonStyle(PressableStyle())
        .disabled(isDeleting)
        .overlay { deletingOverlay }
        .sheet(isPresented: $showFullPost) {
            ProfilePostDetailView(
                post: post,
                onDelete: {
                    Task {
                        await deletePost()
                    }
                }
            )
            .environmentObject(authService)
        }
        .alert(
            "Couldn't Delete Post",
            isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteError ?? "")
        }
    }

    @ViewBuilder
    private var deletingOverlay: some View {
        if isDeleting {
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    HStack(spacing: DS.Spacing.s) {
                        ProgressView()
                        Text("Deleting…")
                            .font(.subheadline.weight(.medium))
                    }
                )
                .transition(.opacity)
        }
    }

    private func deletePost() async {
        isDeleting = true

        do {
            try await authService.deletePost(postId: post.id)
            onPostDeleted?()
        } catch {
            deleteError = "Couldn't delete the post. Check your connection and try again."
        }

        isDeleting = false
    }
}

// MARK: - Profile Post Detail View

struct ProfilePostDetailView: View {
    let post: Post
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    @State private var currentImageIndex = 0
    @EnvironmentObject var authService: FirebaseAuthService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    authorRow

                    if !post.displayContent.isEmpty {
                        Text(post.displayContent)
                            .font(.body)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let snapshot = post.tradeSnapshot {
                        TradeSummaryCard(snapshot: snapshot)
                    } else if let trade = post.tradeSummary {
                        // Older trade posts with typed-in numbers
                        TradeSummaryCard(trade: trade, proof: .selfReported)
                    }

                    if !post.imageUrls.isEmpty {
                        imageGallery
                    }

                    engagementRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .screenBackground()
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.goldText)
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(Color.marketRed)
                }
            }
            .confirmationDialog("Delete Post", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Post", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private var authorRow: some View {
        HStack(spacing: DS.Spacing.m) {
            UserAvatar(
                username: post.authorUsername,
                imageURL: authService.currentUser?.profileImageUrl,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(post.authorUsername)")
                    .font(.headline)
                Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if post.postType != .text {
                Tag(text: post.postType.displayName)
            }
        }
    }

    private var imageGallery: some View {
        VStack(spacing: DS.Spacing.s) {
            TabView(selection: $currentImageIndex) {
                ForEach(Array(post.imageUrls.enumerated()), id: \.offset) { index, imageUrl in
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.surfaceRaised
                            .overlay(ProgressView().tint(Color.goldText))
                    }
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: post.imageUrls.count > 1 ? .automatic : .never))
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))

            if post.imageUrls.count > 1 {
                Text("\(currentImageIndex + 1) of \(post.imageUrls.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var engagementRow: some View {
        HStack(spacing: DS.Spacing.xl) {
            Label("\(post.likesCount) \(post.likesCount == 1 ? "like" : "likes")", systemImage: "heart")
            Label("\(post.commentsCount) \(post.commentsCount == 1 ? "comment" : "comments")", systemImage: "bubble.left")
            Spacer(minLength: 0)
        }
        .font(.subheadline.weight(.medium).monospacedDigit())
        .foregroundStyle(.secondary)
        .labelStyle(ProfileCompactLabelStyle())
        .padding(.top, DS.Spacing.xs)
    }
}

// MARK: - Trade Row

/// One trade as a row inside a card (own and other users' profiles).
struct ProfileUserTradeCard: View {
    let trade: Trade

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(
                systemName: trade.tradeType.icon,
                tint: trade.isOpen ? .goldText : plColor,
                size: 38
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(trade.ticker)
                        .font(.headline)
                        .lineLimit(1)
                    if trade.isOpen {
                        Tag(text: "Open")
                    }
                    TradeProofBadge(proof: trade.proof, compact: true)
                }

                Text("\(trade.quantity.quantityString) \(unitLabel) @ \(trade.entryPrice.asTradingPrice)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DS.Spacing.s)

            VStack(alignment: .trailing, spacing: 3) {
                // Open trades show unrealized P&L only once a live price is known
                if let pl = displayedPL {
                    Text(pl.asCurrencyWithSign)
                        .arkadNumber(15, weight: .semibold)
                        .foregroundStyle(pl >= 0 ? Color.marketGreen : Color.marketRed)
                }

                Text(trade.entryDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .accessibilityElement(children: .combine)
    }

    private var plColor: Color {
        trade.profitLoss >= 0 ? .marketGreen : .marketRed
    }

    private var unitLabel: String {
        switch trade.tradeType {
        case .option: return trade.quantity == 1 ? "contract" : "contracts"
        case .stock: return trade.quantity == 1 ? "share" : "shares"
        case .crypto, .forex: return "units"
        }
    }

    private var displayedPL: Double? {
        if !trade.isOpen { return trade.profitLoss }
        guard let current = trade.currentPrice, current > 0, current != trade.entryPrice else { return nil }
        return trade.unrealizedPL
    }
}

// MARK: - Top Trade Row

/// A closed, profitable trade with its return.
struct TopPositionCard: View {
    let trade: Trade

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            Text(String(trade.ticker.prefix(4)))
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.marketGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.marketGreen.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(trade.ticker)
                        .font(.headline)
                        .lineLimit(1)
                    TradeProofBadge(proof: trade.proof, compact: true)
                }
                Text("\(trade.quantity.quantityString) \(trade.tradeType == .option ? "contracts" : "shares") · \(trade.daysHeld)d held")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DS.Spacing.s)

            VStack(alignment: .trailing, spacing: 4) {
                Text(trade.profitLoss.asCurrencyWithSign)
                    .arkadNumber(15, weight: .semibold)
                    .foregroundStyle(Color.marketGreen)
                if trade.entryPrice > 0 {
                    ChangePill(
                        text: String(format: "%+.1f%%", trade.profitLossPercentage),
                        isPositive: trade.profitLossPercentage >= 0
                    )
                }
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Community Card

struct ProfileUserGroupCard: View {
    let group: TradingGroup

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    if group.isPrivate {
                        Image(systemName: "lock.fill")
                            .accessibilityLabel("Private")
                    }
                    Text("\(group.memberCount) \(group.memberCount == 1 ? "member" : "members")")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .cardStyle(padding: 14)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var avatar: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if let imageUrl = group.imageUrl, !imageUrl.isEmpty {
            // https:// or arkad-image:// (images stored in Firestore)
            ArkadAsyncImage(urlString: imageUrl) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                initialsTile
            }
            .frame(width: 44, height: 44)
            .clipShape(shape)
        } else {
            initialsTile
                .frame(width: 44, height: 44)
        }
    }

    private var initialsTile: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.goldTint)
            .overlay(
                Text(String(group.name.prefix(2)).uppercased())
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.goldText)
            )
    }
}

// MARK: - Shared Helpers

/// Names where a block of numbers comes from, so portfolio stats (trades the user logs)
/// aren't mistaken for the callout record (verified from posted callouts).
struct ProfileSourceLabel: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.leading, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Hairline between rows inside a profile card.
struct ProfileRowDivider: View {
    var inset: CGFloat = DS.Spacing.l + 38 + DS.Spacing.m

    var body: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(height: 1)
            .padding(.leading, inset)
    }
}
