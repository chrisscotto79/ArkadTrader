// File: Core/Home/Views/UserPostCard.swift
// Enhanced User Post Card with Sharing Functionality

import SwiftUI

struct UserPostCard: View {
    let post: Post
    @ObservedObject var homeViewModel: HomeViewModel
    @State private var showOtherUserProfile = false
    @State private var profileUser: User?
    @State private var isLoadingUser = false
    @State private var debugMessage = ""
    @State private var showComments = false
    
    // ✅ Add reporting state
    @State private var showShareSheet = false
    @State private var shareMessage = ""
    @State private var showShareConfirmation = false
    @State private var showPostMenu = false
    @State private var showReportSheet = false
    @State private var selectedReportReason = ""
    @State private var customReportReason = ""
    @State private var isReporting = false

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
                        
                        Text(post.content)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // User Header - CLICKABLE with Debug
            Button(action: {
                print("🔴 Profile button tapped for: \(post.authorUsername)")
                handleProfileTap()
            }) {
                HStack(spacing: 12) {
                    // Profile Avatar - Clickable
                    ZStack {
                        Circle()
                            .fill(Color.arkadGold.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(post.authorUsername.prefix(1)).uppercased())
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.arkadGold)
                            )
                        
                        if isLoadingUser {
                            ProgressView()
                                .scaleEffect(0.6)
                                .foregroundColor(.arkadGold)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        // Username - Clickable with tap indicator
                        HStack {
                            Text("@\(post.authorUsername)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            // Debug indicator
                            if !debugMessage.isEmpty {
                                Text(debugMessage)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Text(formatDate(post.createdAt))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // ✅ Add post menu button
                    Menu {
                        Button(action: {
                            showReportSheet = true
                        }) {
                            Label("Report Post", systemImage: "flag")
                        }
                        
                        // Future menu items can go here
                        // Label("Copy Link", systemImage: "link")
                        // Label("Hide Post", systemImage: "eye.slash")
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Tap indicator
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Post type badge (if not text)
            if post.postType != .text {
                HStack {
                    Spacer()
                    Text(post.postType.displayName)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(postTypeColor(for: post.postType))
                        .cornerRadius(8)
                }
            }
            
            // Post Content
            Text(post.content)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(.primary)
            
            // ✅ ADD THESE NEW SECTIONS HERE - Ticker Display
            if !post.tickers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.tickers, id: \.self) { ticker in
                            Text("$\(ticker)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.arkadGold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.arkadGold.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            
            // ✅ Trading Data Display
            if let tradingData = post.tradingData {
                HStack {
                    Text(tradingData.profitLossEmoji)
                    Text(tradingData.formattedProfitLoss)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(tradingData.isProfitable ? .green : .red)
                    
                    if let positionSize = tradingData.positionSize {
                        Text("• \(positionSize)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            
            // ✅ Image Display
            if !post.imageUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.imageUrls, id: \.self) { imageUrl in
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    )
                            }
                            .frame(width: 120, height: 80)
                            .clipped()
                            .cornerRadius(8)
                            .onTapGesture {
                                // Future: Add full-screen image viewer
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            
            // Engagement Section
            HStack(spacing: 24) {
                // Like button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        homeViewModel.toggleLike(for: post.id)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: homeViewModel.likedPosts.contains(post.id) ? "heart.fill" : "heart")
                            .foregroundColor(homeViewModel.likedPosts.contains(post.id) ? .red : .gray)
                        
                        Text("\(post.likesCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(homeViewModel.likedPosts.contains(post.id) ? .red : .gray)
                    }
                }
                
                // Comment button
                Button(action: {
                    showComments = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "message")
                            .foregroundColor(.gray)
                        
                        Text("\(post.commentsCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                    }
                }
                
                // ✅ Enhanced Share button
                Button(action: {
                    showShareSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.gray)
                        
                        Text("Share")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Bookmark button
                Button(action: {
                    homeViewModel.toggleBookmark(for: post.id)
                }) {
                    Image(systemName: homeViewModel.bookmarkedPosts.contains(post.id) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(homeViewModel.bookmarkedPosts.contains(post.id) ? .arkadGold : .gray)
                }
            }
            .font(.subheadline)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        
        // ✅ Share confirmation toast
        .overlay(
            shareConfirmationToast,
            alignment: .top
        )
        
        // Profile sheet
        .sheet(isPresented: $showOtherUserProfile) {
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
        
        // Comments sheet
        .sheet(isPresented: $showComments) {
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
        
        // ✅ Share action sheet
        .confirmationDialog("Share Post", isPresented: $showShareSheet, titleVisibility: .visible) {
            Button("Copy Post Content") {
                copyPostContent()
            }
            
            Button("Copy Link") {
                copyPostLink()
            }
            
            Button("Share via iOS") {
                shareViaIOS()
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose how you'd like to share this post by @\(post.authorUsername)")
        }
        
        // ✅ Report sheet
        .sheet(isPresented: $showReportSheet) {
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
        
        .onAppear {
            debugMessage = authService.isAuthenticated ? "✓" : "✗"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                debugMessage = ""
            }
        }
    }
    
    // ✅ Share confirmation toast view
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
    
    // MARK: - Sharing Functions
    
    private func copyPostContent() {
        let content = """
        @\(post.authorUsername): \(post.content)
        
        — Shared from ArkadTrader
        """
        
        UIPasteboard.general.string = content
        showShareMessage("Post content copied!")
        
        print("📋 Copied post content: \(post.content)")
    }
    
    private func copyPostLink() {
        // Generate a shareable link (you can customize this format)
        let link = "https://arkadtrader.app/post/\(post.id)"
        
        UIPasteboard.general.string = link
        showShareMessage("Link copied!")
        
        print("🔗 Copied post link: \(link)")
    }
    
    private func shareViaIOS() {
        let content = """
        Check out this post from @\(post.authorUsername) on ArkadTrader:
        
        \(post.content)
        
        https://arkadtrader.app/post/\(post.id)
        """
        
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
        
        window.rootViewController?.present(activityController, animated: true)
        
        print("📱 Opened iOS share sheet for post: \(post.id)")
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
        print("🔄 handleProfileTap() called")
        print("📋 Post Author ID: \(post.authorId)")
        print("👤 Post Author Username: \(post.authorUsername)")
        print("🔐 Auth Service Current User: \(authService.currentUser?.id ?? "nil")")
        print("✅ Is Authenticated: \(authService.isAuthenticated)")
        
        debugMessage = "Loading..."
        
        // Check if this is the current user's post
        if let currentUser = authService.currentUser,
           currentUser.id == post.authorId {
            print("👤 User tapped their own profile - not opening modal")
            debugMessage = "Your post"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                debugMessage = ""
            }
            return
        }
        
        // Load other user's profile
        Task {
            await loadUserProfile()
        }
    }
    
    private func loadUserProfile() async {
        print("🔄 loadUserProfile() started")
        
        guard profileUser == nil else {
            print("✅ Profile already loaded, showing modal")
            await MainActor.run {
                showOtherUserProfile = true
                debugMessage = ""
            }
            return
        }
        
        await MainActor.run {
            isLoadingUser = true
            debugMessage = "Loading..."
        }
        
        do {
            print("🔍 Fetching user by ID: \(post.authorId)")
            
            if let user = try await authService.getUserById(userId: post.authorId) {
                print("✅ User found: \(user.username)")
                await MainActor.run {
                    profileUser = user
                    isLoadingUser = false
                    debugMessage = "Found!"
                    showOtherUserProfile = true
                }
            } else {
                print("⚠️ User not found, creating minimal user")
                await MainActor.run {
                    profileUser = createMinimalUser()
                    isLoadingUser = false
                    debugMessage = "Minimal"
                    showOtherUserProfile = true
                }
            }
        } catch {
            print("❌ Error loading user profile: \(error)")
            
            await MainActor.run {
                profileUser = createMinimalUser()
                isLoadingUser = false
                debugMessage = "Error"
                showOtherUserProfile = true
            }
        }
        
        // Clear debug message after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            debugMessage = ""
        }
    }
    
    private func createMinimalUser() -> User {
        print("🔨 Creating minimal user for: \(post.authorUsername)")
        
        var user = User(
            id: post.authorId,
            email: "\(post.authorUsername)@example.com",
            username: post.authorUsername,
            fullName: post.authorUsername.capitalized
        )
        
        user.bio = "Trader on ArkadTrader"
        user.followersCount = 0
        user.followingCount = 0
        user.totalProfitLoss = 0.0
        user.winRate = 0.0
        
        return user
    }
    
    // MARK: - Helper Methods
    
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
