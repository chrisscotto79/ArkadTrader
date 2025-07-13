// Complete Enhanced UserPostCard.swift
// Replace your entire UserPostCard.swift file with this

import SwiftUI

struct UserPostCard: View {
    let post: Post
    @ObservedObject var homeViewModel: HomeViewModel
    
    // Local state for optimistic UI updates
    @State private var isLiked: Bool = false
    @State private var isBookmarked: Bool = false
    @State private var likesCount: Int = 0
    @State private var showImageViewer: Bool = false
    @State private var selectedImageIndex: Int = 0
    @State private var showActionSheet: Bool = false
    @State private var imageLoadingStates: [String: Bool] = [:]
    
    init(post: Post, homeViewModel: HomeViewModel) {
        self.post = post
        self.homeViewModel = homeViewModel
        self._likesCount = State(initialValue: post.likesCount)
        self._isLiked = State(initialValue: homeViewModel.likedPosts.contains(post.id))
        self._isBookmarked = State(initialValue: homeViewModel.bookmarkedPosts.contains(post.id))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User Header
            userHeaderSection
            
            // Post Content
            postContentSection
            
            // Images Section (if post has images)
            if post.hasImages {
                postImagesSection
            }
            
            // Engagement Section
            engagementSection
            
            // Action Buttons
            actionButtonsSection
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .onAppear {
            updateLocalState()
        }
        .onChange(of: homeViewModel.likedPosts) { _, _ in
            updateLocalState()
        }
        .onChange(of: homeViewModel.bookmarkedPosts) { _, _ in
            updateLocalState()
        }
        .sheet(isPresented: $showImageViewer) {
            ImageViewerSheet(
                imageUrls: post.imageUrls ?? [],
                selectedIndex: $selectedImageIndex
            )
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("Post Options"),
                message: nil,
                buttons: [
                    .default(Text("Share")) {
                        sharePost()
                    },
                    .default(Text("Report")) {
                        reportPost()
                    },
                    .cancel()
                ]
            )
        }
    }
    
    // MARK: - View Components
    
    private var userHeaderSection: some View {
        HStack(spacing: 12) {
            // Profile Avatar
            Circle()
                .fill(Color.arkadGold.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(post.authorUsername.prefix(1)).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.arkadGold)
                )
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(post.authorUsername)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text(formatDate(post.createdAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if post.isEdited {
                        Text("• edited")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            // Post Type Badge
            if post.postType != .text {
                Text(post.postType.displayName)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colorForPostType(post.postType))
                    .cornerRadius(8)
            }
            
            // More Options Button
            Button(action: {
                showActionSheet = true
            }) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .font(.subheadline)
            }
        }
    }
    
    private var postContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !post.content.isEmpty {
                Text(post.content)
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 12)
    }
    
    private var postImagesSection: some View {
        VStack(spacing: 8) {
            if let imageUrls = post.imageUrls, !imageUrls.isEmpty {
                let imageCount = imageUrls.count
                
                if imageCount == 1 {
                    // Single image - full width
                    singleImageView(url: imageUrls[0], index: 0)
                } else if imageCount == 2 {
                    // Two images - side by side
                    HStack(spacing: 8) {
                        ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, url in
                            imageView(url: url, index: index)
                                .frame(maxWidth: .infinity)
                        }
                    }
                } else if imageCount == 3 {
                    // Three images - one large, two small
                    HStack(spacing: 8) {
                        imageView(url: imageUrls[0], index: 0)
                            .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 8) {
                            imageView(url: imageUrls[1], index: 1)
                            imageView(url: imageUrls[2], index: 2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    // Four or more images - 2x2 grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(Array(imageUrls.prefix(4).enumerated()), id: \.offset) { index, url in
                            ZStack {
                                imageView(url: url, index: index)
                                
                                // Show "+X more" overlay for 4th image if there are more
                                if index == 3 && imageUrls.count > 4 {
                                    Rectangle()
                                        .fill(Color.black.opacity(0.5))
                                        .overlay(
                                            Text("+\(imageUrls.count - 4)")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        )
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    private func singleImageView(url: String, index: Int) -> some View {
        Button(action: {
            selectedImageIndex = index
            showImageViewer = true
        }) {
            AsyncImage(url: URL(string: url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: 300)
                    .clipped()
                    .cornerRadius(12)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 250)
                    .cornerRadius(12)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }
        }
    }
    
    private func imageView(url: String, index: Int) -> some View {
        Button(action: {
            selectedImageIndex = index
            showImageViewer = true
        }) {
            AsyncImage(url: URL(string: url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(8)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 120)
                    .cornerRadius(8)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }
        }
    }
    
    private var engagementSection: some View {
        HStack(spacing: 16) {
            if likesCount > 0 || post.commentsCount > 0 {
                HStack(spacing: 12) {
                    if likesCount > 0 {
                        Text("\(likesCount) likes")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if post.commentsCount > 0 {
                        Text("\(post.commentsCount) comments")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            if post.hasImages {
                HStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text("\(post.getImageCount())")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.top, 8)
    }
    
    // Add this computed property to your CreatePostView struct after the imageSection property:

    
    
    // MARK: - Helper Methods
    
    private func updateLocalState() {
        isLiked = homeViewModel.likedPosts.contains(post.id)
        isBookmarked = homeViewModel.bookmarkedPosts.contains(post.id)
        likesCount = post.likesCount
    }
    
    private func handleLikeAction() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Update UI immediately
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
            likesCount += isLiked ? 1 : -1
        }
        
        // Call HomeViewModel method
        homeViewModel.toggleLike(for: post.id)
    }
    
    private func handleBookmarkAction() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Update UI immediately
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isBookmarked.toggle()
        }
        
        // Call HomeViewModel method
        homeViewModel.toggleBookmark(for: post.id)
    }
    
    private func sharePost() {
        let shareText = """
        Check out this post from @\(post.authorUsername):
        
        \(post.content)
        
        Shared via ArkadTrader
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func reportPost() {
        Task {
            await homeViewModel.reportPost(postId: post.id, reason: "Inappropriate content")
        }
    }
    
    private func colorForPostType(_ type: PostType) -> Color {
        switch type {
        case .text: return .blue
        case .tradeResult: return .green
        case .marketAnalysis: return .purple
        case .image: return .orange
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Image Viewer Sheet

struct ImageViewerSheet: View {
    let imageUrls: [String]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selectedIndex) {
                ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, url in
                    AsyncImage(url: URL(string: url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .tag(index)
                    } placeholder: {
                        ProgressView()
                            .foregroundColor(.white)
                            .scaleEffect(1.5)
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            
            VStack {
                HStack {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(20)
                    
                    Spacer()
                    
                    Text("\(selectedIndex + 1) of \(imageUrls.count)")
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)
                }
                .padding()
                
                Spacer()
            }
        }
    }
}


struct ImageViewerSheet: View {
    let imageUrls: [String]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                TabView(selection: $selectedIndex) {
                    ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, urlString in
                        if let url = URL(string: urlString) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .tag(index)
                            } placeholder: {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            }
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Text post preview
        UserPostCard(
            post: Post(content: "Just thinking about the market today... What do you think about the current trends?",
                      authorId: "1",
                      authorUsername: "trader1"),
            homeViewModel: HomeViewModel()
        )
        
        // Image post preview (mock)
        UserPostCard(
            post: {
                var post = Post(content: "Check out this amazing chart pattern! 📈",
                               authorId: "2",
                               authorUsername: "chartmaster",
                               imageUrls: ["https://example.com/image1.jpg"])
                post.postType = .image
                return post
            }(),
            homeViewModel: HomeViewModel()
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
