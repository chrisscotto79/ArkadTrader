// File: Core/Communities/Views/Detail/ChatMessageRow.swift
// A single chat message: grouped bubble (yours in gold on the right, others' on the left),
// author line, reply quote, media, the trade kinds (callout card, callout update row, result
// card, trade share card, game plan card) and reactions. Long-press for reply / react / copy /
// edit / pin / report / delete. Deleted messages show as a muted "Message deleted" row.

import SwiftUI
import UIKit

struct EnhancedMessageRowWithReactions: View {
    let message: CommunityMessage
    let author: User?
    let authorRole: CommunityRole
    let community: Community
    /// First message of a group: shows the avatar and author line
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
    let currentUserId: String
    /// Used to highlight @mentions of the current user
    var currentUsername: String = ""
    var onTrackCallout: () -> Void = {}
    /// Last message of a group: shows the time and the rounded tail corner
    var isLastInGroup: Bool = true
    /// Owners, admins and moderators can pin
    var canPin: Bool = false
    var onTogglePin: () -> Void = {}
    /// Report this message (nil for your own messages)
    var onReport: (() -> Void)? = nil
    /// For a callout: its `calloutUpdate` messages in the loaded channel, oldest first
    var calloutUpdates: [CommunityMessage] = []
    /// For an update or result: the callout it refers to, when loaded
    var parentCallout: TradeCallout? = nil
    /// Whether a message id is in the loaded messages (so tapping a quote or "↳" can jump to it)
    var isMessageLoaded: (String) -> Bool = { _ in false }
    /// Scrolls the chat to a loaded message
    var onJumpToMessage: (String) -> Void = { _ in }

    @Environment(\.openURL) private var openURL

    private var avatarSize: CGFloat { 32 }
    private var bigRadius: CGFloat { 18 }
    private var smallRadius: CGFloat { 6 }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.s) {
            if isUserMessage {
                Spacer(minLength: 56)
            } else {
                avatarColumn
            }

            VStack(alignment: isUserMessage ? .trailing : .leading, spacing: 4) {
                if showUsername && !isUserMessage {
                    authorLine
                }

                if message.isDeleted {
                    deletedBubble
                } else {
                    messageContent
                        .contextMenu { contextActions }

                    if !reactions.isEmpty {
                        reactionsRow
                    }
                }

                if showsFooter {
                    footerLine
                }
            }

            if !isUserMessage {
                Spacer(minLength: 40)
            }
        }
        .padding(.top, showUsername ? DS.Spacing.s : 0)
        .frame(maxWidth: .infinity, alignment: isUserMessage ? .trailing : .leading)
    }

    // MARK: - Avatar & author

    /// Photo stored on the message when it was sent, else the author's current one
    private var avatarURL: String? {
        if let stored = message.authorAvatarURL, !stored.isEmpty { return stored }
        return author?.profileImageUrl
    }

    @ViewBuilder
    private var avatarColumn: some View {
        if showUsername {
            Button {
                if let author { onProfileTap(author) }
            } label: {
                UserAvatar(username: message.authorUsername, imageURL: avatarURL, size: avatarSize)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("View \(message.authorUsername)'s profile")
        } else {
            Color.clear.frame(width: avatarSize, height: 1)
        }
    }

    private var authorLine: some View {
        HStack(spacing: 5) {
            Button {
                if let author { onProfileTap(author) }
            } label: {
                Text(message.authorUsername)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
            }
            .buttonStyle(.plain)

            roleBadge

            if let author, author.isVerified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.goldText)
                    .accessibilityLabel("Verified")
            }

            Text(formatTimestamp(message.createdAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private var roleBadge: some View {
        switch authorRole {
        case .owner:
            Image(systemName: "crown.fill")
                .font(.caption2)
                .foregroundStyle(Color.goldText)
                .accessibilityLabel("Owner")
        case .admin:
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundStyle(CommunityRole.admin.color)
                .accessibilityLabel("Admin")
        case .moderator:
            Image(systemName: "shield.fill")
                .font(.caption2)
                .foregroundStyle(CommunityRole.moderator.color)
                .accessibilityLabel("Moderator")
        case .member:
            EmptyView()
        }
    }

    // MARK: - Deleted, edited, pinned

    private var deletedBubble: some View {
        HStack(spacing: 6) {
            Image(systemName: "trash")
                .font(.caption)
            Text("Message deleted")
                .font(.subheadline)
                .italic()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .overlay(bubbleShape.stroke(Color.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Message deleted")
    }

    private var isEditedVisible: Bool {
        message.isEdited && !message.isDeleted
    }

    private var isPinnedVisible: Bool {
        message.isPinned && !message.isDeleted
    }

    private var showsFooter: Bool {
        (isLastInGroup && isUserMessage) || isEditedVisible || isPinnedVisible
    }

    /// "Pinned · edited · 3:41 PM" under the bubble
    private var footerLine: some View {
        HStack(spacing: 4) {
            if isPinnedVisible {
                Label("Pinned", systemImage: "pin.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Color.goldText)
            }
            if isPinnedVisible && (isEditedVisible || (isLastInGroup && isUserMessage)) {
                Text("·")
            }
            if isEditedVisible {
                Text("edited")
            }
            if isEditedVisible && isLastInGroup && isUserMessage {
                Text("·")
            }
            if isLastInGroup && isUserMessage {
                Text(formatTime(message.createdAt))
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }

    // MARK: - Content

    @ViewBuilder
    private var messageContent: some View {
        if let replyTo = message.replyTo {
            VStack(alignment: isUserMessage ? .trailing : .leading, spacing: 3) {
                let canJump = isMessageLoaded(replyTo.messageId)
                ReplyQuoteHeader(reply: replyTo, canJump: canJump) {
                    onJumpToMessage(replyTo.messageId)
                }
                kindContent
            }
        } else {
            kindContent
        }
    }

    /// Jumps to the callout an update or result refers to, when it's loaded
    private func parentJump(_ parentId: String) -> (() -> Void)? {
        guard isMessageLoaded(parentId) else { return nil }
        return { onJumpToMessage(parentId) }
    }

    @ViewBuilder
    private var kindContent: some View {
        if let callout = message.callout {
            CalloutCardView(
                callout: callout,
                authorUsername: message.authorUsername,
                messageId: message.id,
                channelId: message.channelId,
                communityId: message.communityId,
                authorId: message.authorId,
                updates: calloutUpdates,
                postedAt: message.createdAt,
                onTrack: onTrackCallout
            )
            .frame(maxWidth: 360)
        } else if let update = message.calloutUpdate {
            CalloutUpdateRow(
                update: update,
                parent: parentCallout,
                summary: message.content,
                onOpenParent: parentJump(update.parentMessageId)
            )
        } else if let result = message.calloutResult {
            CalloutResultCard(result: result, onOpenParent: parentJump(result.parentMessageId))
        } else if let share = message.tradeShare {
            TradeShareCard(share: share)
        } else if let plan = message.gamePlan {
            GamePlanCard(plan: plan)
        } else if let media = getMediaContent(from: message) {
            mediaMessageView(media)
        } else {
            textBubble
        }
    }

    private var textBubble: some View {
        Text(attributedMessageContent)
            .font(.body)
            .foregroundStyle(isUserMessage ? Color.onGold : Color.primary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(bubbleShape.fill(bubbleFill))
            .overlay(
                bubbleShape.stroke(mentionsMe && !isUserMessage ? Color.goldText.opacity(0.35) : Color.clear, lineWidth: 1)
            )
            .contentShape(bubbleShape)
    }

    private var bubbleShape: UnevenRoundedRectangle {
        if isUserMessage {
            return UnevenRoundedRectangle(
                topLeadingRadius: bigRadius,
                bottomLeadingRadius: bigRadius,
                bottomTrailingRadius: isLastInGroup ? bigRadius : smallRadius,
                topTrailingRadius: showUsername ? bigRadius : smallRadius,
                style: .continuous
            )
        }
        return UnevenRoundedRectangle(
            topLeadingRadius: showUsername ? bigRadius : smallRadius,
            bottomLeadingRadius: isLastInGroup ? bigRadius : smallRadius,
            bottomTrailingRadius: bigRadius,
            topTrailingRadius: bigRadius,
            style: .continuous
        )
    }

    private var bubbleFill: Color {
        if isUserMessage { return .arkadGold }
        return mentionsMe ? .goldTint : .surfaceRaised
    }

    // MARK: - Media

    @ViewBuilder
    private func mediaMessageView(_ media: MediaContent) -> some View {
        switch media.type {
        case .image:
            imageView(media)
        case .document:
            documentView(media)
        case .video:
            videoView(media)
        }
    }

    private func imageView(_ media: MediaContent) -> some View {
        AsyncImage(url: URL(string: media.url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 240, maxHeight: 320)
            case .failure:
                mediaPlaceholder(icon: "photo", text: "Photo unavailable")
            default:
                mediaPlaceholder(icon: nil, text: nil)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
        .accessibilityLabel("Photo from \(message.authorUsername)")
    }

    private func mediaPlaceholder(icon: String?, text: String?) -> some View {
        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
            .fill(Color.surfaceRaised)
            .frame(width: 240, height: 180)
            .overlay {
                if let icon, let text {
                    VStack(spacing: 6) {
                        Image(systemName: icon).font(.title2)
                        Text(text).font(.caption)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
    }

    @ViewBuilder
    private func documentView(_ media: MediaContent) -> some View {
        if let url = URL(string: media.url) {
            Link(destination: url) { documentCard(media) }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Open \(media.fileName)")
        } else {
            documentCard(media)
        }
    }

    private func documentCard(_ media: MediaContent) -> some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: documentIcon(for: media.fileName), size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(media.fileName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Text(media.fileSize.map(formatFileSize) ?? fileKind(for: media.fileName))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: DS.Spacing.s)

            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.m)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous).fill(Color.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func videoView(_ media: MediaContent) -> some View {
        if let url = URL(string: media.url) {
            Link(destination: url) { videoThumbnail }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Play video")
        } else {
            videoThumbnail
        }
    }

    private var videoThumbnail: some View {
        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
            .fill(Color.surfaceRaised)
            .frame(width: 240, height: 140)
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                    Text("Play video")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .strokeBorder(Color.hairline, lineWidth: 1)
            )
    }

    // MARK: - Reactions

    private var reactionsRow: some View {
        HStack(spacing: 6) {
            ForEach(reactions) { group in
                Button {
                    onReact(group.emoji)
                } label: {
                    HStack(spacing: 4) {
                        Text(group.emoji)
                            .font(.footnote)
                        if group.count > 1 {
                            Text("\(group.count)")
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(group.hasUserReacted ? Color.goldText : Color.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(
                        Capsule().fill(group.hasUserReacted ? Color.goldTint : Color.surfaceRaised)
                    )
                    .overlay(
                        Capsule().strokeBorder(group.hasUserReacted ? Color.goldText.opacity(0.4) : Color.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(group.emoji) \(group.count), \(group.displayText)")
            }

            Button(action: onShowEmojiPicker) {
                Image(systemName: "face.smiling")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 26)
                    .background(Capsule().fill(Color.surfaceRaised))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Add reaction")
        }
    }

    // MARK: - Long-press actions

    @ViewBuilder
    private var contextActions: some View {
        Button(action: onReply) {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }
        Button(action: onShowEmojiPicker) {
            Label("React", systemImage: "face.smiling")
        }
        if message.callout == nil, getMediaContent(from: message) == nil {
            Button {
                UIPasteboard.general.string = message.content
            } label: {
                Label("Copy Text", systemImage: "doc.on.doc")
            }
        }
        if let media = getMediaContent(from: message), let url = URL(string: media.url) {
            Button {
                openURL(url)
            } label: {
                Label("Open", systemImage: "arrow.up.right.square")
            }
        }
        if canEdit && !message.hasStructuredKind && getMediaContent(from: message) == nil {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
        }
        if canPin {
            Button(action: onTogglePin) {
                Label(message.isPinned ? "Unpin" : "Pin", systemImage: message.isPinned ? "pin.slash" : "pin")
            }
        }
        if let onReport, !isUserMessage {
            Button(action: onReport) {
                Label("Report", systemImage: "flag")
            }
        }
        if canDelete {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    /// Time only: the chat shows a day separator above each day's messages
    private func formatTimestamp(_ date: Date) -> String {
        formatTime(date)
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
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
        switch (fileName as NSString).pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "doc", "docx": return "doc.text"
        case "xls", "xlsx", "csv": return "tablecells"
        case "ppt", "pptx": return "rectangle.on.rectangle"
        case "txt", "rtf": return "doc.plaintext"
        case "zip", "rar", "gz": return "archivebox"
        default: return "doc"
        }
    }

    /// "PDF document", "File"
    private func fileKind(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.uppercased()
        return ext.isEmpty ? "File" : "\(ext) file"
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    // MARK: - Mentions

    private static let mentionRegex = try? NSRegularExpression(pattern: #"@(\w+)"#)

    private var mentionRanges: [Range<String.Index>] {
        let content = message.content
        let nsRange = NSRange(location: 0, length: (content as NSString).length)
        let matches = Self.mentionRegex?.matches(in: content, range: nsRange) ?? []
        return matches.compactMap { Range($0.range, in: content) }
    }

    /// Whether this message @mentions the current user
    private var mentionsMe: Bool {
        guard !currentUsername.isEmpty else { return false }
        let target = "@\(currentUsername.lowercased())"
        return mentionRanges.contains { String(message.content[$0]).lowercased() == target }
    }

    private var attributedMessageContent: AttributedString {
        var attributed = AttributedString(message.content)
        for range in mentionRanges {
            guard let attributedRange = Range(range, in: attributed) else { continue }
            attributed[attributedRange].font = .body.weight(.semibold)
            if !isUserMessage {
                attributed[attributedRange].foregroundColor = .goldText
            }
        }
        return attributed
    }
}

// MARK: - Button Styles
struct ProfileImageButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
