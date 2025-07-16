//
//  CommentsView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/16/25.
//


import SwiftUI

struct CommentsView: View {
    let postId: String
    @State private var comments: [Comment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                // Comments list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(comments) { comment in
                            CommentRowView(comment: comment)
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
            }
        }
    }
    
    private func loadComments() async {
        isLoading = true
        do {
            comments = try await authService.getComments(postId: postId)
        } catch {
            print("Error loading comments: \(error)")
        }
        isLoading = false
    }
    
    private func addComment() async {
        guard !newCommentText.isEmpty,
              let currentUser = authService.currentUser else { return }
        
        isLoading = true
        
        do {
            try await authService.addComment(
                postId: postId,
                content: newCommentText,
                authorId: currentUser.id,
                authorUsername: currentUser.username
            )
            
            newCommentText = ""
            await loadComments()
        } catch {
            print("Error adding comment: \(error)")
        }
        
        isLoading = false
    }
}

struct CommentRowView: View {
    let comment: Comment
    
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
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("@\(comment.authorUsername)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(comment.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(comment.content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}
