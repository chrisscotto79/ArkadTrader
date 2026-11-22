// File: Core/Home/Views/UserPostCard.swift
// Enhanced User Post Card with Improved Layout and Delete Functionality

import SwiftUI

struct UserPostCard: View {
    let post: Post
    @ObservedObject var homeViewModel: HomeViewModel
    @State private var showOtherUserProfile = false
    @State private var profileUser: User?
    @State private var isLoadingUser = false
    @State private var showComments = false
    
    // Delete functionality
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    
    // Sharing and reporting
    @State private var showShareSheet = false
    @State private var shareMessage = ""
    @State private var showShareConfirmation = false
    @State private var showPostMenu = false
    @State private var showReportSheet = false
    @State private var selectedReportReason = ""
    @State private var customReportReason = ""
    @State private var isReporting = false
    @State private var currentImageIndex = 0


    @EnvironmentObject var authService: FirebaseAuthService
    
    init(post: Post, homeViewModel: HomeViewModel) {
        self.post = post
        self.homeViewModel = homeViewModel
    }

    // MARK: - Report Post View
    struct ReportPostView: View {
        let post: Post
        let onReport: (String) -> Void
        
        @Environment(\.dismiss) var dismiss
        @EnvironmentObject var authService: FirebaseAuthService
        
        @State private var selectedReason = ""
        @State private var customReason = ""
        @State private var showCustomInput = false
        @State private var isSubmitting = false
        
        private let reportReasons = [
            "Spam or misleading information",
            "Harassment or bullying",
            "Inappropriate content",
            "False trading information",
            "Hate speech or discrimination",
            "Violation of community guidelines",
            "Copyright infringement",
            "Other"
        ]
        
        var body: some View {
            NavigationView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Report Post")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Help us understand the problem")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Post preview
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(Color.arkadGold.opacity(0.2))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Text(String(post.authorUsername.prefix(1)).uppercased())
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.arkadGold)
                                    )
                                
                                Text("@\(post.authorUsername)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                            }
                            
                            Text(post.displayContent)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    Divider()
                    
                    // Report reasons
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(reportReasons, id: \.self) { reason in
                                Button(action: {
                                    selectedReason = reason
                                    if reason == "Other" {
                                        showCustomInput = true
                                    } else {
                                        showCustomInput = false
                                        customReason = ""
                                    }
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(reason)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                                .multilineTextAlignment(.leading)
                                            
                                            if reason == selectedReason && reason != "Other" {
                                                Text("Selected")
                                                    .font(.caption)
                                                    .foregroundColor(.arkadGold)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: selectedReason == reason ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedReason == reason ? .arkadGold : .gray.opacity(0.5))
                                            .font(.title3)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .background(Color.clear)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if reason != reportReasons.last {
                                    Divider()
                                        .padding(.leading, 20)
                                }
                            }
                            
                            // Custom reason input
                            if showCustomInput {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Please describe the issue:")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 20)
                                    
                                    TextField("Describe the problem...", text: $customReason, axis: .vertical)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(3...6)
                                        .padding(.horizontal, 20)
                                }
                                .padding(.vertical, 16)
                                .background(Color.gray.opacity(0.02))
                            }
                        }
                    }
                    
                    // Submit button
                    VStack(spacing: 0) {
                        Divider()
                        
                        HStack(spacing: 12) {
                            Button("Cancel") {
                                dismiss()
                            }
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(25)
                            
                            Button(action: submitReport) {
                                HStack {
                                    if isSubmitting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .foregroundColor(.white)
                                    } else {
                                        Text("Submit Report")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(canSubmit ? Color.red : Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(25)
                            }
                            .disabled(!canSubmit || isSubmitting)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .background(Color(.systemBackground))
                }
                .navigationBarHidden(true)
            }
        }
        
        private var canSubmit: Bool {
            if selectedReason == "Other" {
                return !customReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return !selectedReason.isEmpty
        }
        
        private func submitReport() {
            isSubmitting = true
            
            let finalReason = selectedReason == "Other" ? customReason : selectedReason
            
            // Add slight delay for better UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onReport(finalReason)
                dismiss()
            }
        }
    }
    
    // MARK: - Main Body
    var body: some View {
        VStack(spacing: 0) {
            // User Header
            userHeaderSection
            
            // Content
            contentSection
            
            // Images
            imageSection
            
            // Engagement buttons
            engagementSection
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(shareConfirmationToast, alignment: .top)
        .overlay(deletingOverlay)
        .sheet(isPresented: $showOtherUserProfile) { profileSheet }
        .sheet(isPresented: $showComments) { commentsSheet }
        .sheet(isPresented: $showReportSheet) { reportSheet }
        .confirmationDialog("Share Post", isPresented: $showShareSheet, titleVisibility: .visible) { shareDialog }
        .confirmationDialog("Delete Post", isPresented: $showDeleteConfirmation, titleVisibility: .visible) { deleteDialog }
    }
    
    // MARK: - View Components
    @ViewBuilder
    private var userHeaderSection: some View {
        Button(action: { handleProfileTap() }) {
            HStack(spacing: 12) {
                ZStack {
                    UserAvatar(username: post.authorUsername, size: 40)
                    if isLoadingUser {
                        ProgressView().scaleEffect(0.6)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("@\(post.authorUsername)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if post.postType != .text {
                            Text(post.postType.displayName)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(postTypeColor(for: post.postType))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(postTypeColor(for: post.postType).opacity(0.12)))
                        }
                        
                    }
                    
                    Text(formatDate(post.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    if post.authorId == authService.currentUser?.id {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Post", systemImage: "trash")
                        }
                    }
                    
                    Button {
                        showReportSheet = true
                    } label: {
                        Label("Report Post", systemImage: "flag")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                        .accessibilityLabel("More")
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    @ViewBuilder
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !post.displayContent.isEmpty {
                Text(post.displayContent)
                    .font(.body)
                    .lineSpacing(6)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if !post.tickers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(post.tickers, id: \.self) { ticker in
                            HStack(spacing: 4) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.arkadGold)
                                
                                Text(ticker)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.arkadGold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.arkadGold.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.arkadGold.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            
            if let trade = post.tradeSummary {
                TradeSummaryCard(trade: trade)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    @ViewBuilder
    private var imageSection: some View {
        if !post.imageUrls.isEmpty {
            TabView(selection: $currentImageIndex) {
                ForEach(Array(post.imageUrls.enumerated()), id: \.offset) { index, imageUrl in
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else if phase.error != nil {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundColor(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
                    .clipped()
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: post.imageUrls.count > 1 ? .automatic : .never))
            .frame(height: 320)
            .padding(.top, 12)
            .accessibilityLabel("\(post.imageUrls.count) photo\(post.imageUrls.count == 1 ? "" : "s")")
        }
    }

    @ViewBuilder
    private var engagementSection: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)
                .padding(.top, 14)
            
            HStack(spacing: 24) { // ✅ Reduced spacing from 32 to 24
                // Like button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        homeViewModel.toggleLike(for: post.id)
                    }
                }) {
                    HStack(spacing: 6) { // ✅ Reduced spacing from 8 to 6
                        Image(systemName: homeViewModel.likedPosts.contains(post.id) ? "heart.fill" : "heart")
                            .font(.subheadline)
                            .foregroundColor(homeViewModel.likedPosts.contains(post.id) ? .red : .secondary)
                        
                        Text("\(post.likesCount)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(homeViewModel.likedPosts.contains(post.id) ? .red : .secondary)
                            .fixedSize() // ✅ Prevent text wrapping
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Comment button
                Button(action: {
                    showComments = true
                }) {
                    HStack(spacing: 6) { // ✅ Reduced spacing from 8 to 6
                        Image(systemName: "message")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(post.commentsCount)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .fixedSize() // ✅ Prevent text wrapping
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // ✅ IMPROVED: Share button with fixed size
                Button(action: {
                    showShareSheet = true
                }) {
                    HStack(spacing: 6) { // ✅ Reduced spacing from 8 to 6
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Share")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .fixedSize() // ✅ Prevent text wrapping
                            .lineLimit(1) // ✅ Force single line
                    }
                    .fixedSize(horizontal: true, vertical: false) // ✅ Prevent button from shrinking
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Bookmark button
                Button(action: {
                    homeViewModel.toggleBookmark(for: post.id)
                }) {
                    Image(systemName: homeViewModel.bookmarkedPosts.contains(post.id) ? "bookmark.fill" : "bookmark")
                        .font(.subheadline)
                        .foregroundColor(homeViewModel.bookmarkedPosts.contains(post.id) ? .arkadGold : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Helper Views
    @ViewBuilder
    private var deletingOverlay: some View {
        if isDeleting {
            Color.black.opacity(0.3)
                .overlay(
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        
                        Text("Deleting...")
                            .foregroundColor(.white)
                            .font(.subheadline)
                            .padding(.top, 8)
                    }
                )
                .cornerRadius(16)
        }
    }

    @ViewBuilder
    private var profileSheet: some View {
        if let profileUser = profileUser {
            OtherUserProfileView(user: profileUser)
                .environmentObject(authService)
        } else {
            VStack(spacing: 20) {
                Text("Unable to load profile")
                    .font(.headline)
                
                Text("User: @\(post.authorUsername)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("Dismiss") {
                    showOtherUserProfile = false
                }
                .foregroundColor(.blue)
            }
            .padding()
        }
    }

    @ViewBuilder
    private var commentsSheet: some View {
        CommentsView(
            postId: post.id,
            onCommentCountChanged: { newCount in
                homeViewModel.updatePostCommentCount(postId: post.id, newCount: newCount)
            }
        )
        .environmentObject(authService)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var reportSheet: some View {
        ReportPostView(
            post: post,
            onReport: { reason in
                Task {
                    await reportPost(reason: reason)
                }
            }
        )
        .environmentObject(authService)
    }

    @ViewBuilder
    private var shareDialog: some View {
        Button("Copy Post Content") {
            copyPostContent()
        }
        
        Button("Share…") {
            shareViaIOS()
        }
        
        Button("Cancel", role: .cancel) { }
    }

    @ViewBuilder
    private var deleteDialog: some View {
        Button("Delete Post", role: .destructive) {
            Task {
                await deletePost()
            }
        }
        
        Button("Cancel", role: .cancel) { }
    }
    
    // MARK: - Share confirmation toast view
    @ViewBuilder
    private var shareConfirmationToast: some View {
        if showShareConfirmation {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Text(shareMessage)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    // MARK: - Helper Methods
    // MARK: - Delete Post Function
    private func deletePost() async {
        guard let currentUserId = authService.currentUser?.id,
              currentUserId == post.authorId else {
            showShareMessage("You can only delete your own posts")
            return
        }
        
        isDeleting = true
        
        do {
            // Delete from Firebase
            try await authService.deletePost(postId: post.id)
            
            // Remove from local arrays
            await MainActor.run {
                homeViewModel.posts.removeAll { $0.id == post.id }
                homeViewModel.followingPosts.removeAll { $0.id == post.id }
            }
            
            print("✅ Post deleted successfully")
            showShareMessage("Post deleted")
            
        } catch {
            print("❌ Error deleting post: \(error)")
            showShareMessage("Failed to delete post")
        }
        
        isDeleting = false
    }
    
    // MARK: - Sharing Functions
    private func copyPostContent() {
        UIPasteboard.general.string = shareText
        showShareMessage("Post copied")
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showShareConfirmation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showShareConfirmation = false
            }
        }
    }
    
    // MARK: - Reporting Functions
    private func reportPost(reason: String) async {
        guard let currentUserId = authService.currentUser?.id else {
            showShareMessage("Must be logged in to report")
            return
        }
        
        print("🚨 Reporting post: \(post.id) for reason: \(reason)")
        
        do {
            try await authService.reportPost(
                postId: post.id,
                reportedBy: currentUserId,
                reason: reason
            )
            
            // ✅ Hide the post from this user immediately
            homeViewModel.hideReportedPost(postId: post.id, reportedBy: currentUserId)
            
            showShareMessage("Post reported and hidden")
            print("✅ Post reported successfully and hidden from user")
            
        } catch {
            showShareMessage("Failed to report post")
            print("❌ Error reporting post: \(error)")
        }
    }
    
    // MARK: - Profile Navigation Logic
    private func handleProfileTap() {
        // Your own post: nothing to open
        guard authService.currentUser?.id != post.authorId else { return }
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
            fullName: post.authorUsername
        )
        
        user.bio = nil
        user.followersCount = 0
        user.followingCount = 0
        user.totalProfitLoss = 0.0
        user.winRate = 0.0
        
        return user
    }
    
    private func postTypeColor(for type: PostType) -> Color {
        switch type {
        case .text: return .clear
        case .tradeResult: return .green
        case .marketAnalysis: return .blue
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    let samplePost = Post(content: "Just made a great trade on AAPL! 📈", authorId: "1", authorUsername: "trader1")
    
    UserPostCard(post: samplePost, homeViewModel: HomeViewModel())
        .padding()
        .environmentObject(FirebaseAuthService.shared)
}

/// The numbers from a trade post: P&L, ticker, entry → exit and size
struct TradeSummaryCard: View {
    let trade: TradingData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trade.isProfitable ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                .font(.title3)
                .foregroundColor(trade.isProfitable ? .marketGreen : .marketRed)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(trade.formattedProfitLoss)
                        .font(.headline.monospacedDigit())
                        .foregroundColor(trade.isProfitable ? .marketGreen : .marketRed)
                    if let ticker = trade.ticker, !ticker.isEmpty {
                        Text("$\(ticker)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                    }
                    if let type = trade.tradeType {
                        Text(type.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }
                if let details {
                    Text(details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill((trade.isProfitable ? Color.marketGreen : Color.marketRed).opacity(0.08))
        )
        .accessibilityElement(children: .combine)
    }

    /// "Entry $200.00 → Exit $250.00 · 10 shares"
    private var details: String? {
        var parts: [String] = []
        if let entry = trade.entryPrice, let exit = trade.exitPrice {
            parts.append("\(entry.formatted(.currency(code: "USD"))) → \(exit.formatted(.currency(code: "USD")))")
        }
        if let size = trade.positionSize, !size.isEmpty {
            parts.append(size)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
