//
//  CommentsView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/16/25.
//

import SwiftUI

struct CommentsView: View {
    let postId: String
    let onCommentCountChanged: (Int) -> Void
    @State private var comments: [Comment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    @State private var likedComments: Set<String> = []
    
    // ✅ Reply functionality
    @State private var replyingToComment: Comment? = nil
    @State private var replyText = ""
    @State private var showReplyInput = false
    
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    // ✅ Computed properties for organizing comments
    private var topLevelComments: [Comment] {
        return comments.filter { $0.parentCommentId == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    private func getReplies(for commentId: String) -> [Comment] {
        // ✅ Get direct replies to this comment (now all replies are flattened to root level)
        return comments.filter { $0.parentCommentId == commentId }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ✅ Enhanced header with better styling
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Comments")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("\(topLevelComments.count) comment\(topLevelComments.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Done") {
                            dismiss()
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.arkadGold.opacity(0.1))
                        .cornerRadius(20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white, Color.gray.opacity(0.05)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // ✅ Comments list with threaded replies
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isLoading && comments.isEmpty {
                            // Loading state
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Loading comments...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else if comments.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("No comments yet")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Be the first to share your thoughts!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            // Comments with replies
                            ForEach(topLevelComments) { comment in
                                VStack(spacing: 0) {
                                    // Parent comment
                                    CommentRowView(
                                        comment: comment,
                                        isInitiallyLiked: likedComments.contains(comment.id),
                                        isReply: false,
                                        onReply: {
                                            startReply(to: comment)
                                        }
                                    ) {
                                        Task {
                                            await deleteComment(comment)
                                        }
                                    }
                                    
                                    // Replies to this comment
                                    let replies = getReplies(for: comment.id)
                                    if !replies.isEmpty {
                                        VStack(spacing: 0) {
                                            ForEach(replies) { reply in
                                                HStack(spacing: 0) {
                                                    // Reply thread line
                                                    VStack {
                                                        Rectangle()
                                                            .fill(Color.arkadGold.opacity(0.3))
                                                            .frame(width: 2)
                                                        
                                                        Circle()
                                                            .fill(Color.arkadGold.opacity(0.5))
                                                            .frame(width: 6, height: 6)
                                                    }
                                                    .frame(width: 20)
                                                    .padding(.leading, 32)
                                                    
                                                    // Reply content
                                                    CommentRowView(
                                                        comment: reply,
                                                        isInitiallyLiked: likedComments.contains(reply.id),
                                                        isReply: true,
                                                        onReply: {
                                                            startReply(to: reply)
                                                        }
                                                    ) {
                                                        Task {
                                                            await deleteComment(reply)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Divider between comment threads
                                    if comment.id != topLevelComments.last?.id {
                                        Divider()
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // ✅ Enhanced comment input area
                VStack(spacing: 0) {
                    // Reply indicator
                    if let replyingTo = replyingToComment {
                        HStack {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .font(.caption)
                                .foregroundColor(.arkadGold)
                            
                            Text("Replying to @\(replyingTo.authorUsername)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button("Cancel") {
                                cancelReply()
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.arkadGold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.arkadGold.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.arkadGold.opacity(0.05), Color.arkadGold.opacity(0.1)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                    
                    Divider()
                    
                    // Input field
                    HStack(spacing: 12) {
                        // User avatar
                        Circle()
                            .fill(Color.arkadGold.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(authService.currentUser?.username.prefix(1) ?? "U").uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.arkadGold)
                            )
                        
                        // Text input
                        TextField(
                            replyingToComment != nil ? "Write a reply..." : "Write a comment...",
                            text: replyingToComment != nil ? $replyText : $newCommentText
                        )
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.vertical, 8)
                        
                        // Send button
                        Button(action: {
                            Task {
                                if replyingToComment != nil {
                                    await addReply()
                                } else {
                                    await addComment()
                                }
                            }
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(canSendMessage ? .arkadGold : .gray)
                                .font(.title2)
                        }
                        .disabled(!canSendMessage || isLoading)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            Task {
                await loadComments()
                await loadLikedComments()
            }
        }
    }
    
    // ✅ Computed property for send button state
    private var canSendMessage: Bool {
        if replyingToComment != nil {
            return !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    // MARK: - Reply Functions
    
    private func startReply(to comment: Comment) {
        // ✅ Find the root parent for this comment thread
        let rootParent = comment.parentCommentId != nil ?
            topLevelComments.first { $0.id == comment.parentCommentId } ?? comment : comment
        
        replyingToComment = rootParent
        replyText = "@\(comment.authorUsername) "
        showReplyInput = true
        
        print("🔄 Started reply to: \(comment.authorUsername) (will be added to thread: \(rootParent.authorUsername))")
    }
    
    private func cancelReply() {
        replyingToComment = nil
        replyText = ""
        showReplyInput = false
        print("❌ Cancelled reply")
    }
    
    private func addReply() async {
        guard let replyingTo = replyingToComment,
              let currentUser = authService.currentUser,
              !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ Cannot add reply - missing data")
            return
        }
        
        print("🔵 === ADDING REPLY ===")
        print("📝 Reply text: '\(replyText)'")
        print("🆔 Parent comment ID: '\(replyingTo.id)'")
        print("👤 Current user: \(currentUser.username)")
        
        isLoading = true
        
        do {
            // ✅ Always reply to the root parent (Twitter style)
            let rootParentId = replyingTo.parentCommentId ?? replyingTo.id
            
            try await authService.addComment(
                postId: postId,
                content: replyText,
                authorId: currentUser.id,
                authorUsername: currentUser.username,
                parentCommentId: rootParentId  // ✅ Always use root parent
            )
            
            print("✅ Reply added successfully to root parent: \(rootParentId)")
            
            // Clear reply state
            cancelReply()
            
            // Reload comments to show the new reply
            await loadComments()
            
        } catch {
            print("❌ ERROR adding reply: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Existing Functions (Enhanced)
    
    private func loadLikedComments() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            likedComments = try await authService.getUserLikedComments(userId: userId)
            print("✅ Loaded \(likedComments.count) liked comments")
            
        } catch {
            print("❌ Error loading liked comments: \(error)")
        }
    }
    
    private func loadComments() async {
        print("🔍 === LOADING COMMENTS ===")
        print("🆔 Post ID: '\(postId)'")
        
        isLoading = true
        do {
            print("🔄 Fetching comments from authService...")
            comments = try await authService.getCommentsForPost(postId: postId)
            print("✅ Loaded \(comments.count) total comments (including replies)")
            
            // Debug: Show comment structure
            let topLevel = topLevelComments.count
            let replies = comments.count - topLevel
            print("📊 Comment breakdown: \(topLevel) top-level, \(replies) replies")
            
            // ✅ Debug: Show all comments with their parent relationships
            for comment in comments {
                if let parentId = comment.parentCommentId {
                    print("📝 Reply: '\(comment.content)' by @\(comment.authorUsername) -> parent: \(parentId)")
                } else {
                    print("📝 Top-level: '\(comment.content)' by @\(comment.authorUsername)")
                }
            }
            
        } catch {
            print("❌ ERROR loading comments: \(error)")
        }
        isLoading = false
    }
    
    private func deleteComment(_ comment: Comment) async {
        print("🗑️ Deleting comment: \(comment.content)")
        
        do {
            try await authService.deleteComment(commentId: comment.id, postId: postId)
            print("✅ Comment deleted successfully")
            
            await loadComments()
            
            // Update comment count (only count top-level comments)
            onCommentCountChanged(topLevelComments.count)
            
        } catch {
            print("❌ Error deleting comment: \(error)")
        }
    }
    
    private func addComment() async {
        print("🔵 === ADDING COMMENT ===")
        print("📝 Comment text: '\(newCommentText)'")
        print("🆔 Post ID: '\(postId)'")
        print("👤 Current user: \(authService.currentUser?.username ?? "nil")")
        
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUser = authService.currentUser else {
            print("❌ Guard failed - empty text or no user")
            return
        }
        
        isLoading = true
        
        do {
            try await authService.addComment(
                postId: postId,
                content: newCommentText,
                authorId: currentUser.id,
                authorUsername: currentUser.username,
                parentCommentId: nil  // ✅ This makes it a top-level comment
            )
            
            print("✅ Comment added successfully!")
            newCommentText = ""
            await loadComments()
            
            // Update the comment count in main feed (only top-level comments)
            onCommentCountChanged(topLevelComments.count)
            
        } catch {
            print("❌ ERROR adding comment: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Enhanced CommentRowView

struct CommentRowView: View {
    let comment: Comment
    let isInitiallyLiked: Bool
    let isReply: Bool
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var isLiked = false
    @State private var likesCount: Int
    
    let onReply: () -> Void
    let onDelete: () -> Void
    
    init(comment: Comment, isInitiallyLiked: Bool, isReply: Bool = false, onReply: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.comment = comment
        self.isInitiallyLiked = isInitiallyLiked
        self.isReply = isReply
        self.onReply = onReply
        self.onDelete = onDelete
        self._likesCount = State(initialValue: comment.likesCount)
        self._isLiked = State(initialValue: isInitiallyLiked)
        
        print("💡 CommentRowView init - Comment: '\(comment.content)' (ID: \(comment.id)) - isInitiallyLiked: \(isInitiallyLiked)")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // User avatar
                AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(comment.authorUsername)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.arkadGold.opacity(0.2))
                        .overlay(
                            Text(String(comment.authorUsername.prefix(1)).uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.arkadGold)
                        )
                }
                .frame(width: isReply ? 28 : 32, height: isReply ? 28 : 32)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 8) {
                    // Header with username and time
                    HStack {
                        Text("@\(comment.authorUsername)")
                            .font(isReply ? .caption : .subheadline)
                            .fontWeight(.semibold)
                        
                        Text("·")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text(comment.createdAt.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Delete button for own comments
                        if comment.authorId == authService.currentUser?.id {
                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.7))
                                    .padding(4)
                            }
                        }
                    }
                    
                    // Comment content
                    Text(comment.content)
                        .font(isReply ? .subheadline : .body)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Action buttons
                    HStack(spacing: 20) {
                        // Like button
                        Button(action: {
                            Task {
                                await toggleLike()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.caption)
                                    .foregroundColor(isLiked ? .red : .gray)
                                
                                if likesCount > 0 {
                                    Text("\(likesCount)")
                                        .font(.caption)
                                        .foregroundColor(isLiked ? .red : .gray)
                                }
                            }
                        }
                        
                        // Reply button
                        Button(action: onReply) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text("Reply")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .onChange(of: isInitiallyLiked) {
            isLiked = isInitiallyLiked
            print("🔄 CommentRowView: Updated isLiked to \(isInitiallyLiked) for comment: \(comment.content)")
        }
    }
    
    private func toggleLike() async {
        guard let userId = authService.currentUser?.id else {
            print("❌ No user ID for comment like")
            return
        }
        
        print("❤️ Toggling like for comment: \(comment.content)")
        
        // Update UI immediately
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isLiked.toggle()
            likesCount += isLiked ? 1 : -1
        }
        
        // Save to Firebase
        do {
            if isLiked {
                try await authService.likeComment(commentId: comment.id, userId: userId)
                print("✅ Comment liked successfully")
            } else {
                try await authService.unlikeComment(commentId: comment.id, userId: userId)
                print("✅ Comment unliked successfully")
            }
        } catch {
            // Revert UI on error
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isLiked.toggle()
                likesCount += isLiked ? 1 : -1
            }
            print("❌ Error toggling comment like: \(error)")
        }
    }
}
