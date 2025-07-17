// File: Core/Home/Views/Components/PostCard.swift
// Enhanced PostCard with all user interactions

import SwiftUI

struct PostCard: View {
    let post: Post
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var homeViewModel: HomeViewModel
    
    @State private var isLiked = false
    @State private var isBookmarked = false
    @State private var showActionSheet = false
    @State private var showShareSheet = false
    @State private var showReportSheet = false
    @State private var likesCount: Int
    @State private var commentsCount: Int
    @State private var sharesCount: Int
    
    // Animation states
    @State private var likeAnimationScale: CGFloat = 1.0
    @State private var bookmarkAnimationScale: CGFloat = 1.0
    
    init(post: Post) {
        self.post = post
        self._likesCount = State(initialValue: post.likesCount)
        self._commentsCount = State(initialValue: post.commentsCount)
        self._sharesCount = State(initialValue: post.sharesCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User header (clickable)
            userHeaderSection
            
            // Post content with hashtags and mentions
            postContentSection
            
            // Post images if any
            if !post.imageUrls.isEmpty {
                postImagesSection
            }
            
            // Post type indicator and ticker symbols
            postMetadataSection
            
            // Interaction bar
            interactionBar
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onAppear {
            setupInitialState()
        }
        .sheet(isPresented: $showShareSheet) {
            SharePostView(post: post)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportPostView(post: post)
                .environmentObject(authService)
        }
        .actionSheet(isPresented: $showActionSheet) {
            postActionSheet
        }
    }
    
    // MARK: - User Header Section
    private var userHeaderSection: some View {
        HStack(spacing: 12) {
            // Profile picture (clickable)
            Button(action: {
                handleUserProfileTap()
            }) {
                AsyncImage(url: URL(string: post.authorProfileImageUrl ?? "https://avatar.iran.liara.run/username?username=\(post.authorUsername)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.arkadGold.opacity(0.2))
                        .overlay(
                            Text(String(post.authorUsername.prefix(1)).uppercased())
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.arkadGold)
                        )
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 2) {
                // Username (clickable)
                Button(action: {
                    handleUserProfileTap()
                }) {
                    Text("@\(post.authorUsername)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Time and post type
                HStack(spacing: 4) {
                    Text(formatTimeAgo(post.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if post.postType != .text {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 2) {
                            Image(systemName: post.postType.icon)
                                .font(.caption2)
                                .foregroundColor(postTypeColor)
                            
                            Text(post.postType.displayName)
                                .font(.caption)
                                .foregroundColor(postTypeColor)
                        }
                    }
                }
            }
            
            Spacer()
            
            // More options button
            Button(action: {
                showActionSheet = true
            }) {
                Image(systemName: "ellipsis")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Post Content Section
    private var postContentSection: some View {
        Button(action: {
            handlePostTap()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Main content with enhanced text
                EnhancedText(content: post.content,
                           hashtags: post.hashtags,
                           mentions: post.mentionedUsers,
                           tickers: post.tickerSymbols) { interactionType, value in
                    handleTextInteraction(type: interactionType, value: value)
                }
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Post Images Section
    private var postImagesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(post.imageUrls, id: \.self) { imageUrl in
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 200, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 200, height: 150)
                            .overlay(
                                ProgressView()
                            )
                    }
                    .onTapGesture {
                        // TODO: Show full screen image viewer
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Post Metadata Section
    private var postMetadataSection: some View {
        HStack {
            // Ticker symbols
            if !post.tickerSymbols.isEmpty {
                HStack(spacing: 4) {
                    ForEach(post.tickerSymbols.prefix(3), id: \.self) { ticker in
                        Button(action: {
                            homeViewModel.applyTickerFilter(ticker)
                        }) {
                            Text("$\(ticker)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if post.tickerSymbols.count > 3 {
                        Text("+\(post.tickerSymbols.count - 3)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Post type badge
            if post.postType != .text {
                Button(action: {
                    let filter: PostFilter = {
                        switch post.postType {
                        case .tradeResult: return .trades
                        case .marketAnalysis: return .analysis
                        case .question: return .questions
                        case .news: return .news
                        case .text: return .all
                        }
                    }()
                    homeViewModel.applyFilter(filter)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: post.postType.icon)
                            .font(.caption2)
                        Text(post.postType.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(postTypeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(postTypeColor.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Interaction Bar
    private var interactionBar: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)
            
            HStack(spacing: 0) {
                // Like button
                Button(action: {
                    handleLikeTap()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.subheadline)
                            .foregroundColor(isLiked ? .red : .secondary)
                            .scaleEffect(likeAnimationScale)
                        
                        Text("\(likesCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Comment button
                Button(action: {
                    handleCommentTap()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "message")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(commentsCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Share button
                Button(action: {
                    handleShareTap()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if sharesCount > 0 {
                            Text("\(sharesCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Share")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Bookmark button
                Button(action: {
                    handleBookmarkTap()
                }) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.subheadline)
                        .foregroundColor(isBookmarked ? .arkadGold : .secondary)
                        .scaleEffect(bookmarkAnimationScale)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Action Sheet
    private var postActionSheet: ActionSheet {
        var buttons: [ActionSheet.Button] = []
        
        // Save/Unsave button
        if isBookmarked {
            buttons.append(.default(Text("Remove from Saved")) {
                Task { await handleBookmarkTap() }
            })
        } else {
            buttons.append(.default(Text("Save Post")) {
                Task { await handleBookmarkTap() }
            })
        }
        
        // Copy link button
        buttons.append(.default(Text("Copy Link")) {
            handleCopyLink()
        })
        
        // Report button (only for other users' posts)
        if post.authorId != authService.currentUser?.id {
            buttons.append(.destructive(Text("Report Post")) {
                showReportSheet = true
            })
        }
        
        // Block user button (only for other users' posts)
        if post.authorId != authService.currentUser?.id {
            buttons.append(.destructive(Text("Block User")) {
                // TODO: Implement block user functionality
            })
        }
        
        buttons.append(.cancel())
        
        return ActionSheet(
            title: Text("Post Options"),
            message: Text("Choose an action"),
            buttons: buttons
        )
    }
    
    // MARK: - Helper Methods
    private func setupInitialState() {
        isLiked = homeViewModel.likedPosts.contains(post.id)
        isBookmarked = homeViewModel.bookmarkedPosts.contains(post.id)
        likesCount = post.likesCount
        commentsCount = post.commentsCount
        sharesCount = post.sharesCount
    }
    
    private func handleUserProfileTap() {
        homeViewModel.showUserProfile(userId: post.authorId)
    }
    
    private func handlePostTap() {
        homeViewModel.showPostDetail(post: post)
    }
    
    private func handleLikeTap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
            likesCount += isLiked ? 1 : -1
            
            // Heart animation
            likeAnimationScale = 1.3
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    likeAnimationScale = 1.0
                }
            }
        }
        
        // Update global state
        if isLiked {
            homeViewModel.likedPosts.insert(post.id)
        } else {
            homeViewModel.likedPosts.remove(post.id)
        }
        
        // Sync with Firebase
        Task {
            await homeViewModel.toggleLike(postId: post.id)
        }
    }
    
    private func handleCommentTap() {
        homeViewModel.showPostDetail(post: post)
    }
    
    private func handleShareTap() {
        showShareSheet = true
    }
    
    private func handleBookmarkTap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isBookmarked.toggle()
            
            // Bookmark animation
            bookmarkAnimationScale = 1.3
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    bookmarkAnimationScale = 1.0
                }
            }
        }
        
        // Update global state
        if isBookmarked {
            homeViewModel.bookmarkedPosts.insert(post.id)
        } else {
            homeViewModel.bookmarkedPosts.remove(post.id)
        }
        
        // Sync with Firebase
        Task {
            await homeViewModel.toggleBookmark(postId: post.id)
        }
    }
    
    private func handleCopyLink() {
        let postLink = "https://arkad.app/posts/\(post.id)"
        UIPasteboard.general.string = postLink
        
        // Show toast or feedback
        // TODO: Add toast notification
    }
    
    private func handleTextInteraction(type: TextInteractionType, value: String) {
        switch type {
        case .hashtag:
            homeViewModel.applyHashtagFilter(value)
        case .mention:
            // TODO: Navigate to mentioned user's profile
            break
        case .ticker:
            homeViewModel.applyTickerFilter(value)
        }
    }
    
    private var postTypeColor: Color {
        switch post.postType {
        case .text: return .blue
        case .tradeResult: return .green
        case .marketAnalysis: return .orange
        case .question: return .purple
        case .news: return .red
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Enhanced Text Component
enum TextInteractionType {
    case hashtag
    case mention
    case ticker
}

struct EnhancedText: View {
    let content: String
    let hashtags: [String]
    let mentions: [String]
    let tickers: [String]
    let onInteraction: (TextInteractionType, String) -> Void
    
    var body: some View {
        Text(attributedString)
            .font(.body)
            .foregroundColor(.primary)
            .multilineTextAlignment(.leading)
    }
    
    private var attributedString: AttributedString {
        var attributedString = AttributedString(content)
        
        // Style hashtags
        for hashtag in hashtags {
            if let range = attributedString.range(of: "#\(hashtag)") {
                attributedString[range].foregroundColor = .blue
                attributedString[range].font = .body.weight(.medium)
            }
        }
        
        // Style mentions
        for mention in mentions {
            if let range = attributedString.range(of: "@\(mention)") {
                attributedString[range].foregroundColor = .purple
                attributedString[range].font = .body.weight(.medium)
            }
        }
        
        // Style tickers
        for ticker in tickers {
            if let range = attributedString.range(of: "$\(ticker)") {
                attributedString[range].foregroundColor = .green
                attributedString[range].font = .body.weight(.medium)
            }
        }
        
        return attributedString
    }
}

// MARK: - Share Post View
struct SharePostView: View {
    let post: Post
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var homeViewModel: HomeViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Share Post")
                .font(.headline)
                .padding()
            
            VStack(spacing: 16) {
                ForEach(ShareOption.allCases, id: \.self) { option in
                    Button(action: {
                        handleShareOption(option)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: option.icon)
                                .font(.title3)
                                .foregroundColor(.arkadGold)
                                .frame(width: 24)
                            
                            Text(option.displayName)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.secondary)
            .padding()
        }
        .presentationDetents([.height(300)])
    }
    
    private func handleShareOption(_ option: ShareOption) {
        Task {
            await homeViewModel.sharePost(postId: post.id, shareOption: option)
            
            switch option {
            case .copyLink:
                let postLink = "https://arkad.app/posts/\(post.id)"
                UIPasteboard.general.string = postLink
            case .shareToStory:
                // TODO: Implement story sharing
                break
            case .shareExternal:
                // TODO: Implement system share sheet
                break
            }
            
            dismiss()
        }
    }
}

// MARK: - Report Post View
struct ReportPostView: View {
    let post: Post
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedReason: PostReport.ReportReason?
    @State private var additionalDetails = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Why are you reporting this post?")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    ForEach(PostReport.ReportReason.allCases, id: \.self) { reason in
                        Button(action: {
                            selectedReason = reason
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(reason.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text(reason.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedReason == reason {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.arkadGold)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional Details (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    TextEditor(text: $additionalDetails)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Report Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitReport()
                    }
                    .disabled(selectedReason == nil || isSubmitting)
                }
            }
        }
    }
    
    private func submitReport() {
        guard let reason = selectedReason else { return }
        
        isSubmitting = true
        
        Task {
            await homeViewModel.reportPost(
                postId: post.id,
                reason: reason,
                details: additionalDetails.isEmpty ? nil : additionalDetails
            )
            
            await MainActor.run {
                isSubmitting = false
                dismiss()
            }
        }
    }
}
