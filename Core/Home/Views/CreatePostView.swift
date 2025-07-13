// Enhanced CreatePostView with Image Support and Better UX
// Replace your existing CreatePostView.swift with this enhanced version

import SwiftUI
import PhotosUI

struct CreatePostView: View {
    let onPost: (Post, [UIImage]?) -> Void
        @Environment(\.dismiss) var dismiss
        @EnvironmentObject var authService: FirebaseAuthService
        
        // MARK: - State Variables (Make sure these are all present)
        @State private var content: String = ""
        @State private var selectedPostType: PostType = .text
        @State private var isPosting: Bool = false
        @State private var characterCount: Int = 0
        @State private var showCharacterWarning: Bool = false
        
        // Image handling
        @State private var selectedImages: [UIImage] = []
        @State private var showingImagePicker: Bool = false
        @State private var photoPickerItems: [PhotosPickerItem] = []
        @State private var isLoadingImages: Bool = false
        
        // UI State
        @State private var showEmojiPicker: Bool = false
        @State private var showPostTypeSelector: Bool = false
        @State private var showPreview: Bool = false
        @State private var selectedEmoji: String = ""
        @State private var showImageFullScreen: Bool = false
        @State private var selectedImageIndex: Int = 0
        
        // Validation & Limits
        private let maxCharacters: Int = 280
        private let warningThreshold: Int = 250
        private let maxImages: Int = 4
        
        // Common trading emojis
        private let tradingEmojis: [String] = ["📈", "📉", "💰", "🚀", "📊", "💎", "🔥", "⚡", "🎯", "💪", "🏆", "⭐"]
        
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.gray.opacity(0.05)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // User Info Section
                        userInfoSection
                        
                        // Post Type Selector
                        postTypeSection
                        
                        // Content Editor
                        contentEditorSection
                        
                        // Image Section
                        if !selectedImages.isEmpty || selectedPostType == .image {
                            imageSection
                        }
                        
                        // Action Buttons
                        actionButtonsSection
                        
                        // Character Count
                        characterCountSection
                        
                        // Preview Section
                        if showPreview && (!content.isEmpty || !selectedImages.isEmpty) {
                            previewSection
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        createPost()
                    } label: {
                        if isPosting || isLoadingImages {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Posting...")
                            }
                        } else {
                            Text("Post")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(canPost ? .arkadGold : .gray)
                    .disabled(!canPost || isPosting || isLoadingImages)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            PhotosPicker(
                selection: $photoPickerItems,
                maxSelectionCount: maxImages,
                matching: .images
            ) {
                Text("Select Photos")
            }
        }
        .onChange(of: photoPickerItems) { _, newItems in
            loadImages(from: newItems)
        }
        .fullScreenCover(isPresented: $showImageFullScreen) {
            ImageFullScreenView(
                images: selectedImages,
                selectedIndex: $selectedImageIndex
            )
        }
    }
    
    // MARK: - View Components
    
    private var userInfoSection: some View {
        HStack(spacing: 12) {
            // User Avatar
            Circle()
                .fill(Color.arkadGold.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(authService.currentUser?.username.prefix(1).uppercased() ?? "U"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.arkadGold)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(authService.currentUser?.username ?? "username")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Posting to feed")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var postTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Post Type")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring()) {
                        showPostTypeSelector.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: selectedPostType.icon)
                            .foregroundColor(colorForPostType(selectedPostType))
                        
                        Text(selectedPostType.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Image(systemName: showPostTypeSelector ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.arkadGold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.arkadGold.opacity(0.1))
                    .cornerRadius(20)
                }
            }
            
            if showPostTypeSelector {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(PostType.allCases, id: \.self) { type in
                        Button(action: {
                            selectedPostType = type
                            withAnimation(.spring()) {
                                showPostTypeSelector = false
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: type.icon)
                                    .foregroundColor(colorForPostType(type))
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text(type.placeholder.prefix(25) + "...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                if selectedPostType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.arkadGold)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedPostType == type ? Color.arkadGold.opacity(0.1) : Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedPostType == type ? Color.arkadGold.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var contentEditorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                
                VStack(spacing: 0) {
                    TextEditor(text: $content)
                        .font(.body)
                        .lineSpacing(4)
                        .padding(16)
                        .background(Color.clear)
                        .onChange(of: content) { _, newValue in
                            updateCharacterCount()
                        }
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                    
                    // Placeholder
                    if content.isEmpty {
                        HStack {
                            Text(selectedPostType.placeholder)
                                .font(.body)
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.leading, 20)
                            Spacer()
                        }
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .offset(y: -90)
                    }
                }
            }
            
            // Quick Action Emojis
            if showEmojiPicker {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(tradingEmojis, id: \.self) { emoji in
                            Button(action: {
                                content += emoji
                                updateCharacterCount()
                            }) {
                                Text(emoji)
                                    .font(.title2)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .transition(.slide)
            }
        }
    }
    
    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Images (\(selectedImages.count)/\(maxImages))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if selectedImages.count < maxImages {
                    Button("Add Photos") {
                        showingImagePicker = true
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.arkadGold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.arkadGold.opacity(0.1))
                    .cornerRadius(16)
                }
            }
            
            Group {
                if isLoadingImages {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading images...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                } else if !selectedImages.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Button(action: {
                                    selectedImageIndex = index
                                    showImageFullScreen = true
                                }) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 120)
                                        .clipped()
                                        .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        selectedImages.remove(at: index)
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Color.white, in: Circle())
                                }
                                .padding(8)
                            }
                        }
                    }
                } else {
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.title)
                                .foregroundColor(.arkadGold)
                            
                            Text("Add photos to your post")
                                .font(.subheadline)
                                .foregroundColor(.arkadGold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.arkadGold.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .background(Color.arkadGold.opacity(0.05))
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    
    
    private var characterCountSection: some View {
        HStack {
            Spacer()
            
            Text("\(characterCount)/\(maxCharacters)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(characterCountColor)
            
            Circle()
                .trim(from: 0, to: CGFloat(characterCount) / CGFloat(maxCharacters))
                .stroke(characterCountColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: characterCount)
        }
        .padding(.horizontal, 16)
        .opacity(characterCount > 0 ? 1 : 0.3)
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Mock post preview
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.arkadGold.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(authService.currentUser?.username.prefix(1).uppercased() ?? "U"))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.arkadGold)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("@\(authService.currentUser?.username ?? "username")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("now")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if selectedPostType != .text {
                        Text(selectedPostType.displayName)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(colorForPostType(selectedPostType))
                            .cornerRadius(8)
                    }
                }
                
                if !content.isEmpty {
                    Text(content)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundColor(.primary)
                }
                
                if !selectedImages.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(selectedImages.count, 2)), spacing: 8) {
                        ForEach(Array(selectedImages.prefix(4).enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 100)
                                .clipped()
                                .cornerRadius(8)
                        }
                    }
                }
                
                HStack(spacing: 24) {
                    Label("0", systemImage: "heart")
                    Label("0", systemImage: "message")
                    Label("Share", systemImage: "square.and.arrow.up")
                    Spacer()
                    Image(systemName: "bookmark")
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Helper Methods
    
    private var canPost: Bool {
        (!content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty) &&
        characterCount <= maxCharacters &&
        !isPosting &&
        !isLoadingImages
    }
    
    private var characterCountColor: Color {
        if characterCount > maxCharacters {
            return .red
        } else if characterCount > warningThreshold {
            return .orange
        } else {
            return .arkadGold
        }
    }
    
    private func updateCharacterCount() {
        characterCount = content.count
        showCharacterWarning = characterCount > warningThreshold
    }
    
    private func colorForPostType(_ type: PostType) -> Color {
        switch type {
        case .text: return .blue
        case .tradeResult: return .green
        case .marketAnalysis: return .purple
        case .image: return .orange  // <- Add this missing case
        }
    }
    private func postTypeIcon(for type: PostType) -> String {
        switch type {
        case .text: return "text.bubble"
        case .tradeResult: return "chart.line.uptrend.xyaxis"
        case .marketAnalysis: return "chart.bar.doc.horizontal"
        case .image: return "photo"  // <- Add this missing case
        }
    }
    
    private func loadImages(from items: [PhotosPickerItem]) {
        isLoadingImages = true
        selectedImages.removeAll()
        
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImages.append(image)
                    }
                }
            }
            
            await MainActor.run {
                isLoadingImages = false
                // Auto-set to image type if images are added
                if !selectedImages.isEmpty && selectedPostType == .text {
                    selectedPostType = .image
                }
            }
        }
    }
    
    private func createPost() {
        guard canPost else { return }
        
        guard let userId = authService.currentUser?.id,
              let username = authService.currentUser?.username else { return }
        
        isPosting = true
        
        // Create post object
        let newPost = Post(
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            authorId: userId,
            authorUsername: username,
            imageUrls: nil // URLs will be set after upload
        )
        
        var finalPost = newPost
        finalPost.postType = selectedPostType
        
        // Pass to parent with images
        onPost(finalPost, selectedImages.isEmpty ? nil : selectedImages)
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        dismiss()
    }
    
    private func clearAll() {
        withAnimation(.easeInOut(duration: 0.3)) {
            content = ""
            selectedImages.removeAll()
            characterCount = 0
            showCharacterWarning = false
            selectedPostType = .text
        }
    }
}

// MARK: - Full Screen Image View

struct ImageFullScreenView: View {
    let images: [UIImage]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            
            VStack {
                HStack {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                Spacer()
            }
        }
    }
}

#Preview {
    CreatePostView { post, images in
        print("Created post: \(post.content)")
        if let images = images {
            print("With \(images.count) images")
        }
    }
    .environmentObject(FirebaseAuthService.shared)
}
