// File: Core/Home/Views/Components/PostDetailView.swift
// Detailed post view with comments and all interactions

import SwiftUI

struct PostDetailView: View {
    let post: Post
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Post header
                    HStack {
                        AsyncImage(url: URL(string: post.authorProfileImageUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.arkadGold.opacity(0.3))
                                .overlay(
                                    Text(String(post.authorUsername.prefix(1)).uppercased())
                                        .fontWeight(.bold)
                                        .foregroundColor(.arkadGold)
                                )
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@\(post.authorUsername)")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(post.createdAt.timeAgoDisplay)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(.arkadGold)
                    }
                    .padding(.horizontal)
                    
                    // Post content
                    VStack(alignment: .leading, spacing: 12) {
                        Text(post.content)
                            .font(.body)
                            .lineLimit(nil)
                        
                        // Hashtags and tickers
                        if !post.hashtags.isEmpty || !post.tickerSymbols.isEmpty {
                            HStack {
                                ForEach(post.hashtags, id: \.self) { hashtag in
                                    Text("#\(hashtag)")
                                        .font(.caption)
                                        .foregroundColor(.arkadGold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.arkadGold.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                ForEach(post.tickerSymbols, id: \.self) { ticker in
                                    Text("$\(ticker)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        
                        // Engagement stats
                        HStack(spacing: 20) {
                            HStack(spacing: 4) {
                                Image(systemName: "heart")
                                Text("\(post.likesCount)")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "message")
                                Text("\(post.commentsCount)")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text("\(post.sharesCount)")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // TODO: Add comments section here
                    VStack {
                        Text("Comments coming soon...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Post Display Card (Non-interactive version for detail view)
struct PostDisplayCard: View {
    let post: Post
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var homeViewModel: HomeViewModel
    
    @State private var isLiked = false
    @State private var isBookmarked = false
    @State private var likesCount: Int
    @State private var showActionSheet = false
    
    init(post: Post) {
        self.post = post
        self._likesCount = State(initialValue: post.likesCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // User header
            HStack(spacing: 12) {
                // Profile picture
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
                .onTapGesture {
                    homeViewModel.showUserProfile(userId: post.authorId)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Button(action: {
                        homeViewModel.showUserProfile(userId: post.authorId)
                    }) {
                        Text("@\(post.authorUsername)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if post.postType != .text {
                    HStack(spacing: 4) {
                        Image(systemName: post.postType.icon)
                            .font(.caption)
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
                
                Button(action: {
                    showActionSheet = true
                }) {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Post content
            EnhancedText(content: post.content,
                        hashtags: post.hashtags,
                        mentions: post.mentionedUsers,
                        tickers: post.tickerSymbols) { type, value in
                handleTextInteraction(type: type, value: value)
            }
            .font(.body)
            .lineLimit(nil)
            
            // Post images
            if !post.imageUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.imageUrls, id: \.self) { imageUrl in
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 250, height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 250, height: 200)
                                    .overlay(ProgressView())
                            }
                        }
                    }
                }
            }
            
            // Ticker symbols and hashtags
            if !post.tickerSymbols.isEmpty || !post.hashtags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.tickerSymbols, id: \.self) { ticker in
                            Button(action: {
                                homeViewModel.applyTickerFilter(ticker)
                            }) {
                                Text("$\(ticker)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        ForEach(post.hashtags, id: \.self) { hashtag in
                            Button(action: {
                                homeViewModel.applyHashtagFilter(hashtag)
                            }) {
                                Text("#\(hashtag)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            // Interaction bar
            HStack(spacing: 24) {
                Button(action: {
                    Task {
                        await homeViewModel.toggleLike(postId: post.id)
                        isLiked.toggle()
                        likesCount += isLiked ? 1 : -1
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .secondary)
                        Text("\(likesCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                HStack(spacing: 6) {
                    Image(systemName: "message")
                        .foregroundColor(.secondary)
                    Text("\(post.commentsCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    // TODO: Share post
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.secondary)
                        Text("\(post.sharesCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: {
                    Task {
                        await homeViewModel.toggleBookmark(postId: post.id)
                        isBookmarked.toggle()
                    }
                }) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isBookmarked ? .arkadGold : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
        .onAppear {
            isLiked = homeViewModel.likedPosts.contains(post.id)
            isBookmarked = homeViewModel.bookmarkedPosts.contains(post.id)
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("Post Options"),
                buttons: [
                    .default(Text("Copy Link")) {
                        UIPasteboard.general.string = "https://arkad.app/posts/\(post.id)"
                    },
                    .destructive(Text("Report")) {
                        homeViewModel.showReportSheet(post: post)
                    },
                    .cancel()
                ]
            )
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
    
    private func handleTextInteraction(type: TextInteractionType, value: String) {
        switch type {
        case .hashtag:
            homeViewModel.applyHashtagFilter(value)
        case .mention:
            // TODO: Navigate to mentioned user
            break
        case .ticker:
            homeViewModel.applyTickerFilter(value)
        }
    }
}

// MARK: - Comment View
struct CommentView: View {
    let comment: Comment
    let replies: [Comment]
    let onReply: (Comment) -> Void
    let onLike: (String) -> Void
    let onUserTap: (String) -> Void
    
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var isLiked = false
    @State private var showReplies = false
    @State private var likesCount: Int
    
    init(comment: Comment, replies: [Comment], onReply: @escaping (Comment) -> Void, onLike: @escaping (String) -> Void, onUserTap: @escaping (String) -> Void) {
        self.comment = comment
        self.replies = replies
        self.onReply = onReply
        self.onLike = onLike
        self.onUserTap = onUserTap
        self._likesCount = State(initialValue: comment.likesCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Profile picture
                Button(action: {
                    onUserTap(comment.authorId)
                }) {
                    AsyncImage(url: URL(string: comment.authorProfileImageUrl ?? "https://avatar.iran.liara.run/username?username=\(comment.authorUsername)")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Text(String(comment.authorUsername.prefix(1)).uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 6) {
                    // Comment header
                    HStack {
                        Button(action: {
                            onUserTap(comment.authorId)
                        }) {
                            Text("@\(comment.authorUsername)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatTimeAgo(comment.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    // Comment content
                    Text(comment.content)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Comment actions
                    HStack(spacing: 16) {
                        Button(action: {
                            isLiked.toggle()
                            likesCount += isLiked ? 1 : -1
                            onLike(comment.id)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.caption)
                                    .foregroundColor(isLiked ? .red : .secondary)
                                
                                if likesCount > 0 {
                                    Text("\(likesCount)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            onReply(comment)
                        }) {
                            Text("Reply")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                    }
                }
                
                Spacer()
            }
            
            // Replies
            if !replies.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showReplies.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showReplies ? "chevron.down" : "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.arkadGold)
                            
                            Text("\(replies.count) repl\(replies.count == 1 ? "y" : "ies")")
                                .font(.caption)
                                .foregroundColor(.arkadGold)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 44)
                    
                    if showReplies {
                        VStack(spacing: 8) {
                            ForEach(replies, id: \.id) { reply in
                                CommentView(
                                    comment: reply,
                                    replies: [],
                                    onReply: onReply,
                                    onLike: onLike,
                                    onUserTap: onUserTap
                                )
                                .padding(.leading, 44)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Empty Comments View
struct EmptyCommentsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "message")
                .font(.system(size: 40))
                .foregroundColor(.arkadGold.opacity(0.6))
            
            Text("No comments yet")
                .font(.headline)
                .fontWeight(.medium)
            
            Text("Be the first to share your thoughts!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
