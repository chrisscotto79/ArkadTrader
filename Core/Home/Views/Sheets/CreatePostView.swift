// File: Core/Home/Views/Sheets/CreatePostView.swift
// Enhanced create post view with all post types and features

import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var postContent = ""
    @State private var selectedPostType: PostType = .text
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var postImages: [UIImage] = []
    @State private var isPosting = false
    @State private var showDiscardAlert = false
    @State private var showImagePicker = false
    @State private var characterCount = 0
    @State private var detectedHashtags: [String] = []
    @State private var detectedMentions: [String] = []
    @State private var detectedTickers: [String] = []
    
    private let characterLimit = 500
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with user info
                userHeaderSection
                
                // Post type selector
                postTypeSelector
                
                // Content input area
                contentInputArea
                
                // Image attachments
                if !postImages.isEmpty {
                    imageAttachmentsSection
                }
                
                // Detected elements preview
                if !detectedHashtags.isEmpty || !detectedMentions.isEmpty || !detectedTickers.isEmpty {
                    detectedElementsSection
                }
                
                // Bottom toolbar
                bottomToolbar
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasContent {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        handlePost()
                    }
                    .disabled(isPostingDisabled)
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Discard Post?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Writing", role: .cancel) {}
        } message: {
            Text("Are you sure you want to discard this post?")
        }
        .onChange(of: postContent) { newValue in
            updateDetectedElements()
        }
        .onChange(of: selectedImages) { newValue in
            loadSelectedImages()
        }
    }
    
    // MARK: - User Header Section
    private var userHeaderSection: some View {
        HStack(spacing: 12) {
            // User avatar
            AsyncImage(url: URL(string: authService.currentUser?.profileImageUrl ?? "https://avatar.iran.liara.run/username?username=\(authService.currentUser?.username ?? "user")")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.arkadGold.opacity(0.2))
                    .overlay(
                        Text(String(authService.currentUser?.username.prefix(1) ?? "U").uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.arkadGold)
                    )
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(authService.currentUser?.username ?? "user")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Posting as \(selectedPostType.displayName.lowercased())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Post type indicator
            HStack(spacing: 4) {
                Image(systemName: selectedPostType.icon)
                    .font(.caption)
                Text(selectedPostType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(postTypeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(postTypeColor.opacity(0.1))
            .cornerRadius(6)
        }
        .padding()
        .background(Color.white)
    }
    
    // MARK: - Post Type Selector
    private var postTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Post Type")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PostType.allCases, id: \.self) { postType in
                        PostTypeChip(
                            postType: postType,
                            isSelected: selectedPostType == postType
                        ) {
                            withAnimation(.spring()) {
                                selectedPostType = postType
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color.white)
    }
    
    // MARK: - Content Input Area
    private var contentInputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Placeholder text based on post type
            if postContent.isEmpty {
                placeholderText
            }
            
            // Text editor
            TextEditor(text: $postContent)
                .font(.body)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 120)
                .onChange(of: postContent) { newValue in
                    characterCount = newValue.count
                    if characterCount > characterLimit {
                        postContent = String(newValue.prefix(characterLimit))
                        characterCount = characterLimit
                    }
                }
        }
        .padding()
        .background(Color.white)
    }
    
    // MARK: - Placeholder Text
    private var placeholderText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedPostType.placeholder)
                .font(.body)
                .foregroundColor(.secondary)
                .allowsHitTesting(false)
            
            if selectedPostType != .text {
                Text(selectedPostType.tips)
                    .font(.caption)
                    .foregroundColor(.arkadGold)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Image Attachments Section
    private var imageAttachmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Images")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(postImages.count)/4")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(postImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Button(action: {
                                postImages.remove(at: index)
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 24, height: 24)
                                    
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                            .offset(x: 8, y: -8)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color.white)
    }
    
    // MARK: - Detected Elements Section
    private var detectedElementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected in your post")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                if !detectedHashtags.isEmpty {
                    DetectedElementRow(
                        title: "Hashtags",
                        icon: "number",
                        color: .purple,
                        elements: detectedHashtags.map { "#\($0)" }
                    )
                }
                
                if !detectedMentions.isEmpty {
                    DetectedElementRow(
                        title: "Mentions",
                        icon: "at",
                        color: .blue,
                        elements: detectedMentions.map { "@\($0)" }
                    )
                }
                
                if !detectedTickers.isEmpty {
                    DetectedElementRow(
                        title: "Tickers",
                        icon: "dollarsign.circle",
                        color: .green,
                        elements: detectedTickers.map { "$\($0)" }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color.white)
    }
    
    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        VStack(spacing: 12) {
            // Character count and tools
            HStack {
                // Media button
                PhotosPicker(
                    selection: $selectedImages,
                    maxSelectionCount: 4 - postImages.count,
                    matching: .images
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.subheadline)
                        Text("Photos")
                            .font(.caption)
                    }
                    .foregroundColor(.arkadGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.arkadGold.opacity(0.1))
                    .cornerRadius(6)
                }
                .disabled(postImages.count >= 4)
                
                // Emoji button
                Button(action: {
                    // TODO: Add emoji picker
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "face.smiling")
                            .font(.subheadline)
                        Text("Emoji")
                            .font(.caption)
                    }
                    .foregroundColor(.arkadGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.arkadGold.opacity(0.1))
                    .cornerRadius(6)
                }
                
                Spacer()
                
                // Character count
                Text("\(characterCount)/\(characterLimit)")
                    .font(.caption)
                    .foregroundColor(characterCount > characterLimit * 9 / 10 ? .red : .secondary)
            }
            .padding(.horizontal)
            
            // Post button
            Button(action: handlePost) {
                HStack {
                    if isPosting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    }
                    
                    Text(isPosting ? "Posting..." : "Share Post")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isPostingDisabled ? Color.secondary : Color.arkadGold)
                )
            }
            .disabled(isPostingDisabled)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color.white)
    }
    
    // MARK: - Helper Properties
    private var hasContent: Bool {
        !postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !postImages.isEmpty
    }
    
    private var isPostingDisabled: Bool {
        let trimmedContent = postContent.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedContent.isEmpty || trimmedContent.count > characterLimit || isPosting
    }
    
    private var postTypeColor: Color {
        switch selectedPostType {
        case .text: return .blue
        case .tradeResult: return .green
        case .marketAnalysis: return .orange
        case .question: return .purple
        case .news: return .red
        }
    }
    
    // MARK: - Helper Methods
    private func updateDetectedElements() {
        detectedHashtags = extractHashtags(from: postContent)
        detectedMentions = extractMentions(from: postContent)
        detectedTickers = extractTickers(from: postContent)
    }
    
    private func extractHashtags(from text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "#\\w+", options: [])
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        
        return matches.compactMap { match in
            let range = Range(match.range, in: text)!
            let hashtag = String(text[range])
            return String(hashtag.dropFirst()) // Remove the #
        }
    }
    
    private func extractMentions(from text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "@\\w+", options: [])
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        
        return matches.compactMap { match in
            let range = Range(match.range, in: text)!
            let mention = String(text[range])
            return String(mention.dropFirst()) // Remove the @
        }
    }
    
    private func extractTickers(from text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "\\$[A-Z]{1,5}", options: [])
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        
        return matches.compactMap { match in
            let range = Range(match.range, in: text)!
            let ticker = String(text[range])
            return String(ticker.dropFirst()) // Remove the $
        }
    }
    
    private func loadSelectedImages() {
        Task {
            var newImages: [UIImage] = []
            
            for item in selectedImages {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    newImages.append(image)
                }
            }
            
            await MainActor.run {
                postImages.append(contentsOf: newImages)
                selectedImages.removeAll()
            }
        }
    }
    
    private func handlePost() {
        let trimmedContent = postContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty && trimmedContent.count <= characterLimit else { return }
        
        isPosting = true
        
        Task {
            // TODO: Upload images first if any
            var imageUrls: [String] = []
            
            if !postImages.isEmpty {
                // Upload images to Firebase Storage
                // imageUrls = try await uploadImages(postImages)
            }
            
            // Create post
            await homeViewModel.createPost(
                content: trimmedContent,
                postType: selectedPostType,
                imageUrls: imageUrls
            )
            
            await MainActor.run {
                isPosting = false
                dismiss()
            }
        }
    }
}

// MARK: - Post Type Chip
struct PostTypeChip: View {
    let postType: PostType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(postTypeColor.opacity(isSelected ? 1.0 : 0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: postType.icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? .white : postTypeColor)
                }
                
                Text(postType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? postTypeColor : .secondary)
            }
            .frame(width: 80)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var postTypeColor: Color {
        switch postType {
        case .text: return .blue
        case .tradeResult: return .green
        case .marketAnalysis: return .orange
        case .question: return .purple
        case .news: return .red
        }
    }
}

// MARK: - Detected Element Row
struct DetectedElementRow: View {
    let title: String
    let icon: String
    let color: Color
    let elements: [String]
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(elements.prefix(5), id: \.self) { element in
                        Text(element)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if elements.count > 5 {
                        Text("+\(elements.count - 5)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Enhanced Post Types
extension PostType {
    var placeholder: String {
        switch self {
        case .text:
            return "What's on your mind? Share your thoughts with the community..."
        case .tradeResult:
            return "Share your latest trade results. Include ticker, entry/exit prices, P&L, and what you learned..."
        case .marketAnalysis:
            return "Share your market analysis and insights. What do you see in the charts or fundamentals?"
        case .question:
            return "Ask the community a question about trading, markets, or strategies..."
        case .news:
            return "Share important market news or updates. Include source links when possible..."
        }
    }
    
    var tips: String {
        switch self {
        case .text:
            return "💡 Tip: Use hashtags (#profit) and mention users (@username) to increase engagement"
        case .tradeResult:
            return "💡 Tip: Include #trade, ticker symbols ($AAPL), and specific profit/loss details"
        case .marketAnalysis:
            return "💡 Tip: Use #analysis and tag relevant stocks or sectors for better visibility"
        case .question:
            return "💡 Tip: Be specific and use relevant hashtags for better answers from the community"
        case .news:
            return "💡 Tip: Include source links and relevant tickers to provide context"
        }
    }
}

// MARK: - Preview
#Preview {
    CreatePostView()
        .environmentObject(FirebaseAuthService.shared)
        .environmentObject(HomeViewModel())
}
