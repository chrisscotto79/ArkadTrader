// File: Core/Home/Views/Components/PostCard.swift
// Enhanced PostCard with all user interactions

import SwiftUI

// File: Core/Home/Views/Components/PostCard.swift
// Simple PostCard component for HomeView

import SwiftUI

struct PostCard: View {
    let post: Post
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var homeViewModel: HomeViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Post header
            HStack(spacing: 12) {
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
                
                // Post type indicator
                Image(systemName: post.postType.icon)
                    .font(.caption)
                    .foregroundColor(post.postType.displayColor)
                    .padding(6)
                    .background(post.postType.displayColor.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // Post content
            Text(post.content)
                .font(.body)
                .lineLimit(nil)
            
            // Engagement buttons
            HStack(spacing: 20) {
                // Like button
                Button(action: {
                    Task {
                        await homeViewModel.toggleLike(postId: post.id)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .secondary)
                        
                        Text("\(post.likesCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Comment button
                Button(action: {
                    homeViewModel.showPostDetail(post: post)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .foregroundColor(.secondary)
                        
                        Text("\(post.commentsCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Bookmark button
                Button(action: {
                    Task {
                        await homeViewModel.toggleBookmark(postId: post.id)
                    }
                }) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isBookmarked ? .arkadGold : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // More options
                Button(action: {
                    // TODO: Show options menu
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Computed Properties
    private var isLiked: Bool {
        homeViewModel.likedPosts.contains(post.id)
    }
    
    private var isBookmarked: Bool {
        homeViewModel.bookmarkedPosts.contains(post.id)
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
