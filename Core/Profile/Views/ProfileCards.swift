// File: Core/Profile/Views/ProfileCards.swift
// Cards shown in profile tabs: posts, post detail, trades, positions and groups.

import SwiftUI

// MARK: - Supporting Card Components
struct ProfileUserPostCard: View {
    let post: Post
    let onPostDeleted: (() -> Void)?
    @State private var showFullPost = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isPressed = false
    @EnvironmentObject var authService: FirebaseAuthService
    
    init(post: Post, onPostDeleted: (() -> Void)? = nil) {
        self.post = post
        self.onPostDeleted = onPostDeleted
    }
    
    var body: some View {
        Button(action: {
            showFullPost = true
        }) {
            // UPDATED: Horizontal layout for single column display
            HStack(spacing: 16) {
                // Image or icon section (fixed width)
                imageSection
                    .frame(width: 80)
                
                // Content section (flexible width)
                VStack(alignment: .leading, spacing: 12) {
                    // Post content
                    Text(post.displayContent)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Bottom section with engagement and metadata
                    VStack(spacing: 8) {
                        // Engagement stats
                        HStack(spacing: 16) {
                            // Likes
                            HStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.1))
                                        .frame(width: 20, height: 20)
                                    
                                    Image(systemName: post.likesCount > 0 ? "heart.fill" : "heart")
                                        .font(.caption2)
                                        .foregroundColor(post.likesCount > 0 ? .red : .gray)
                                }
                                
                                Text("\(post.likesCount)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            
                            // Comments
                            if post.commentsCount > 0 {
                                HStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.1))
                                            .frame(width: 20, height: 20)
                                        
                                        Image(systemName: "message.fill")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Text("\(post.commentsCount)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Spacer()
                            
                            // Time
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                    .foregroundColor(.arkadGold.opacity(0.7))
                                
                                Text(formatTimeAgo(post.createdAt))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Post type indicator
                        HStack {
                            if post.postType != .text {
                                HStack(spacing: 4) {
                                    Image(systemName: postTypeIcon(for: post.postType))
                                        .font(.caption2)
                                    
                                    Text(post.postType.displayName)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(postTypeColor(for: post.postType))
                                        .shadow(color: postTypeColor(for: post.postType).opacity(0.3), radius: 2, x: 0, y: 1)
                                )
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(
                        color: isPressed ? Color.arkadGold.opacity(0.15) : Color.black.opacity(0.04),
                        radius: isPressed ? 8 : 4,
                        x: 0,
                        y: isPressed ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.arkadGold.opacity(isPressed ? 0.3 : 0.1),
                                Color.arkadGold.opacity(isPressed ? 0.15 : 0.05),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
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
        .overlay(deletingOverlay)
    }
    
    // UPDATED: Optimized image section for horizontal layout
    @ViewBuilder
    private var imageSection: some View {
        if !post.imageUrls.isEmpty {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: post.imageUrls.first!)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.arkadGold.opacity(0.3),
                                Color.arkadGold.opacity(0.1),
                                Color.arkadGold.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        VStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundColor(.arkadGold.opacity(0.6))
                            
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .arkadGold))
                                .scaleEffect(0.6)
                        }
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Image count badge
                if post.imageUrls.count > 1 {
                    Text("\(post.imageUrls.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.4))
                                )
                        )
                        .offset(x: -4, y: 4)
                }
            }
        } else {
            // Text-only post icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.arkadGold.opacity(0.15),
                                Color.arkadGold.opacity(0.08),
                                Color.arkadGold.opacity(0.03)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 4) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.title3)
                        .foregroundColor(.arkadGold.opacity(0.7))
                    
                    Text("Text")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold.opacity(0.8))
                }
            }
            .frame(width: 80, height: 80)
        }
    }
    
    @ViewBuilder
    private var deletingOverlay: some View {
        if isDeleting {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.3))
                )
                .overlay(
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        
                        Text("Deleting...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                )
        }
    }
    
    private func postTypeIcon(for type: PostType) -> String {
        switch type {
        case .text: return "text.quote"
        case .tradeResult: return "chart.line.uptrend.xyaxis"
        case .marketAnalysis: return "magnifyingglass.circle"
        }
    }
    
    private func postTypeColor(for type: PostType) -> Color {
        switch type {
        case .text: return .gray
        case .tradeResult: return .green
        case .marketAnalysis: return .blue
        }
    }
    
    private func deletePost() async {
        isDeleting = true
        
        do {
            try await authService.deletePost(postId: post.id)
            print("✅ Post deleted successfully")
            
            // Call the callback to refresh the posts list
            await MainActor.run {
                onPostDeleted?()
            }
        } catch {
            print("❌ Error deleting post: \(error)")
        }
        
        isDeleting = false
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Post header
                    HStack {
                        Circle()
                            .fill(Color.arkadGold.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(post.authorUsername.prefix(1)).uppercased())
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.arkadGold)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@\(post.authorUsername)")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(formatFullDate(post.createdAt))
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Post content
                    if !post.displayContent.isEmpty {
                        Text(post.displayContent)
                            .font(.body)
                            .lineSpacing(6)
                            .padding(.horizontal)
                    }

                    if let trade = post.tradeSummary {
                        TradeSummaryCard(trade: trade)
                            .padding(.horizontal)
                    }
                    
                    // Images
                    if !post.imageUrls.isEmpty {
                        VStack(spacing: 12) {
                            TabView(selection: $currentImageIndex) {
                                ForEach(Array(post.imageUrls.enumerated()), id: \.offset) { index, imageUrl in
                                    AsyncImage(url: URL(string: imageUrl)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .arkadGold))
                                            )
                                    }
                                    .frame(height: 300)
                                    .clipped()
                                    .tag(index)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                            .frame(height: 300)
                            
                            if post.imageUrls.count > 1 {
                                Text("\(currentImageIndex + 1) of \(post.imageUrls.count)")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                    
                    // Engagement stats
                    HStack(spacing: 24) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart")
                                .foregroundColor(.red)
                            Text("\(post.likesCount)")
                                .fontWeight(.medium)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "message")
                                .foregroundColor(.blue)
                            Text("\(post.commentsCount)")
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .navigationTitle("Post Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Delete") {
                        showDeleteConfirmation = true
                    }
                    .foregroundColor(.red)
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
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ProfileUserTradeCard: View {
    let trade: Trade
    
    var body: some View {
        HStack(spacing: 12) {
            // Trade icon
            Image(systemName: trade.isOpen ? "circle" : "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(trade.isOpen ? .arkadGold : .marketGreen)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.ticker)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if trade.isOpen {
                        Text("OPEN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.arkadGold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.arkadGold.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                Text("\(trade.quantity) \(unitLabel) @ \(trade.entryPrice.asCurrency)")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                // Open trades show unrealized P&L only once a live price is known
                if let pl = displayedPL {
                    Text(pl.asCurrencyWithSign)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(pl >= 0 ? .marketGreen : .marketRed)
                }
                
                Text(formatShortDate(trade.entryDate))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.arkadGold.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var unitLabel: String {
        trade.tradeType == .option ? "contracts" : "shares"
    }
    
    private var displayedPL: Double? {
        if !trade.isOpen { return trade.profitLoss }
        guard let current = trade.currentPrice, current > 0, current != trade.entryPrice else { return nil }
        return trade.unrealizedPL
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct TopPositionCard: View {
    let trade: Trade
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.marketGreen.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(trade.ticker.prefix(2))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.marketGreen)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(trade.ticker)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Return: \(String(format: "%.1f", trade.profitLossPercentage))%")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(trade.profitLoss.asCurrencyWithSign)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.marketGreen)
                
                Text("\(trade.quantity) \(trade.tradeType == .option ? "contracts" : "shares")")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.marketGreen.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ProfileUserGroupCard: View {
    let group: TradingGroup
    
    var body: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color.arkadGold.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(group.name.prefix(2))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.arkadGold)
                )
            
            VStack(spacing: 4) {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("\(group.memberCount) members")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
