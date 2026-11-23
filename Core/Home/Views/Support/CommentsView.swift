// File: Core/Home/Views/Support/CommentsView.swift
// Comments sheet for a post: threaded comments, likes, replies and a composer pinned to the bottom.

import SwiftUI

struct CommentsView: View {
    let postId: String
    let onCommentCountChanged: (Int) -> Void
    @State private var comments: [Comment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    @State private var hasLoaded = false
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

                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(canSendMessage ? Color.onGold : Color.secondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(canSendMessage ? Color.arkadGold : Color.surfaceRaised))
                }
                .buttonStyle(PressableStyle())
                .disabled(!canSendMessage || isLoading)
                .accessibilityLabel(replyingToComment != nil ? "Send reply" : "Send comment")
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.vertical, DS.Spacing.s)
        }
        .background(Color.surface)
        .animation(.snappy(duration: 0.25), value: replyingToComment?.id)
        .animation(.snappy(duration: 0.2), value: canSendMessage)
    }

    private var canSendMessage: Bool {
        if replyingToComment != nil {
            return !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        guard let replyingTo = replyingToComment,
              let currentUser = authService.currentUser,
              !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isLoading = true

        do {
            // Always reply to the root parent
            let rootParentId = replyingTo.parentCommentId ?? replyingTo.id

            try await authService.addComment(
                postId: postId,
                content: replyText,
                authorId: currentUser.id,
                authorUsername: currentUser.username,
                parentCommentId: rootParentId
            )

            cancelReply()
            await loadComments()
        } catch {
            print("❌ ERROR adding reply: \(error)")
        }

        isLoading = false
    }

    // MARK: - Loading, adding, deleting

    private func loadLikedComments() async {
        guard let userId = authService.currentUser?.id else { return }

        do {
            likedComments = try await authService.getUserLikedComments(userId: userId)
        } catch {
            print("❌ Error loading liked comments: \(error)")
        }
    }

    private func loadComments() async {
        isLoading = true
        do {
            let loaded = try await authService.getCommentsForPost(postId: postId)
            withAnimation(.snappy(duration: 0.25)) {
                comments = loaded
            }
        } catch {
            print("❌ ERROR loading comments: \(error)")
        }
        isLoading = false
        hasLoaded = true
    }

    private func deleteComment(_ comment: Comment) async {
        do {
            try await authService.deleteComment(commentId: comment.id, postId: postId)
            await loadComments()

            // Update comment count (only count top-level comments)
            onCommentCountChanged(comments.filter { $0.parentCommentId == nil }.count)
        } catch {
            print("❌ Error deleting comment: \(error)")
        }
    }

    private func addComment() async {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUser = authService.currentUser else {
            return
        }

        isLoading = true

        do {
            try await authService.addComment(
                postId: postId,
                content: newCommentText,
                authorId: currentUser.id,
                authorUsername: currentUser.username,
                parentCommentId: nil  // top-level comment
            )

            newCommentText = ""
            await loadComments()

            // Update the comment count in the feed (only top-level comments)
            onCommentCountChanged(comments.filter { $0.parentCommentId == nil }.count)
        } catch {
            print("❌ ERROR adding comment: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Comment Row

private struct CommentRowView: View {
    let comment: Comment
    let isInitiallyLiked: Bool
    let isReply: Bool
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var isLiked = false
    @State private var likesCount: Int
    @State private var showDeleteConfirmation = false

    let onReply: () -> Void
    let onReport: () -> Void
    let onDelete: () -> Void

    init(comment: Comment, isInitiallyLiked: Bool, isReply: Bool = false, onReply: @escaping () -> Void,
         onReport: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.comment = comment
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
            isLiked = isInitiallyLiked
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
        guard let userId = authService.currentUser?.id else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Update UI immediately
        withAnimation(.snappy(duration: 0.25)) {
            isLiked.toggle()
            likesCount += isLiked ? 1 : -1
        }

        do {
            if isLiked {
                try await authService.likeComment(commentId: comment.id, userId: userId)
            } else {
                try await authService.unlikeComment(commentId: comment.id, userId: userId)
            }
        } catch {
            // Revert on error
            withAnimation(.snappy(duration: 0.25)) {
                isLiked.toggle()
                likesCount += isLiked ? 1 : -1
            }
            print("❌ Error toggling comment like: \(error)")
        }
    }
}
