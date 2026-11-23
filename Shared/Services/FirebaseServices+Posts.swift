// File: Shared/Services/FirebaseServices+Posts.swift
// Posts, post likes, bookmarks, comments and comment likes.
//
// Write shapes (firestore.rules checks these):
// - posts/{id}: created with createdAt = server time, likesCount/commentsCount 0, content <= 2000,
//   tickers <= 10 uppercased symbols, hashtags <= 10, authorUsername = the stored username.
// - Like: posts/{p}/likes/{uid} + users/{uid}/likedPosts/{p} + posts/{p}.likesCount ±1, one batch.
// - Top-level comment: posts/{p}/comments/{c} + posts/{p}.commentsCount ±1 + lastCommentId = c,
//   one batch. Replies don't change the post.
// - Comment like: posts/{p}/comments/{c}/likes/{uid} + comments/{c}.likesCount ±1
//   + users/{uid}/commentLikes/{c} (an index with postId), one batch.

import Foundation
import FirebaseFirestore
import FirebaseStorage

extension FirebaseServices {
    /// Firestore allows 500 writes per batch; stay well under it.
    private static let batchLimit = 450

    // MARK: - Post Management

    /// Creates a post. A trade-result post (`tradeId` set) gets its `tradeSnapshot` copied from the
    /// trade document as stored, so it matches what firestore.rules compare (snapshotMatches).
    func createPost(_ post: Post) async throws {
        guard post.content.count <= Post.maxContentLength else {
            throw NSError(domain: "Post", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Posts can be up to \(Post.maxContentLength.formatted()) characters."
            ])
        }
        var data = post.toFirestore()
        data["createdAt"] = FieldValue.serverTimestamp()
        data["likesCount"] = 0
        data["commentsCount"] = 0
        if let tradeId = post.tradeId {
            data["tradeId"] = tradeId
            data["tradeSnapshot"] = try await tradeSnapshotData(tradeId: tradeId, authorId: post.authorId)
        } else {
            data.removeValue(forKey: "tradeSnapshot")
        }
        try await db.collection("posts").document(post.id).setData(data)
        notifyPostMentions(postId: post.id, authorUsername: post.authorUsername, content: post.content)
    }

    /// The snapshot of the author's own closed trade, straight from the trade document.
    private func tradeSnapshotData(tradeId: String, authorId: String) async throws -> [String: Any] {
        let document = try await db.collection("trades").document(tradeId).getDocument(source: .server)
        guard let trade = document.data(), trade["userId"] as? String == authorId else {
            throw NSError(domain: "TradeResultPost", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "That trade couldn't be found in your portfolio."])
        }
        guard let snapshot = TradeSnapshot.firestoreData(fromTradeDocument: trade) else {
            throw NSError(domain: "TradeResultPost", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Only closed trades can be shared as a trade result."])
        }
        return snapshot
    }

    /// Updates only the fields an author may edit. Counts, dates, the author, the post type and
    /// the trade snapshot are fixed once posted.
    func updatePost(_ post: Post) async throws {
        var data: [String: Any] = [
            "content": post.content,
            "tickers": Cashtag.cleaned(post.tickers),
            "hashtags": Array(post.hashtags.prefix(Post.maxHashtags)),
            "mentions": post.mentions
        ]
        data[PostSentiment.firestoreField] = post.sentiment?.rawValue ?? FieldValue.delete()
        try await db.collection("posts").document(post.id).updateData(data)
    }

    /// Deletes a post with its comments and likes, in batches of 450. The post itself goes last,
    /// so the rules can still read it while its comments and likes are removed, and a failure
    /// part-way leaves a post that can be deleted again. Every screen drops it (PostStore).
    func deletePost(postId: String) async throws {
        let postRef = db.collection("posts").document(postId)
        let comments = try await postRef.collection("comments").getDocuments()
        let likes = try await postRef.collection("likes").getDocuments()

        var refs = comments.documents.map(\.reference) + likes.documents.map(\.reference)
        while refs.count >= Self.batchLimit {
            let batch = db.batch()
            for ref in refs.prefix(Self.batchLimit) { batch.deleteDocument(ref) }
            try await batch.commit()
            refs.removeFirst(Self.batchLimit)
        }

        let batch = db.batch()
        for ref in refs { batch.deleteDocument(ref) }
        batch.deleteDocument(postRef)
        try await batch.commit()

        await MainActor.run { PostStore.shared.markRemoved(postId) }
    }

    /// The newest posts (first page). Kept for callers that don't page.
    func getFeedPosts(limit: Int = 50) async throws -> [Post] {
        try await getFeedPage(limit: limit, after: nil).posts
    }

    /// One page of the newest posts. Pass the returned cursor as `after` for the next page;
    /// it's nil when there are no more.
    func getFeedPage(limit: Int = 30, after cursor: DocumentSnapshot?) async throws -> (posts: [Post], cursor: DocumentSnapshot?) {
        var query = db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        if let cursor {
            query = query.start(afterDocument: cursor)
        }
        let snapshot = try await query.getDocuments()
        let posts = snapshot.documents.compactMap(Post.fromDocument)
        let next = snapshot.documents.count < limit ? nil : snapshot.documents.last
        return (posts, next)
    }

    func getUserPosts(userId: String) async throws -> [Post] {
        let snapshot = try await db.collection("posts")
            .whereField("authorId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap(Post.fromDocument)
    }

    /// Discover's post search. Firestore has no full-text search, so:
    /// - "$TSLA" (or a bare symbol like "tsla"): posts tagged with that ticker, newest first;
    /// - "#tag": posts with that hashtag;
    /// - anything else: the newest 50 posts, matched on text and username.
    /// Hidden posts are left out (blocked authors are filtered by the caller).
    func searchPosts(query: String, limit: Int = 20) async throws -> [Post] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        let posts = db.collection("posts")

        var found: [Post] = []
        if text.hasPrefix("#") {
            let tag = String(text.dropFirst())
            guard !tag.isEmpty, tag.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { return [] }
            // Hashtags are stored as typed ("#Trading"), so try the usual spellings
            let variants = Array(Set(["#" + tag, "#" + tag.lowercased(), "#" + tag.uppercased(),
                                      "#" + tag.prefix(1).uppercased() + tag.dropFirst().lowercased()]))
            let snapshot = try await posts
                .whereField("hashtags", arrayContainsAny: variants)
                .limit(to: 50)
                .getDocuments()
            found = snapshot.documents.compactMap(Post.fromDocument)
                .sorted { $0.createdAt > $1.createdAt }
        } else {
            let symbol = Cashtag.normalize(text)
            let looksLikeTicker = Cashtag.isValid(symbol)
            if looksLikeTicker {
                let snapshot = try await posts
                    .whereField("tickers", arrayContains: symbol)
                    .order(by: "createdAt", descending: true)
                    .limit(to: limit)
                    .getDocuments()
                found = snapshot.documents.compactMap(Post.fromDocument)
            }
            // "$TSLA" is clearly a ticker; a plain word also searches recent post text
            if !text.hasPrefix("$") {
                let lowered = text.lowercased()
                let snapshot = try await posts
                    .order(by: "createdAt", descending: true)
                    .limit(to: 50)
                    .getDocuments()
                let shown = Set(found.map(\.id))
                found += snapshot.documents.compactMap(Post.fromDocument).filter { post in
                    !shown.contains(post.id)
                        && (post.content.lowercased().contains(lowered)
                            || post.authorUsername.lowercased().contains(lowered))
                }
            }
        }
        return Array(found.filter { !$0.isHidden }.prefix(limit))
    }

    // MARK: - Likes

    /// Likes a post once. If you've already liked it (like document exists), nothing changes.
    func likePost(postId: String, userId: String) async throws {
        let postRef = db.collection("posts").document(postId)
        let likeRef = postRef.collection("likes").document(userId)
        let userLikeRef = db.collection("users").document(userId).collection("likedPosts").document(postId)

        if try await likeRef.getDocument().exists {
            // Already counted; make sure your own index has it
            try? await userLikeRef.setData(["postId": postId, "likedAt": FieldValue.serverTimestamp()])
            return
        }

        let batch = db.batch()
        batch.setData(["userId": userId, "likedAt": FieldValue.serverTimestamp()], forDocument: likeRef)
        batch.setData(["postId": postId, "likedAt": FieldValue.serverTimestamp()], forDocument: userLikeRef)
        batch.updateData(["likesCount": FieldValue.increment(Int64(1))], forDocument: postRef)
        try await batch.commit()
        notifyPostLiked(postId: postId)
    }

    /// Removes your like. The count only goes down when posts/{id}/likes/{you} exists, so an
    /// older like that lives only in your own lists can't push the count below the real number.
    func unlikePost(postId: String, userId: String) async throws {
        let postRef = db.collection("posts").document(postId)
        let likeRef = postRef.collection("likes").document(userId)
        let userRef = db.collection("users").document(userId)
        let userLikeRef = userRef.collection("likedPosts").document(postId)

        if try await likeRef.getDocument().exists {
            let batch = db.batch()
            batch.deleteDocument(likeRef)
            batch.deleteDocument(userLikeRef)
            batch.updateData(["likesCount": FieldValue.increment(Int64(-1))], forDocument: postRef)
            try await batch.commit()
        } else {
            try await userLikeRef.delete()
        }
        // The oldest app versions kept likes at users/{uid}/likes/{postId}; tidy up separately
        try? await userRef.collection("likes").document(postId).delete()
    }

    /// The ids of posts you've liked: users/{uid}/likedPosts plus the oldest location,
    /// users/{uid}/likes (moved to the new layout in the background).
    func getUserLikedPosts(userId: String) async throws -> Set<String> {
        let userRef = db.collection("users").document(userId)
        let current = try await userRef.collection("likedPosts").getDocuments()
        var liked = Set(current.documents.map(\.documentID))

        if let legacy = try? await userRef.collection("likes").getDocuments() {
            let unmigrated = Set(legacy.documents.map(\.documentID)).subtracting(liked)
            liked.formUnion(unmigrated)
            if !unmigrated.isEmpty {
                Task { await migrateLegacyLikes(userId: userId, postIds: unmigrated) }
            }
        }
        return liked
    }

    /// Moves likes from users/{uid}/likes into the current layout (posts/{p}/likes/{uid} and
    /// users/{uid}/likedPosts/{p}) and deletes the old documents. Those likes were already
    /// counted in likesCount, so the counts don't change. 3 writes per like, so 150 per batch,
    /// each batch a new one. Failures are left for the next session.
    private func migrateLegacyLikes(userId: String, postIds: Set<String>) async {
        let userRef = db.collection("users").document(userId)
        for chunk in Array(postIds).chunked(into: Self.batchLimit / 3) {
            let batch = db.batch()
            for postId in chunk {
                batch.setData(["postId": postId, "likedAt": FieldValue.serverTimestamp(), "migratedFromOldFormat": true],
                              forDocument: userRef.collection("likedPosts").document(postId))
                batch.setData(["userId": userId, "likedAt": FieldValue.serverTimestamp(), "migratedFromOldFormat": true],
                              forDocument: db.collection("posts").document(postId).collection("likes").document(userId))
                batch.deleteDocument(userRef.collection("likes").document(postId))
            }
            do {
                try await batch.commit()
            } catch {
                return
            }
        }
    }

    // MARK: - Profile photo

    /// Deletes a profile photo uploaded by older versions (profile_images/{file}). Failures are
    /// ignored so the profile update still goes through.
    func deleteProfileImage(imageUrl: String) async throws {
        guard let url = URL(string: imageUrl) else { return }
        let pathComponents = url.pathComponents
        if let index = pathComponents.firstIndex(of: "profile_images"), index + 1 < pathComponents.count {
            let fileName = pathComponents[index + 1]
            try? await Storage.storage().reference().child("profile_images/\(fileName)").delete()
        }
    }

    // MARK: - Bookmarks

    func bookmarkPost(postId: String, userId: String) async throws {
        try await db.collection("users").document(userId).collection("bookmarks").document(postId).setData([
            "postId": postId,
            "bookmarkedAt": FieldValue.serverTimestamp()
        ])
    }

    func unbookmarkPost(postId: String, userId: String) async throws {
        try await db.collection("users").document(userId).collection("bookmarks").document(postId).delete()
    }

    func getUserBookmarkedPosts(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(userId).collection("bookmarks").getDocuments()
        return Set(snapshot.documents.map(\.documentID))
    }

    // MARK: - Comments

    /// Adds a comment, or a reply when `parentCommentId` is set, and returns it. A top-level
    /// comment adds 1 to the post's commentsCount and sets its lastCommentId in the same batch;
    /// replies leave the post alone. Notifies the post's author, the parent comment's author and
    /// anyone @mentioned.
    @discardableResult
    func addComment(postId: String, content: String, authorId: String, authorUsername: String,
                    parentCommentId: String? = nil) async throws -> Comment {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw FirestoreError.invalidData }
        guard text.count <= Comment.maxLength else {
            throw NSError(domain: "Comment", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Comments can be up to \(Comment.maxLength.formatted()) characters."
            ])
        }

        let comment = Comment(postId: postId, content: text, authorId: authorId,
                              authorUsername: authorUsername, parentCommentId: parentCommentId)
        let postRef = db.collection("posts").document(postId)
        let commentRef = postRef.collection("comments").document(comment.id)

        let batch = db.batch()
        batch.setData(comment.toFirestore(), forDocument: commentRef)
        if parentCommentId == nil {
            batch.updateData([
                "commentsCount": FieldValue.increment(Int64(1)),
                "lastCommentId": comment.id
            ], forDocument: postRef)
        }
        try await batch.commit()

        notifyCommented(postId: postId, commentId: comment.id, parentCommentId: parentCommentId,
                        commenterUsername: authorUsername, content: text)
        return comment
    }

    func getCommentsForPost(postId: String) async throws -> [Comment] {
        let snapshot = try await db.collection("posts").document(postId)
            .collection("comments")
            .getDocuments()
        let comments = snapshot.documents.compactMap { document in
            try? Comment.fromFirestore(data: document.data(with: .estimate), id: document.documentID)
        }
        return comments.sorted { $0.createdAt < $1.createdAt }
    }

    /// Deletes a comment. A top-level comment takes 1 off the post's commentsCount (and sets
    /// lastCommentId to it) in the same batch, and its replies go with it: in that batch and,
    /// if there are many, in more batches after. Deleting a reply leaves the post alone.
    func deleteComment(commentId: String, postId: String) async throws {
        let postRef = db.collection("posts").document(postId)
        let commentRef = postRef.collection("comments").document(commentId)
        let document = try await commentRef.getDocument()
        guard document.exists else { return }

        guard document.data()?["parentCommentId"] as? String == nil else {
            try await commentRef.delete()
            return
        }

        let replies = try await postRef.collection("comments")
            .whereField("parentCommentId", isEqualTo: commentId)
            .getDocuments()
        var replyRefs = replies.documents.map(\.reference)

        let batch = db.batch()
        batch.deleteDocument(commentRef)
        batch.updateData([
            "commentsCount": FieldValue.increment(Int64(-1)),
            "lastCommentId": commentId
        ], forDocument: postRef)
        let firstReplies = replyRefs.prefix(Self.batchLimit - 2)
        for ref in firstReplies { batch.deleteDocument(ref) }
        try await batch.commit()
        replyRefs.removeFirst(firstReplies.count)

        for chunk in replyRefs.chunked(into: Self.batchLimit) {
            let batch = db.batch()
            for ref in chunk { batch.deleteDocument(ref) }
            try await batch.commit()
        }
    }

    // MARK: - Comment likes

    /// Likes a comment once: posts/{p}/comments/{c}/likes/{uid}, likesCount +1 and your
    /// users/{uid}/commentLikes/{c} index, in one batch.
    func likeComment(postId: String, commentId: String, userId: String) async throws {
        let commentRef = db.collection("posts").document(postId).collection("comments").document(commentId)
        let likeRef = commentRef.collection("likes").document(userId)
        let indexRef = db.collection("users").document(userId).collection("commentLikes").document(commentId)
        let indexData: [String: Any] = ["commentId": commentId, "postId": postId, "likedAt": FieldValue.serverTimestamp()]

        if try await likeRef.getDocument().exists {
            try? await indexRef.setData(indexData)
            return
        }

        let batch = db.batch()
        batch.setData(["userId": userId, "likedAt": FieldValue.serverTimestamp()], forDocument: likeRef)
        batch.updateData(["likesCount": FieldValue.increment(Int64(1))], forDocument: commentRef)
        batch.setData(indexData, forDocument: indexRef)
        try await batch.commit()
    }

    /// Removes your like from a comment; the count only goes down when your like document exists.
    func unlikeComment(postId: String, commentId: String, userId: String) async throws {
        let commentRef = db.collection("posts").document(postId).collection("comments").document(commentId)
        let likeRef = commentRef.collection("likes").document(userId)
        let indexRef = db.collection("users").document(userId).collection("commentLikes").document(commentId)

        if try await likeRef.getDocument().exists {
            let batch = db.batch()
            batch.deleteDocument(likeRef)
            batch.updateData(["likesCount": FieldValue.increment(Int64(-1))], forDocument: commentRef)
            batch.deleteDocument(indexRef)
            try await batch.commit()
        } else {
            try await indexRef.delete()
        }
    }

    /// The comments on one post that you've liked (from your commentLikes index).
    func getLikedCommentIds(postId: String, userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(userId)
            .collection("commentLikes")
            .whereField("postId", isEqualTo: postId)
            .getDocuments()
        return Set(snapshot.documents.map(\.documentID))
    }
}
