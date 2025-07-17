// File: Core/Home/Views/Sheets/CreatePostView.swift
// Complete CreatePostView for HomeView - FIXED

import SwiftUI

struct CreatePostView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var postContent = ""
    @State private var selectedPostType: PostType = .text
    @State private var isPosting = false
    @FocusState private var isTextFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Post type selector
                postTypeSelector
                
                // Content input
                contentInputSection
                
                // Footer with tips
                footerSection
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                isTextFocused = true
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.secondary)
            
            Spacer()
            
            Text("Create Post")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button("Post") {
                createPost()
            }
            .disabled(postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
            .foregroundColor(canPost ? .arkadGold : .secondary)
            .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Post Type Selector
    private var postTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PostType.allCases, id: \.self) { type in
                    PostTypeChip(
                        type: type,
                        isSelected: selectedPostType == type
                    ) {
                        selectedPostType = type
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Content Input Section
    private var contentInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: authService.currentUser?.profileImageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.arkadGold.opacity(0.3))
                        .overlay(
                            Text(String(authService.currentUser?.username.prefix(1) ?? "U").uppercased())
                                .fontWeight(.bold)
                                .foregroundColor(.arkadGold)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(authService.currentUser?.fullName ?? "")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("@\(authService.currentUser?.username ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Text input - FIXED binding issue
            TextField(getPlaceholder(for: selectedPostType), text: $postContent, axis: .vertical)
                .font(.body)
                .lineLimit(10...20)
                .focused($isTextFocused)
                .textFieldStyle(PlainTextFieldStyle())
            
            // Character count
            HStack {
                Spacer()
                Text("\(postContent.count)/2000")
                    .font(.caption)
                    .foregroundColor(postContent.count > 2000 ? .red : .secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(getTips(for: selectedPostType))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Post type info
            HStack {
                Image(systemName: selectedPostType.icon)
                    .foregroundColor(selectedPostType.displayColor)
                
                Text(selectedPostType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(selectedPostType.displayColor)
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Computed Properties
    private var canPost: Bool {
        !postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        postContent.count <= 2000 &&
        !isPosting
    }
    
    // MARK: - Helper Methods
    private func getPlaceholder(for postType: PostType) -> String {
        switch postType {
        case .text:
            return "What's on your mind? Share your thoughts with the community..."
        case .tradeResult:
            return "Share your latest trade results. Include ticker, entry/exit prices, and what you learned..."
        case .marketAnalysis:
            return "Share your market analysis and insights. What do you see in the charts or fundamentals?"
        }
    }
    
    private func getTips(for postType: PostType) -> String {
        switch postType {
        case .text:
            return "💡 Tip: Use hashtags and mention users with @ to increase engagement"
        case .tradeResult:
            return "💡 Tip: Include #trade, ticker symbols, and profit/loss details"
        case .marketAnalysis:
            return "💡 Tip: Use #analysis and tag relevant stocks or sectors"
        }
    }
    
    // MARK: - Actions
    private func createPost() {
        guard canPost else { return }
        
        isPosting = true
        isTextFocused = false
        
        Task {
            await homeViewModel.createPost(
                content: postContent,
                postType: selectedPostType,
                imageUrls: []
            )
            
            await MainActor.run {
                isPosting = false
                dismiss()
            }
        }
    }
}

// MARK: - Supporting Views
struct PostTypeChip: View {
    let type: PostType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.caption)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : type.displayColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? type.displayColor : type.displayColor.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(type.displayColor, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - PostType Extension for Colors
extension PostType {
    var displayColor: Color {
        switch self {
        case .text: return .blue
        case .tradeResult: return .marketGreen
        case .marketAnalysis: return .orange
        }
    }
}
