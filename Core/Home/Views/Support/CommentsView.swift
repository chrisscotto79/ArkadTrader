// File: Core/Home/Views/Support/CommentsView.swift
// Comments sheet for a post: threaded comments, likes, replies and a composer pinned to the bottom.

import SwiftUI

struct CommentsView: View {
    let postId: String
    /// Called with the new number of top-level comments after one is added or deleted
    /// (PostStore is updated either way, so every post card shows it).
    var onCommentCountChanged: ((Int) -> Void)? = nil
    @State private var comments: [Comment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var hasLoaded = false
    @State private var loadError: String?
    /// Shown above the composer when a comment couldn't be sent or deleted
    @State private var sendError: String?
    @State private var likedComments: Set<String> = []
    @State private var reportTarget: ReportTarget?
    @ObservedObject private var blockStore = BlockStore.shared

    // Replies
    @State private var replyingToComment: Comment? = nil
    @State private var replyText = ""
    @State private var showReplyInput = false
    @FocusState private var isInputFocused: Bool

    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss

    /// Comments minus anyone the user has blocked
    private var visibleComments: [Comment] {
        comments.filter { !blockStore.isBlocked($0.authorId) }
    }

    private var topLevelComments: [Comment] {
        visibleComments.filter { $0.parentCommentId == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func getReplies(for commentId: String) -> [Comment] {
        // Replies are flattened onto their root comment
        visibleComments.filter { $0.parentCommentId == commentId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.hairline)

            ScrollView {
                commentsList
                    .padding(.vertical, DS.Spacing.s)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.surface.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target)
        }
        .onAppear {
            Task {
                await blockStore.loadIfNeeded()
                await loadComments()
                await loadLikedComments()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Comments")
                    .font(.title3.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Text("\(topLevelComments.count) comment\(topLevelComments.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer()

            IconButton(systemName: "xmark", accessibilityLabel: "Close", size: 32) {
                dismiss()
            }
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.top, DS.Spacing.l)
        .padding(.bottom, DS.Spacing.m)
    }

    // MARK: - List

    @ViewBuilder
    private var commentsList: some View {
        if isLoading && !hasLoaded && comments.isEmpty {
            HomeFeedLoadingView(message: "Loading comments…")
        } else if let loadError, comments.isEmpty {
            EmptyStateView(
                systemImage: "wifi.exclamationmark",
                title: "Couldn't load comments",
                message: loadError,
                actionTitle: "Try again"
            ) {
                Task { await loadComments() }
            }
        } else if visibleComments.isEmpty {
            EmptyStateView(
                systemImage: "bubble.left.and.bubble.right.fill",
                title: "No comments yet",
                message: "Start the conversation."
            )
        } else {
            LazyVStack(spacing: 0) {
                ForEach(topLevelComments) { comment in
                    thread(for: comment)
                    if comment.id != topLevelComments.last?.id {
                        Divider()
                            .overlay(Color.hairline)
                            .padding(.leading, DS.pageMargin + 44)
                    }
                }
            }
        }
    }

    private func thread(for comment: Comment) -> some View {
        VStack(spacing: 0) {
            CommentRowView(
                comment: comment,
                postId: postId,
                isInitiallyLiked: likedComments.contains(comment.id),
                isReply: false,
                onReply: { startReply(to: comment) },
                onReport: { report(comment) }
            ) {
                Task { await deleteComment(comment) }
            }

            ForEach(getReplies(for: comment.id)) { reply in
                CommentRowView(
                    comment: reply,
                    postId: postId,
                    isInitiallyLiked: likedComments.contains(reply.id),
                    isReply: true,
                    onReply: { startReply(to: reply) },
                    onReport: { report(reply) }
                ) {
                    Task { await deleteComment(reply) }
                }
                .padding(.leading, 44)
                .overlay(alignment: .leading) {
                    // Thread line from the parent's avatar
                    Rectangle()
                        .fill(Color.hairline)
                        .frame(width: 2)
                        .padding(.leading, DS.pageMargin + 15)
                }
            }
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 0) {
            if let replyingTo = replyingToComment {
                HStack(spacing: DS.Spacing.s) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption)
                        .foregroundStyle(Color.goldText)
                    Text("Replying to @\(replyingTo.authorUsername)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") { cancelReply() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.goldText)
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.vertical, DS.Spacing.s)
                .background(Color.goldTint)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let sendError {
                Label(sendError, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.marketRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.pageMargin)
                    .padding(.vertical, DS.Spacing.s)
                    .transition(.opacity)
            }

            Divider().overlay(Color.hairline)

            HStack(spacing: DS.Spacing.s) {
                UserAvatar(
                    username: authService.currentUser?.username ?? "",
                    imageURL: authService.currentUser?.profileImageUrl,
                    size: 32
                )

                TextField(
                    replyingToComment != nil ? "Write a reply…" : "Add a comment…",
                    text: replyingToComment != nil ? $replyText : $newCommentText,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .focused($isInputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.surfaceRaised))
                .onChange(of: newCommentText) { _, text in limitLength(&newCommentText, text) }
                .onChange(of: replyText) { _, text in limitLength(&replyText, text) }

                if currentText.count >= Comment.maxLength - 100 {
                    Text("\(Comment.maxLength - currentText.count)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(currentText.count >= Comment.maxLength ? Color.marketRed : Color.warning)
                        .accessibilityLabel("\(Comment.maxLength - currentText.count) characters left")
                }

                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(canSendMessage ? Color.onGold : Color.secondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(canSendMessage ? Color.arkadGold : Color.surfaceRaised))
                }
                .buttonStyle(PressableStyle())
                .disabled(!canSendMessage || isSending)
                .accessibilityLabel(replyingToComment != nil ? "Send reply" : "Send comment")
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.vertical, DS.Spacing.s)
        }
        .background(Color.surface)
        .animation(.snappy(duration: 0.25), value: replyingToComment?.id)
        .animation(.snappy(duration: 0.2), value: canSendMessage)
        .animation(.snappy(duration: 0.2), value: sendError)
    }

    private var currentText: String {
        replyingToComment != nil ? replyText : newCommentText
    }

    private var canSendMessage: Bool {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && text.count <= Comment.maxLength
    }

    /// Keeps a comment within the length the database accepts.
    private func limitLength(_ text: inout String, _ newValue: String) {
        if newValue.count > Comment.maxLength {
            text = String(newValue.prefix(Comment.maxLength))
        }
    }

    private func send() {
        Task {
            if replyingToComment != nil {
                await addReply()
            } else {
                await addComment()
            }
        }
    }

    private func report(_ comment: Comment) {
        reportTarget = .comment(id: comment.id, postId: postId, ownerId: comment.authorId)
    }

    // MARK: - Replies

    private func startReply(to comment: Comment) {
        // Replies go on the root comment of the thread
        let rootParent = comment.parentCommentId != nil ?
            topLevelComments.first { $0.id == comment.parentCommentId } ?? comment : comment

        replyingToComment = rootParent
        replyText = "@\(comment.authorUsername) "
        showReplyInput = true
        isInputFocused = true
    }

    private func cancelReply() {
        replyingToComment = nil
        replyText = ""
        showReplyInput = false
    }

    private func addReply() async {
        guard let replyingTo = replyingToComment else { return }
        // Always reply to the root comment of the thread
        let rootParentId = replyingTo.parentCommentId ?? replyingTo.id
        if await send(replyText, parentCommentId: rootParentId) {
            cancelReply()
        }
    }

    private func addComment() async {
        if await send(newCommentText, parentCommentId: nil) {
            newCommentText = ""
        }
    }

    /// Saves a comment or reply, then reloads the thread. On failure the text stays in the
    /// box and the error shows above it.
    private func send(_ text: String, parentCommentId: String?) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending, let currentUser = authService.currentUser else { return false }

        isSending = true
        sendError = nil
        defer { isSending = false }

        do {
            try await FirebaseServices.shared.addComment(
                postId: postId,
                content: trimmed,
                authorId: currentUser.id,
                authorUsername: currentUser.username,
                parentCommentId: parentCommentId
            )
        } catch {
            sendError = parentCommentId == nil
                ? "Couldn't post your comment. Check your connection and try again."
                : "Couldn't post your reply. Check your connection and try again."
            return false
        }

        await loadComments()
        if parentCommentId == nil { reportCommentCount() }
        return true
    }

    // MARK: - Loading and deleting

    private func loadLikedComments() async {
        guard let userId = authService.currentUser?.id else { return }
        if let liked = try? await FirebaseServices.shared.getLikedCommentIds(postId: postId, userId: userId) {
            likedComments = liked
        }
    }

    private func loadComments() async {
        isLoading = true
        do {
            let loaded = try await authService.getCommentsForPost(postId: postId)
            withAnimation(.snappy(duration: 0.25)) {
                comments = loaded
            }
            loadError = nil
        } catch {
            loadError = "Check your connection and try again."
        }
        isLoading = false
        hasLoaded = true
    }

    private func deleteComment(_ comment: Comment) async {
        sendError = nil
        do {
            try await authService.deleteComment(commentId: comment.id, postId: postId)
            await loadComments()
            if comment.parentCommentId == nil { reportCommentCount() }
        } catch {
            sendError = "Couldn't delete that comment. Try again."
        }
    }

    /// The post's comment count is its top-level comments.
    private func reportCommentCount() {
        let count = comments.filter { $0.parentCommentId == nil }.count
        PostStore.shared.setCommentsCount(count, for: postId)
        onCommentCountChanged?(count)
    }
}

// MARK: - Comment Row

private struct CommentRowView: View {
    let comment: Comment
    let postId: String
    let isInitiallyLiked: Bool
    let isReply: Bool
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var isLiked = false
    @State private var likesCount: Int
    /// A like or unlike is being saved; taps wait for it
    @State private var isSavingLike = false
    @State private var showDeleteConfirmation = false

    let onReply: () -> Void
    let onReport: () -> Void
    let onDelete: () -> Void

    init(comment: Comment, postId: String, isInitiallyLiked: Bool, isReply: Bool = false,
         onReply: @escaping () -> Void, onReport: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.comment = comment
        self.postId = postId
        self.isInitiallyLiked = isInitiallyLiked
        self.isReply = isReply
        self.onReply = onReply
        self.onReport = onReport
        self.onDelete = onDelete
        self._likesCount = State(initialValue: comment.likesCount)
        self._isLiked = State(initialValue: isInitiallyLiked)
    }

    private var isOwnComment: Bool {
        comment.authorId == authService.currentUser?.id
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            UserAvatar(username: comment.authorUsername, size: isReply ? 26 : 32)

            VStack(alignment: .leading, spacing: 4) {
                headerLine

                Text(comment.content)
                    .font(isReply ? .subheadline : .body)
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)

                actions
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.vertical, DS.Spacing.m)
        .onChange(of: isInitiallyLiked) {
            if !isSavingLike { isLiked = isInitiallyLiked }
        }
        .confirmationDialog("Delete this comment?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) { }
        }
    }

    private var headerLine: some View {
        HStack(spacing: 4) {
            Text("@\(comment.authorUsername)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
            Text("· \(comment.createdAt.feedRelativeText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Menu {
                if isOwnComment {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete comment", systemImage: "trash")
                    }
                } else {
                    Button(action: onReport) {
                        Label("Report comment", systemImage: "flag")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 22)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Comment options")
        }
    }

    private var actions: some View {
        HStack(spacing: DS.Spacing.l) {
            Button {
                Task { await toggleLike() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .contentTransition(.symbolEffect(.replace))
                    if likesCount > 0 {
                        Text("\(likesCount)")
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(likesCount)))
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(isLiked ? Color.red : Color.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLiked ? "Unlike" : "Like")

            Button(action: onReply) {
                Text("Reply")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    private func toggleLike() async {
        guard let userId = authService.currentUser?.id, !isSavingLike else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let wasLiked = isLiked
        isSavingLike = true
        withAnimation(.snappy(duration: 0.25)) {
            isLiked = !wasLiked
            likesCount = max(0, likesCount + (wasLiked ? -1 : 1))
        }

        do {
            if wasLiked {
                try await FirebaseServices.shared.unlikeComment(postId: postId, commentId: comment.id, userId: userId)
            } else {
                try await FirebaseServices.shared.likeComment(postId: postId, commentId: comment.id, userId: userId)
            }
        } catch {
            withAnimation(.snappy(duration: 0.25)) {
                isLiked = wasLiked
                likesCount = max(0, likesCount + (wasLiked ? 1 : -1))
            }
        }
        isSavingLike = false
    }
}
