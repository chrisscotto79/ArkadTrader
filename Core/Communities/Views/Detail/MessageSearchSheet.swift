// File: Core/Communities/Views/Detail/MessageSearchSheet.swift
// Search sheet for finding messages in a channel.

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import FirebaseStorage
import Photos
import MobileCoreServices

// MARK: - Message Search Sheet
struct MessageSearchSheet: View {
    let messages: [CommunityMessage]
    let userCache: [String: User]
    @Binding var searchText: String
    @Binding var searchResults: [CommunityMessage]
    let onMessageSelected: (CommunityMessage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search messages...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                            searchResults = []
                        }
                        .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                Divider()
                
                // Search Results
                if searchText.isEmpty {
                    // Recent messages or suggestions
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("Search Messages")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Find messages, mentions, and shared media")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    }
                } else if searchResults.isEmpty {
                    // No results
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("No Results")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Try different keywords or check spelling")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    }
                } else {
                    // Search Results List
                    List(searchResults) { message in
                        SearchMessageRow(
                            message: message,
                            author: userCache[message.authorId],
                            searchTerm: searchText,
                            onTap: {
                                onMessageSelected(message)
                            }
                        )
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        let query = searchText.lowercased()
        searchResults = messages.filter { message in
            // Search in message content
            message.content.lowercased().contains(query) ||
            // Search in author username
            message.authorUsername.lowercased().contains(query) ||
            // Search in author full name
            (userCache[message.authorId]?.fullName.lowercased().contains(query) ?? false)
        }
        .sorted { $0.createdAt > $1.createdAt } // Most recent first
    }
}

// MARK: - Search Message Row
struct SearchMessageRow: View {
    let message: CommunityMessage
    let author: User?
    let searchTerm: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Author and timestamp
                HStack {
                    // Profile image
                    Group {
                        if let author = author,
                           let profileImageUrl = author.profileImageUrl,
                           !profileImageUrl.isEmpty {
                            AsyncImage(url: URL(string: profileImageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.2))
                                    .overlay(
                                        Text(author.fullName.prefix(1))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.accentColor)
                                    )
                            }
                        } else {
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .overlay(
                                    Text(message.authorUsername.prefix(1))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.accentColor)
                                )
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.authorUsername)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(formatTimestamp(message.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Message content with highlighted search term
                Text(highlightedMessageContent)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var highlightedMessageContent: AttributedString {
        var attributedString = AttributedString(message.content)
        
        // Highlight search term (simple version)
        if let range = attributedString.range(of: searchTerm, options: .caseInsensitive) {
            attributedString[range].backgroundColor = .yellow.opacity(0.3)
        }
        
        return attributedString
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}
