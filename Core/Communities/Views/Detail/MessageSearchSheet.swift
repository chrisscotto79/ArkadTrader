// File: Core/Communities/Views/Detail/MessageSearchSheet.swift
// Search sheet for finding messages in a channel.

import SwiftUI

// MARK: - Message Search Sheet
struct MessageSearchSheet: View {
    let messages: [CommunityMessage]
    let userCache: [String: User]
    @Binding var searchText: String
    @Binding var searchResults: [CommunityMessage]
    let onMessageSelected: (CommunityMessage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(.horizontal, DS.pageMargin)
                    .padding(.vertical, DS.Spacing.m)
            }
            .scrollDismissesKeyboard(.immediately)
            .screenBackground()
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Messages, people or tickers"
            )
            .onChange(of: searchText) {
                performSearch()
            }
            .onAppear {
                performSearch()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Color.goldText)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyStateView(
                systemImage: "magnifyingglass",
                title: "Search this channel",
                message: "Find messages, mentions and callouts from the latest \(messages.count) messages."
            )
        } else if searchResults.isEmpty {
            EmptyStateView(
                systemImage: "text.magnifyingglass",
                title: "No results",
                message: "Nothing matches \"\(searchText)\". Try a different word or a username."
            )
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                Text("\(searchResults.count) \(searchResults.count == 1 ? "result" : "results")")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, DS.Spacing.xs)

                CommunityCardList(items: searchResults, dividerInset: DS.Spacing.l) { message in
                    SearchMessageRow(
                        message: message,
                        author: userCache[message.authorId],
                        searchTerm: searchText,
                        onTap: { onMessageSelected(message) }
                    )
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
            guard !message.isDeleted else { return false }
            return message.content.lowercased().contains(query) ||
            message.authorUsername.lowercased().contains(query) ||
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
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                UserAvatar(username: message.authorUsername, imageURL: message.authorAvatarURL ?? author?.profileImageUrl, size: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(message.authorUsername)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Text(formatTimestamp(message.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(highlightedMessageContent)
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(DS.Spacing.l)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    /// Media messages show a label instead of their storage URL
    private var displayContent: String {
        if message.content.hasPrefix("[MEDIA:IMAGE]") { return "Photo" }
        if message.content.hasPrefix("[MEDIA:VIDEO]") { return "Video" }
        if message.content.hasPrefix("[MEDIA:DOCUMENT]") {
            let parts = String(message.content.dropFirst(16)).components(separatedBy: "|")
            return parts.count >= 2 ? "File: \(parts[1])" : "File"
        }
        return message.content
    }

    private var highlightedMessageContent: AttributedString {
        var attributedString = AttributedString(displayContent)
        if let range = attributedString.range(of: searchTerm, options: .caseInsensitive) {
            attributedString[range].backgroundColor = .goldTint
            attributedString[range].font = .subheadline.weight(.semibold)
        }
        return attributedString
    }

    private func formatTimestamp(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}
