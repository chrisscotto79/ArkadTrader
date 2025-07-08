//
//  CreatePostView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/8/25.
//


// File: Core/Home/Views/CreatePostView.swift
// Enhanced Create Post View with rich editing features and better UX

import SwiftUI

struct CreatePostView: View {
    let onPost: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var content = ""
    @State private var selectedPostType: PostType = .text
    @State private var isPosting = false
    @State private var characterCount = 0
    @State private var showCharacterWarning = false
    @State private var selectedEmoji = ""
    @State private var showEmojiPicker = false
    @State private var showPostTypeSelector = false
    @State private var showPreview = false
    
    private let maxCharacters = 280
    private let warningThreshold = 250
    
    // Common trading emojis
    private let tradingEmojis = ["📈", "📉", "💰", "🚀", "📊", "💎", "🔥", "⚡", "🎯", "💪", "🏆", "⭐"]
    
    // Post type suggestions
    private let postTypeSuggestions: [PostType: String] = [
        .text: "Share your thoughts...",
        .tradeResult: "Share your trade results and insights",
        .marketAnalysis: "Share your market analysis and predictions"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                Color.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // User Avatar and Info
                        userInfoSection
                        
                        // Post Type Selector
                        postTypeSection
                        
                        // Content Editor
                        contentEditorSection
                        
                        // Quick Actions
                        quickActionsSection
                        
                        // Character Count and Warnings
                        characterCountSection
                        
                        // Post Preview
                        if showPreview && !content.isEmpty {
                            postPreviewSection
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
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
                    Button("Post") {
                        createPost()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(canPost ? .arkadGold : .gray)
                    .disabled(!canPost || isPosting)
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView(selectedEmoji: $selectedEmoji) { emoji in
                content += emoji
                updateCharacterCount()
            }
        }
    }
    
    // MARK: - User Info Section
    private var userInfoSection: some View {
        HStack(spacing: 12) {
            // User Avatar
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.arkadGold, Color.arkadGoldLight]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text("U") // This would be user's initials
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.arkadGold)
                        )
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Name") // This would be user's name
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Text("Posting to ArkadTrader")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            // Privacy/Audience selector (future feature)
            Button(action: {}) {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption)
                    Text("Public")
                        .font(.caption)
                }
                .foregroundColor(.arkadGold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.arkadGold.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Post Type Section
    private var postTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Post Type")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Button("Suggestions") {
                    showPostTypeSelector.toggle()
                }
                .font(.caption)
                .foregroundColor(.arkadGold)
            }
            
            // Post Type Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PostType.allCases, id: \.self) { type in
                        PostTypePill(
                            type: type,
                            isSelected: selectedPostType == type
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedPostType = type
                                updatePlaceholder()
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            
            if showPostTypeSelector {
                postTypeSuggestionsView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showPostTypeSelector)
    }
    
    // MARK: - Content Editor Section
    private var contentEditorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Text Editor
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                
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
                    
                    // Placeholder when empty
                    if content.isEmpty {
                        VStack {
                            HStack {
                                Text(postTypeSuggestions[selectedPostType] ?? "What's on your mind?")
                                    .font(.body)
                                    .foregroundColor(.textTertiary)
                                    .padding(.leading, 20)
                                    .padding(.top, 24)
                                
                                Spacer()
                            }
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 120)
            }
            
            // Quick Text Shortcuts
            quickTextShortcuts
        }
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                QuickActionButton(
                    icon: "face.smiling",
                    title: "Emoji",
                    color: .warning
                ) {
                    showEmojiPicker = true
                }
                
                QuickActionButton(
                    icon: "eye",
                    title: "Preview",
                    color: .info
                ) {
                    showPreview.toggle()
                }
                
                QuickActionButton(
                    icon: "doc.text",
                    title: "Template",
                    color: .stockColor
                ) {
                    insertTemplate()
                }
                
                QuickActionButton(
                    icon: "trash",
                    title: "Clear",
                    color: .error
                ) {
                    clearContent()
                }
            }
        }
    }
    
    // MARK: - Character Count Section
    private var characterCountSection: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                
                // Character count with progress ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(characterCount) / CGFloat(maxCharacters))
                        .stroke(characterCountColor, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                    
                    if characterCount > warningThreshold {
                        Text("\(maxCharacters - characterCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(characterCountColor)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: characterCount)
            }
            
            if characterCount > warningThreshold {
                HStack {
                    Spacer()
                    Text("\(characterCount)/\(maxCharacters) characters")
                        .font(.caption)
                        .foregroundColor(characterCountColor)
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: characterCount > warningThreshold)
    }
    
    // MARK: - Post Preview Section
    private var postPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Button("Hide") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showPreview = false
                    }
                }
                .font(.caption)
                .foregroundColor(.arkadGold)
            }
            
            // Mock post preview
            PostPreview(
                content: content,
                postType: selectedPostType,
                username: "your_username" // This would be actual username
            )
        }
    }
    
    // MARK: - Quick Text Shortcuts
    private var quickTextShortcuts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(getQuickTexts(), id: \.self) { text in
                    Button(action: {
                        if content.isEmpty {
                            content = text + " "
                        } else {
                            content += " " + text
                        }
                        updateCharacterCount()
                    }) {
                        Text(text)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.arkadGold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.arkadGold.opacity(0.1))
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    // MARK: - Post Type Suggestions View
    private var postTypeSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(PostType.allCases, id: \.self) { type in
                Button(action: {
                    selectedPostType = type
                    showPostTypeSelector = false
                    updatePlaceholder()
                }) {
                    HStack {
                        Image(systemName: postTypeIcon(for: type))
                            .foregroundColor(postTypeColor(for: type))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.textPrimary)
                            
                            Text(postTypeSuggestions[type] ?? "")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        
                        Spacer()
                        
                        if selectedPostType == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.arkadGold)
                        }
                    }
                    .padding(12)
                    .background(selectedPostType == type ? Color.arkadGold.opacity(0.1) : Color.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Computed Properties
    private var canPost: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        characterCount <= maxCharacters &&
        !isPosting
    }
    
    private var characterCountColor: Color {
        if characterCount > maxCharacters {
            return .error
        } else if characterCount > warningThreshold {
            return .warning
        } else {
            return .arkadGold
        }
    }
    
    // MARK: - Helper Methods
    private func updateCharacterCount() {
        characterCount = content.count
        showCharacterWarning = characterCount > warningThreshold
    }
    
    private func updatePlaceholder() {
        // Could add specific placeholder text based on post type
    }
    
    private func createPost() {
        guard canPost else { return }
        
        isPosting = true
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Simulate posting delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onPost(content)
            dismiss()
        }
    }
    
    private func insertTemplate() {
        let templates = getTemplatesForPostType(selectedPostType)
        if let template = templates.first {
            content = template
            updateCharacterCount()
        }
    }
    
    private func clearContent() {
        withAnimation(.easeInOut(duration: 0.2)) {
            content = ""
            characterCount = 0
            showCharacterWarning = false
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func getQuickTexts() -> [String] {
        switch selectedPostType {
        case .text:
            return ["💭", "📈", "📉", "#trading", "#market", "#bullish", "#bearish"]
        case .tradeResult:
            return ["💰", "📊", "🎯", "#profit", "#trade", "#win", "#position"]
        case .marketAnalysis:
            return ["📈", "📉", "🔍", "#analysis", "#forecast", "#technical", "#fundamental"]
        }
    }
    
    private func getTemplatesForPostType(_ type: PostType) -> [String] {
        switch type {
        case .text:
            return ["Just thinking about the market today... 💭"]
        case .tradeResult:
            return ["Just closed my [TICKER] position! 📈 +$[AMOUNT] profit 💰"]
        case .marketAnalysis:
            return ["Looking at [TICKER] chart and seeing [PATTERN]. My prediction: [DIRECTION] 📊"]
        }
    }
    
    private func postTypeIcon(for type: PostType) -> String {
        switch type {
        case .text: return "text.bubble"
        case .tradeResult: return "chart.line.uptrend.xyaxis"
        case .marketAnalysis: return "chart.bar"
        }
    }
    
    private func postTypeColor(for type: PostType) -> Color {
        switch type {
        case .text: return .info
        case .tradeResult: return .success
        case .marketAnalysis: return .warning
        }
    }
}

// MARK: - Supporting Views

struct PostTypePill: View {
    let type: PostType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconForType(type))
                    .font(.caption)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.arkadGold : Color.gray.opacity(0.1))
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
    }
    
    private func iconForType(_ type: PostType) -> String {
        switch type {
        case .text: return "text.bubble"
        case .tradeResult: return "chart.line.uptrend.xyaxis"
        case .marketAnalysis: return "chart.bar"
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

struct PostPreview: View {
    let content: String
    let postType: PostType
    let username: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User header
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.arkadGold.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text("U")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.arkadGold)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(username)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    HStack {
                        Text("now")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        
                        if postType != .text {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            
                            Text(postType.displayName)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(postTypeColor(for: postType))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Content
            Text(content)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(.textPrimary)
            
            // Mock engagement buttons
            HStack(spacing: 24) {
                Label("0", systemImage: "heart")
                Label("0", systemImage: "message")
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .font(.caption)
            .foregroundColor(.textSecondary)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func postTypeColor(for type: PostType) -> Color {
        switch type {
        case .text: return .clear
        case .tradeResult: return .success
        case .marketAnalysis: return .info
        }
    }
}

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    let onEmojiSelected: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    private let tradingEmojis = ["📈", "📉", "💰", "🚀", "📊", "💎", "🔥", "⚡", "🎯", "💪", "🏆", "⭐", "📱", "💻", "🌟", "👑"]
    private let generalEmojis = ["😀", "😂", "🤔", "😎", "🤩", "😍", "👍", "👎", "✨", "🎉", "💯", "🔥", "❤️", "💙", "💚", "🧡"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Trading Emojis
                    emojiSection(title: "Trading & Finance", emojis: tradingEmojis)
                    
                    // General Emojis
                    emojiSection(title: "General", emojis: generalEmojis)
                }
                .padding()
            }
            .navigationTitle("Add Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func emojiSection(title: String, emojis: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(action: {
                        onEmojiSelected(emoji)
                        dismiss()
                    }) {
                        Text(emoji)
                            .font(.title2)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}

#Preview {
    CreatePostView { content in
        print("Posted: \(content)")
    }
}