// File: Core/Communities/Views/Detail/ChannelChatView.swift
// A community channel's chat: header, pinned bar, grouped message list, typing indicator and mentions overlay.
// The composer and attachments live in ChannelChatView+Composer.swift and ChannelChatView+Media.swift.

import SwiftUI
import UIKit

// MARK: - Main ChannelChatView
struct ChannelChatView: View {
    let community: Community
    let channel: Channel

    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel = ChannelChatViewModel()
    @EnvironmentObject var authService: FirebaseAuthService

    // Message input and UI state
    @State var messageText = ""
    @State var showingChannelInfo = false
    @State var selectedMessage: CommunityMessage?
    @State var replyingTo: CommunityMessage?
    @State var editingMessage: CommunityMessage?
    @State var editedContent = ""
    @State var showDeleteConfirmation = false
    @State var messageToDelete: CommunityMessage?
    @State var showEmojiPicker = false
    @State var emojiPickerForMessage: CommunityMessage?
    @FocusState var isMessageFieldFocused: Bool

    // Moderation
    @State var reportTarget: ReportTarget?
    @State var showingPinnedMessages = false

    // Typing and search
    @State var lastTypingTime: Date = Date()
    @State var typingTimer: Timer?
    @State var showingMessageSearch = false
    @State var searchText = ""
    @State var searchResults: [CommunityMessage] = []
    /// Message picked in search, held until the search sheet finishes closing
    @State var searchSelectionId: String?
    /// Message the list should scroll to
    @State var scrollTargetMessageId: String?
    /// Message briefly highlighted after jumping to it from search
    @State var highlightedMessageId: String?

    // Typing-dots animation
    @State var animatingDot = 0
    @State var typingAnimationTimer: Timer?

    // @Mentions
    @State var mentionSuggestions: [User] = []
    @State var showingMentionSuggestions = false
    @State var currentMentionQuery = ""
    @State var mentionRange: Range<String.Index>?

    // Media sharing state
    @State var showingImagePicker = false
    @State var showingCamera = false
    @State var showingDocumentPicker = false
    @State var showingMediaOptions = false
    @State var showCreateCallout = false
    @State var showGamePlanSheet = false
    @State var calloutToTrack: CommunityMessage?
    @State var selectedImage: UIImage?
    @State var selectedDocumentURL: URL?
    @State var isUploadingMedia = false
    @State var uploadErrorMessage: String?

    // Profiles
    @State var selectedUserForProfile: User?
    @State var showUserProfile = false
    @State var userCache: [String: User] = [:]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                channelHeader
                if let latestPin = viewModel.pinnedMessages.first {
                    pinnedBar(latestPin)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                messagesScrollView

                if !viewModel.typingUsernames.isEmpty {
                    typingIndicatorView
                        .transition(.opacity)
                }

                if let replyingTo = replyingTo {
                    replyBanner(to: replyingTo)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if editingMessage != nil {
                    editBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                enhancedMessageInput
            }
            .animation(.snappy(duration: 0.2), value: replyingTo?.id)
            .animation(.snappy(duration: 0.2), value: editingMessage?.id)
            .animation(.snappy(duration: 0.2), value: viewModel.pinnedMessages.first?.id)

            if showEmojiPicker {
                emojiPickerOverlay
            }

            if showingMentionSuggestions {
                mentionSuggestionsOverlay
            }
        }
        .background(Color.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showUserProfile) {
            if let user = selectedUserForProfile {
                UserProfileSheet(user: user, community: community, onBlocked: { blockedId in
                    viewModel.hideMessages(from: blockedId)
                })
                .environmentObject(authService)
            }
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target)
        }
        .sheet(isPresented: $showingPinnedMessages, onDismiss: {
            if let target = searchSelectionId {
                searchSelectionId = nil
                scrollTargetMessageId = target
            }
        }) {
            PinnedMessagesSheet(
                messages: viewModel.pinnedMessages,
                userCache: userCache,
                canUnpin: viewModel.canPinMessages,
                previewText: previewText(for:),
                onSelect: { message in
                    searchSelectionId = message.id
                    showingPinnedMessages = false
                },
                onUnpin: { message in
                    viewModel.togglePin(message)
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCreateCallout) {
            CreateCalloutSheet(channelName: channel.name) { callout in
                viewModel.sendCallout(callout)
            }
        }
        .sheet(isPresented: $showGamePlanSheet) {
            GamePlanSheet(channelName: channel.name) { plan in
                viewModel.sendGamePlan(plan)
            }
        }
        .sheet(item: $calloutToTrack) { message in
            if let callout = message.callout {
                TrackCalloutSheet(callout: callout, communityName: community.name) { entry, quantity in
                    try await viewModel.trackCallout(callout, entryPrice: entry, quantity: quantity)
                }
            }
        }
        .sheet(isPresented: $showingChannelInfo) {
            ChannelInfoSheet(community: community, channel: channel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(selectedURL: $selectedDocumentURL)
        }
        .sheet(isPresented: $showingMessageSearch, onDismiss: {
            // Scroll after the sheet has gone so the jump is visible
            if let target = searchSelectionId {
                searchSelectionId = nil
                scrollTargetMessageId = target
            }
        }) {
            MessageSearchSheet(
                messages: viewModel.messages,
                userCache: userCache,
                searchText: $searchText,
                searchResults: $searchResults,
                onMessageSelected: { message in
                    searchSelectionId = message.id
                    showingMessageSearch = false
                }
            )
        }
        .alert(
            "Upload failed",
            isPresented: Binding(get: { uploadErrorMessage != nil }, set: { if !$0 { uploadErrorMessage = nil } })
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(uploadErrorMessage ?? "")
        }
        .alert("Delete message?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                confirmDeleteMessage()
            }
            Button("Cancel", role: .cancel) {
                cancelDeleteMessage()
            }
        } message: {
            Text("It's removed for everyone in #\(channel.name) and shows as \"Message deleted\". This can't be undone.")
        }
        .onAppear {
            viewModel.loadChannelData(community: community, channel: channel)
            loadUsersForMessages()
        }
        .onDisappear {
            viewModel.cleanup()
            typingAnimationTimer?.invalidate()
            typingTimer?.invalidate()
        }
        .onChange(of: selectedImage) { _, newValue in
            if let image = newValue {
                handleImageUpload(image)
            }
        }
        .onChange(of: selectedDocumentURL) { _, newValue in
            if let url = newValue {
                handleDocumentUpload(url)
            }
        }
        .onChange(of: messageText) {
            handleTypingIndicator()
            detectMentions()
        }
    }
}

// MARK: - Header
extension ChannelChatView {
    var channelHeader: some View {
        HStack(spacing: DS.Spacing.m) {
            IconButton(systemName: "chevron.left", accessibilityLabel: "Back to \(community.name)") {
                dismiss()
            }

            Button(action: { showingChannelInfo = true }) {
                HStack(spacing: DS.Spacing.s) {
                    IconWell(systemName: channelIcon, tint: channelColor, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text("#\(channel.name)")
                                .font(.headline)
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                            if channel.adminOnly {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("Admins only")
                            }
                        }
                        Text(community.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Shows channel info")

            Spacer(minLength: 0)

            IconButton(systemName: "magnifyingglass", accessibilityLabel: "Search messages") {
                showingMessageSearch = true
            }
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.vertical, DS.Spacing.s)
        .background(Color.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
    }

    var channelColor: Color { channel.displayTint }

    var channelIcon: String { channel.displayIcon }
}

// MARK: - Pinned bar
extension ChannelChatView {
    func pinnedBar(_ message: CommunityMessage) -> some View {
        let count = viewModel.pinnedMessages.count
        return Button(action: { showingPinnedMessages = true }) {
            HStack(spacing: DS.Spacing.m) {
                Image(systemName: "pin.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.goldText)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.goldTint))

                VStack(alignment: .leading, spacing: 1) {
                    Text(count > 1 ? "\(count) pinned messages" : "Pinned message")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.goldText)
                    Text(previewText(for: message))
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                }

                Spacer(minLength: DS.Spacing.s)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.vertical, DS.Spacing.s)
            .background(Color.surface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.hairline).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Shows pinned messages")
    }
}

// MARK: - Messages
extension ChannelChatView {
    var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.messages.isEmpty {
                        emptyChannelState
                    } else {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            messageCell(message, at: index)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.m)
                .padding(.top, DS.Spacing.m)
                .padding(.bottom, DS.Spacing.s)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                // Auto-scroll to bottom when a new message arrives
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
                loadUsersForNewMessages()
            }
            .onChange(of: scrollTargetMessageId) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(target, anchor: .center)
                }
                highlightedMessageId = target
                scrollTargetMessageId = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    if highlightedMessageId == target {
                        highlightedMessageId = nil
                    }
                }
            }
            .onTapGesture {
                if showEmojiPicker {
                    showEmojiPicker = false
                    emojiPickerForMessage = nil
                }
                isMessageFieldFocused = false
            }
        }
    }

    @ViewBuilder
    func messageCell(_ message: CommunityMessage, at index: Int) -> some View {
        VStack(spacing: 0) {
            if startsNewDay(at: index) {
                daySeparator(for: message.createdAt)
            }
            messageRow(message, at: index)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .fill(Color.goldTint)
                        .opacity(highlightedMessageId == message.id ? 1 : 0)
                        .padding(.horizontal, -DS.Spacing.s)
                )
                .animation(.easeInOut(duration: 0.3), value: highlightedMessageId)
        }
    }

    func messageRow(_ message: CommunityMessage, at index: Int) -> some View {
        EnhancedMessageRowWithReactions(
            message: message,
            author: userCache[message.authorId],
            authorRole: viewModel.role(for: message.authorId),
            community: community,
            showUsername: isFirstInGroup(at: index),
            isUserMessage: message.authorId == viewModel.currentUserId,
            canEdit: viewModel.canEditMessage(message),
            canDelete: viewModel.canDeleteMessage(message),
            reactions: viewModel.getGroupedReactions(for: message.id),
            onReply: {
                replyingTo = message
                isMessageFieldFocused = true
            },
            onEdit: { startEditingMessage(message) },
            onDelete: { requestDeleteMessage(message) },
            onReact: { emoji in
                viewModel.addReaction(to: message.id, emoji: emoji)
            },
            onShowEmojiPicker: {
                emojiPickerForMessage = message
                showEmojiPicker = true
            },
            onProfileTap: { user in
                selectedUserForProfile = user
                showUserProfile = true
            },
            currentUserId: authService.currentUser?.id ?? "",
            currentUsername: authService.currentUser?.username ?? "",
            onTrackCallout: { calloutToTrack = message },
            isLastInGroup: isLastInGroup(at: index),
            canPin: viewModel.canPin(message),
            onTogglePin: { viewModel.togglePin(message) },
            onReport: reportAction(for: message),
            calloutUpdates: message.callout == nil ? [] : viewModel.calloutUpdates(for: message.id),
            parentCallout: viewModel.parentCallout(of: message),
            isMessageLoaded: { viewModel.message(withId: $0) != nil },
            onJumpToMessage: { jumpToMessage($0) }
        )
    }

    /// Scrolls to a loaded message and briefly highlights it (reply quotes, "↳ update" rows).
    func jumpToMessage(_ id: String) {
        guard viewModel.message(withId: id) != nil else { return }
        scrollTargetMessageId = id
    }

    /// Report option for other people's messages
    func reportAction(for message: CommunityMessage) -> (() -> Void)? {
        guard message.authorId != viewModel.currentUserId, !message.isDeleted else { return nil }
        return {
            reportTarget = .message(
                id: message.id,
                communityId: community.id,
                channelId: channel.id,
                ownerId: message.authorId
            )
        }
    }

    func daySeparator(for date: Date) -> some View {
        Text(dayLabel(for: date))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.surfaceRaised))
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.m)
            .accessibilityAddTraits(.isHeader)
    }

    func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    var emptyChannelState: some View {
        VStack(spacing: DS.Spacing.l) {
            IconWell(systemName: channelIcon, tint: channelColor, size: 64)
            VStack(spacing: 6) {
                Text("Welcome to #\(channel.name)")
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(channelDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, 96)
    }

    var channelDescription: String {
        switch channel.type {
        case .text, .voice:
            if channel.isAnnouncements {
                return "Announcements from the community's owners and admins show up here."
            }
            return "This is the start of #\(channel.name). Say hello to the community."
        case .callouts:
            return channel.adminOnly
                ? "Admins post trade callouts here. Tap \"Track in Portfolio\" on a callout to add it to your trades."
                : "Post trade callouts here with the megaphone button. Tap \"Track in Portfolio\" on a callout to add it to your trades."
        }
    }
}

// MARK: - Grouping
extension ChannelChatView {
    /// Messages from the same author within five minutes are drawn as one group.
    /// Callouts, updates, results, trade shares and game plans always start their own.
    func belongsToSameGroup(_ earlier: CommunityMessage, _ later: CommunityMessage) -> Bool {
        earlier.authorId == later.authorId
            && later.createdAt.timeIntervalSince(earlier.createdAt) <= 300
            && Calendar.current.isDate(earlier.createdAt, inSameDayAs: later.createdAt)
            && !earlier.hasStructuredKind && !later.hasStructuredKind
    }

    func isFirstInGroup(at index: Int) -> Bool {
        let messages = viewModel.messages
        guard index > 0, index < messages.count else { return true }
        return !belongsToSameGroup(messages[index - 1], messages[index])
    }

    func isLastInGroup(at index: Int) -> Bool {
        let messages = viewModel.messages
        guard index + 1 < messages.count else { return true }
        return !belongsToSameGroup(messages[index], messages[index + 1])
    }

    func startsNewDay(at index: Int) -> Bool {
        let messages = viewModel.messages
        guard index > 0, index < messages.count else { return true }
        return !Calendar.current.isDate(messages[index - 1].createdAt, inSameDayAs: messages[index].createdAt)
    }

    /// Kept for callers that only have the message
    func shouldShowUsername(_ message: CommunityMessage) -> Bool {
        guard let index = viewModel.messages.firstIndex(where: { $0.id == message.id }) else { return true }
        return isFirstInGroup(at: index)
    }

    /// One-line description of a message for reply / edit banners
    func previewText(for message: CommunityMessage) -> String {
        message.previewText
    }
}

// MARK: - @Mentions Overlay
extension ChannelChatView {
    var mentionSuggestionsOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { hideMentionSuggestions() }

            VStack(spacing: 0) {
                HStack {
                    Text("Mention someone")
                        .font(.headline)
                    Spacer()
                    Button("Cancel") { hideMentionSuggestions() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.goldText)
                }
                .padding(.horizontal, DS.Spacing.l)
                .padding(.vertical, DS.Spacing.m)

                Rectangle().fill(Color.hairline).frame(height: 1)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(mentionSuggestions.prefix(8), id: \.id) { user in
                            MentionSuggestionRow(user: user) {
                                insertMention(user)
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
            .background(
                UnevenRoundedRectangle(topLeadingRadius: DS.Radius.l, topTrailingRadius: DS.Radius.l, style: .continuous)
                    .fill(Color.surface)
                    .ignoresSafeArea(edges: .bottom)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.snappy(duration: 0.3), value: showingMentionSuggestions)
    }
}

// MARK: - Typing indicator
extension ChannelChatView {
    var typingIndicatorView: some View {
        HStack(spacing: DS.Spacing.s) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 5, height: 5)
                        .opacity(animatingDot == index ? 1 : 0.35)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.surfaceRaised))

            Text(typingText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.vertical, 6)
        .background(Color.surface)
        .onAppear {
            startTypingAnimation()
        }
        .onDisappear {
            typingAnimationTimer?.invalidate()
        }
        .accessibilityElement(children: .combine)
    }

    var typingText: String {
        let names = viewModel.typingUsernames
        switch names.count {
        case 0: return ""
        case 1: return "\(names[0]) is typing…"
        case 2: return "\(names[0]) and \(names[1]) are typing…"
        case 3: return "\(names[0]), \(names[1]) and \(names[2]) are typing…"
        default: return "\(names[0]), \(names[1]) and \(names.count - 2) others are typing…"
        }
    }

    func startTypingAnimation() {
        typingAnimationTimer?.invalidate()
        typingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                animatingDot = (animatingDot + 1) % 3
            }
        }
    }

    // MARK: Typing logic
    func handleTypingIndicator() {
        guard !messageText.isEmpty else {
            stopTyping()
            return
        }

        lastTypingTime = Date()
        sendTypingIndicator(isTyping: true)

        // Stop typing after 3 seconds of inactivity
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            stopTyping()
        }
    }

    func stopTyping() {
        sendTypingIndicator(isTyping: false)
        typingTimer?.invalidate()
    }

    func sendTypingIndicator(isTyping: Bool) {
        viewModel.setTyping(isTyping)
    }
}

// MARK: - User Loading and Caching
extension ChannelChatView {
    func loadUsersForMessages() {
        let userIds = Set(viewModel.messages.map { $0.authorId })
        for userId in userIds where userCache[userId] == nil {
            loadUser(userId: userId)
        }
    }

    func loadUser(userId: String) {
        guard userCache[userId] == nil else { return }

        Task {
            do {
                if let user = try await authService.getUserById(userId: userId) {
                    await MainActor.run {
                        userCache[userId] = user
                    }
                }
            } catch {
                // The row falls back to the username stored on the message
            }
        }
    }

    func loadUsersForNewMessages() {
        let userIds = Set(viewModel.messages.map { $0.authorId })
        let missingUserIds = userIds.subtracting(Set(userCache.keys))
        for userId in missingUserIds {
            loadUser(userId: userId)
        }
    }
}

#Preview {
    let testCommunity = Community(
        name: "Elite Traders",
        description: "Trading community",
        type: .dayTrading,
        creatorId: "test-user",
        memberCount: 156,
        isPrivate: false
    )

    let testChannel = Channel(
        name: "general",
        type: .text,
        communityId: testCommunity.id,
        isDefault: true,
        adminOnly: false
    )

    NavigationStack {
        ChannelChatView(community: testCommunity, channel: testChannel)
    }
    .environmentObject(FirebaseAuthService.shared)
}
