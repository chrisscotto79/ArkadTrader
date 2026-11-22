// File: Core/Communities/Views/Detail/ChatMessageRow.swift
// A single chat message: bubble, author avatar, replies and reactions.

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import FirebaseStorage
import Photos
import MobileCoreServices

// MARK: - Enhanced Message Row with Clickable Profile Images
struct EnhancedMessageRowWithReactions: View {
    let message: CommunityMessage
    let author: User?
    let authorRole: CommunityRole
    let community: Community
    let showUsername: Bool
    let isUserMessage: Bool
    let canEdit: Bool
    let canDelete: Bool
    let reactions: [EmojiReactionGroup]
    let onReply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onReact: (String) -> Void
    let onShowEmojiPicker: () -> Void
    let onProfileTap: (User) -> Void
    let readReceipts: Set<String> // User IDs who have read this message
    let currentUserId: String
    var canManageCallout: Bool = false
    var onTrackCallout: () -> Void = {}
    var onUpdateCalloutStatus: (TradeCallout.Status) -> Void = { _ in }
    
    @State private var showingActions = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // ENHANCED: Clickable Profile Image/Avatar
            if showUsername {
                profileImageView
            } else {
                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(showingActions ? 1.0 : 0.0)
                    .frame(width: 40, alignment: .center)
                    .animation(.easeInOut(duration: 0.2), value: showingActions)
            }
            
            // Message Content
            VStack(alignment: .leading, spacing: 6) {
                // Username and timestamp
                if showUsername {
                    usernameAndTimestamp
                }
                
                // Enhanced Message Content with integrated reactions
                messageContent
                
                // Message actions (simplified)
                if showingActions {
                    messageActionsView
                }
            }
            
            Spacer(minLength: 50)
        }
        .padding(.vertical, showUsername ? 8 : 2)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingActions.toggle()
            }
        }
    }
    
    // MARK: - ENHANCED: Clickable Profile Image Component
    private var profileImageView: some View {
        Button(action: {
            if let author = author {
                onProfileTap(author)
            }
        }) {
            Group {
                if let author = author,
                   let profileImageUrl = author.profileImageUrl,
                   !profileImageUrl.isEmpty {
                    
                    AsyncImage(url: URL(string: profileImageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        // Loading state with user color background
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [userColor.opacity(0.8), userColor.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.6)
                            )
                    }
                } else {
                    // Fallback to initials circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [userColor.opacity(0.8), userColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text(userInitials)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
            .overlay(
                // Online status indicator (optional)
                shouldShowOnlineStatus ?
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(x: 16, y: 16) : nil
            )
        }
        .buttonStyle(ProfileImageButtonStyle())
    }
    
    private var usernameAndTimestamp: some View {
        HStack(spacing: 8) {
            // Username with role badges
            HStack(spacing: 6) {
                Text(message.authorUsername)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(userColor)
                
                // MOD/ADMIN Badge - ENHANCED with simplified role system!
                Group {
                    if authorRole == .owner {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundColor(.purple)
                            .background(
                                Circle()
                                    .fill(.purple.opacity(0.15))
                                    .frame(width: 16, height: 16)
                            )
                    } else if authorRole == .admin {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .background(
                                Circle()
                                    .fill(.orange.opacity(0.15))
                                    .frame(width: 16, height: 16)
                            )
                    } else if authorRole == .moderator {
                        Image(systemName: "shield.fill")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                            .background(
                                Circle()
                                    .fill(.blue.opacity(0.15))
                                    .frame(width: 16, height: 16)
                            )
                    }
                }
                
                // Verified badge
                if let author = author, author.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                
                // Subscription tier badge
                if let author = author, author.subscriptionTier != .basic {
                    Text(author.subscriptionTier.displayName.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(subscriptionTierColor(author.subscriptionTier))
                        .cornerRadius(4)
                }
            }
            
            Text(formatTimestamp(message.createdAt))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Handle different message types
            if let callout = message.callout {
                CalloutCardView(
                    callout: callout,
                    authorUsername: message.authorUsername,
                    canManage: canManageCallout,
                    onTrack: onTrackCallout,
                    onUpdateStatus: onUpdateCalloutStatus
                )
            } else if let mediaContent = getMediaContent(from: message) {
                mediaMessageView(mediaContent)
            } else {
                // Regular text message bubble with mention highlighting
                HStack {
                    Text(attributedMessageContent)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(messageBackgroundColor)
                        )
                    
                    Spacer()
                }
            }
            
            // Reactions positioned below and to the left
            if !reactions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(reactions) { reactionGroup in
                        Button(action: {
                            onReact(reactionGroup.emoji)
                        }) {
                            HStack(spacing: 4) {
                                Text(reactionGroup.emoji)
                                    .font(.caption)
                                
                                if reactionGroup.count > 1 {
                                    Text("\(reactionGroup.count)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(reactionGroup.hasUserReacted ?
                                          Color.yellow.opacity(0.3) :
                                          Color(.systemGray5)
                                    )
                            )
                            .scaleEffect(reactionGroup.hasUserReacted ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3), value: reactionGroup.hasUserReacted)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Add reaction button
                    Button(action: onShowEmojiPicker) {
                        Image(systemName: "plus")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(Color(.systemGray5))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
            }
            
            // NEW: Read Receipts (only show for current user's messages)
            if isUserMessage && !readReceipts.isEmpty {
                readReceiptsView
            }
        }
    }
    
    // MARK: - Media Message View
    @ViewBuilder
    private func mediaMessageView(_ mediaContent: MediaContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch mediaContent.type {
            case .image:
                AsyncImage(url: URL(string: mediaContent.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 250, maxHeight: 300)
                        .cornerRadius(12)
                        .clipped()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 250, height: 200)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
                
            case .document:
                documentPreviewView(mediaContent)
                
            case .video:
                videoPreviewView(mediaContent)
            }
            
            // Caption text if present (but not for pure media messages)
            if !message.content.isEmpty && !message.content.hasPrefix("[MEDIA:") {
                HStack {
                    Text(message.content)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private func documentPreviewView(_ mediaContent: MediaContent) -> some View {
        HStack(spacing: 12) {
            // Document icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: documentIcon(for: mediaContent.fileName))
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            
            // Document info
            VStack(alignment: .leading, spacing: 2) {
                Text(mediaContent.fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let fileSize = mediaContent.fileSize {
                    Text(formatFileSize(fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Download button
            Button(action: {
                // to do - downloadDocument(mediaContent)
            }) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .frame(maxWidth: 280)
    }
    
    @ViewBuilder
    private func videoPreviewView(_ mediaContent: MediaContent) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(width: 250, height: 140)
            
            VStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                Text("Video Message")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private var messageActionsView: some View {
        HStack(spacing: 16) {
            Button("Reply", action: onReply)
                .font(.caption)
                .foregroundColor(.accentColor)
            
            if canEdit {
                Button("Edit", action: onEdit)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            if canDelete {
                Button("Delete", action: onDelete)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Button(action: onShowEmojiPicker) {
                HStack(spacing: 4) {
                    Image(systemName: "face.smiling")
                        .font(.caption)
                    Text("React")
                        .font(.caption)
                }
                .foregroundColor(.accentColor)
            }
            
            Spacer()
        }
        .padding(.top, 4)
        .padding(.leading, 52)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Helper Properties and Methods
    private var userColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .indigo, .teal]
        let hash = message.authorId.hashValue
        return colors[abs(hash) % colors.count]
    }
    
    private var userInitials: String {
        if let author = author {
            let names = author.fullName.components(separatedBy: " ")
            if names.count >= 2 {
                return String(names[0].prefix(1)) + String(names[1].prefix(1))
            } else if let firstChar = names.first?.first {
                return String(firstChar)
            }
        }
        return String(message.authorUsername.prefix(2)).uppercased()
    }
    
    private var shouldShowOnlineStatus: Bool {
        // Implement online status logic if needed
        return false
    }
    
    private func subscriptionTierColor(_ tier: SubscriptionTier) -> Color {
        switch tier {
        case .basic: return .gray
        case .pro: return .blue
        case .elite: return .purple
        }
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
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func getMediaContent(from message: CommunityMessage) -> MediaContent? {
        let content = message.content
        
        if content.hasPrefix("[MEDIA:IMAGE]") {
            let url = String(content.dropFirst(13))
            return MediaContent(type: .image, url: url, fileName: "image.jpg", fileSize: nil)
        } else if content.hasPrefix("[MEDIA:DOCUMENT]") {
            let parts = String(content.dropFirst(16)).components(separatedBy: "|")
            if parts.count >= 2 {
                return MediaContent(type: .document, url: parts[0], fileName: parts[1], fileSize: nil)
            }
        } else if content.hasPrefix("[MEDIA:VIDEO]") {
            let url = String(content.dropFirst(13))
            return MediaContent(type: .video, url: url, fileName: "video.mp4", fileSize: nil)
        }
        
        return nil
    }
    
    private func documentIcon(for fileName: String) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return "doc.richtext"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx":
            return "tablecells"
        case "ppt", "pptx":
            return "rectangle.on.rectangle"
        case "txt":
            return "doc.plaintext"
        case "zip", "rar":
            return "archivebox"
        default:
            return "doc"
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - Mention Highlighting
    private var attributedMessageContent: AttributedString {
        var attributedString = AttributedString(message.content)
        
        // Detect @mentions and apply styling
        let mentionPattern = #"@(\w+)"#
        let regex = try? NSRegularExpression(pattern: mentionPattern)
        let nsString = message.content as NSString
        let matches = regex?.matches(in: message.content, range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in matches.reversed() { // Reverse to maintain indices
            if let range = Range(match.range, in: message.content) {
                if let attributedRange = Range(range, in: attributedString) {
                    attributedString[attributedRange].foregroundColor = .blue
                    attributedString[attributedRange].font = .body.weight(.semibold)
                    
                    // Check if this mention is for current user
                    let mentionText = String(message.content[range])
                    if mentionText.lowercased().contains(currentUserId.lowercased()) {
                        attributedString[attributedRange].backgroundColor = .yellow.opacity(0.3)
                    }
                }
            }
        }
        
        return attributedString
    }
    
    private var messageBackgroundColor: Color {
        // Highlight message background if current user is mentioned
        let mentionPattern = #"@(\w+)"#
        let regex = try? NSRegularExpression(pattern: mentionPattern)
        let matches = regex?.matches(in: message.content, range: NSRange(location: 0, length: message.content.count)) ?? []
        
        let currentUserMentioned = matches.contains { match in
            if let range = Range(match.range, in: message.content) {
                let mentionText = String(message.content[range])
                return mentionText.lowercased().contains(currentUserId.lowercased())
            }
            return false
        }
        
        return currentUserMentioned ? Color.accentColor.opacity(0.1) : Color(.systemGray6)
    }
    
    // MARK: - Read Receipts View
    private var readReceiptsView: some View {
        HStack(spacing: 4) {
            if readReceipts.count > 0 {
                Image(systemName: readReceipts.count == 1 ? "checkmark" : "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(readReceipts.count == 1 ? .secondary : .accentColor)
                
                if readReceipts.count > 1 {
                    Text("\(readReceipts.count)")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                        .fontWeight(.medium)
                }
                
                Text("Read")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.top, 2)
    }
}

// MARK: - Button Styles
struct ProfileImageButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}
