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
       @State private var likedComments: Set<String> = []  // ✅ Add this

       
       @EnvironmentObject var authService: FirebaseAuthService
       @Environment(\.dismiss) var dismiss
       
    
    var body: some View {
        NavigationView {
            VStack {
                            // Comments list
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(comments) { comment in
                                        CommentRowView(
                                            comment: comment,
                                            isInitiallyLiked: likedComments.contains(comment.id)  // ✅ Pass initial state
                                        ) {
                                            Task {
                                                await deleteComment(comment)
                                            }
                                        }
                                    }
                                }
                                .padding()
                            }
                
                // New comment input
                HStack {
                    TextField("Write a comment...", text: $newCommentText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        Task {
                            await addComment()
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.arkadGold)
                            .font(.title2)
                    }
                    .disabled(newCommentText.isEmpty || isLoading)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadComments()
                await loadLikedComments()  // ✅ Add this

            }
        }
    }
    private func loadLikedComments() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            likedComments = try await authService.getUserLikedComments(userId: userId)
            print("✅ Loaded \(likedComments.count) liked comments")
            print("📝 Liked comment IDs: \(likedComments)")
            
            // Debug: Check if our comment is in the liked set
            for comment in comments {
                let isLiked = likedComments.contains(comment.id)
                print("🔍 Comment '\(comment.content)' (ID: \(comment.id)) - isLiked: \(isLiked)")
            }
            
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

            print("✅ Loaded \(comments.count) comments")
            
            for (index, comment) in comments.enumerated() {
                print("📝 Comment \(index + 1): @\(comment.authorUsername): '\(comment.content)'")
            }
            
        } catch {
            print("❌ ERROR loading comments: \(error)")
            print("📋 Error details: \(error.localizedDescription)")
        }
        isLoading = false
        print("🏁 === FINISHED LOADING COMMENTS ===")
    }
    private func deleteComment(_ comment: Comment) async {
        print("🗑️ Deleting comment: \(comment.content)")
        
        do {
            try await authService.deleteComment(commentId: comment.id, postId: postId)
            print("✅ Comment deleted successfully")
            
            await loadComments()
            
            // ✅ Update the comment count in main feed
            onCommentCountChanged(comments.count)
            
        } catch {
            print("❌ Error deleting comment: \(error)")
        }
    }
    
    private func addComment() async {
        print("🔵 === ADDING COMMENT ===")
        print("📝 Comment text: '\(newCommentText)'")
        print("🆔 Post ID: '\(postId)'")
        print("👤 Current user: \(authService.currentUser?.username ?? "nil")")
        
        guard !newCommentText.isEmpty,
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
                    authorUsername: currentUser.username
                )
                
                print("✅ Comment added successfully!")
                newCommentText = ""
                await loadComments()
                
                // ✅ Update the comment count in main feed
                onCommentCountChanged(comments.count)
                
            } catch {
                print("❌ ERROR adding comment: \(error)")
            }
            
            isLoading = false
    }
}


struct CommentRowView: View {
    let comment: Comment
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var isLiked = false
    @State private var likesCount: Int
    
    let onDelete: () -> Void
    
    // Simplified init - remove the onLikeChanged for now
    init(comment: Comment, isInitiallyLiked: Bool, onDelete: @escaping () -> Void) {
        self.comment = comment
        self.onDelete = onDelete
        self._likesCount = State(initialValue: comment.likesCount)
        self._isLiked = State(initialValue: isInitiallyLiked)
        
        print("💡 CommentRowView init - Comment: '\(comment.content)' (ID: \(comment.id)) - isInitiallyLiked: \(isInitiallyLiked)")
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(comment.authorUsername)")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("@\(comment.authorUsername)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Delete button for own comments
                    if comment.authorId == authService.currentUser?.id {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(4)
                        }
                    }
                    
                    Text(comment.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(comment.content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                
                // ✅ Add like button here
                HStack {
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
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
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
