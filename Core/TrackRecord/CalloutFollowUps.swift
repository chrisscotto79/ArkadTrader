// File: Core/TrackRecord/CalloutFollowUps.swift
// The messages an author's app posts about their own callouts (docs/backend-contracts.md, section 11):
// - `calloutUpdate`: trim, add, move stop, move target or note, while the callout is open.
//   Moving the stop or target also changes `callout.stopPrice` / `callout.targetPrice` on the parent
//   and sets `callout.lastUpdateId` to the update's id, in the same batch, so CalloutAutoTracker
//   (which reads the message) closes against the new level and the rules can check the move.
//   Update messages have the fixed id "<parentMessageId>_u<epochMillis>" (`updateMessageId`).
// - `calloutResult`: posted once, right after the callout closes, by hand (CalloutTrackingService)
//   or by the tracker (CalloutAutoTracker), with exactly the numbers written to the callout.
//
// A result message has the fixed id "<parentMessageId>_result", so a second post can't create a
// second message (an overwrite is an update, which the rules refuse).

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum CalloutUpdateError: LocalizedError {
    case notAuthor
    case closed
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .notAuthor: return "Only the person who posted this callout can update it."
        case .closed: return "This callout is closed."
        case .invalid(let message): return message
        }
    }
}

@MainActor
final class CalloutFollowUps {
    static let shared = CalloutFollowUps()

    private var db: Firestore { FirebaseServices.shared.db }
    /// Results being posted right now, so a manual close and a tracker run can't race.
    private var postingResults: Set<String> = []

    private init() {}

    /// The fixed id of a callout's result message.
    nonisolated static func resultMessageId(for parentMessageId: String) -> String {
        "\(parentMessageId)_result"
    }

    /// The id of an update message: "<parentMessageId>_u<epochMillis>".
    nonisolated static func updateMessageId(for parentMessageId: String, at date: Date = Date()) -> String {
        "\(parentMessageId)_u\(Int64((date.timeIntervalSince1970 * 1000).rounded()))"
    }

    /// When an update was posted, read back from its id (see `updateMessageId`).
    nonisolated static func updateTime(fromUpdateId id: String?) -> Date? {
        guard let id, let marker = id.range(of: "_u", options: .backwards),
              let millis = Int64(id[marker.upperBound...]), millis > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(millis) / 1000)
    }

    /// Deep link for the new notification types: `{ route: "community", communityId, channelId, messageId }`.
    nonisolated static func communityRoute(communityId: String, channelId: String, messageId: String) -> [String: String] {
        ["route": "community", "communityId": communityId, "channelId": channelId, "messageId": messageId]
    }

    // MARK: - Updates

    /// What's wrong with an update's own fields, or nil when they're complete.
    nonisolated static func fieldError(for update: CalloutUpdate) -> String? {
        if update.kind.usesPercent {
            guard let percent = update.percent, percent >= 1, percent <= 100 else {
                return "Enter a percent between 1 and 100"
            }
        }
        switch update.kind {
        case .add, .moveStop, .moveTarget:
            guard let price = update.price, price > 0, price.isFinite else { return "Enter a price" }
        case .trim:
            if let price = update.price, !(price > 0 && price.isFinite) { return "Enter a price above zero" }
        case .note:
            if (update.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Write a note" }
        }
        return nil
    }

    /// Where a new stop or target may go. A stop on the wrong side of the market would close the
    /// callout at once at a better-than-market price, so it's checked against the current price
    /// (or, without one, against the entry).
    nonisolated static func levelError(for update: CalloutUpdate, on callout: TradeCallout, referencePrice: Double?) -> String? {
        guard update.kind == .moveStop || update.kind == .moveTarget,
              let price = update.price, price > 0 else { return nil }
        let isLong = callout.direction == .long
        let reference = referencePrice.flatMap { $0 > 0 && $0.isFinite ? $0 : nil }
        let format = TradeCallout.formatPrice

        if update.kind == .moveStop {
            if price == callout.stopPrice { return "That's already the stop" }
            if let target = callout.targetPrice {
                if isLong && price >= target { return "For a long, the stop must be below the target (\(format(target)))" }
                if !isLong && price <= target { return "For a short, the stop must be above the target (\(format(target)))" }
            }
            if let reference {
                if isLong && price >= reference { return "For a long, the stop must be below the current price (\(format(reference)))" }
                if !isLong && price <= reference { return "For a short, the stop must be above the current price (\(format(reference)))" }
            } else {
                if isLong && price > callout.entryPrice { return "Without a live price, a long's stop can't go above entry (\(format(callout.entryPrice)))" }
                if !isLong && price < callout.entryPrice { return "Without a live price, a short's stop can't go below entry (\(format(callout.entryPrice)))" }
            }
        } else {
            if price == callout.targetPrice { return "That's already the target" }
            if let stop = callout.stopPrice {
                if isLong && price <= stop { return "For a long, the target must be above the stop (\(format(stop)))" }
                if !isLong && price >= stop { return "For a short, the target must be below the stop (\(format(stop)))" }
            }
            if let reference {
                if isLong && price <= reference { return "For a long, the target must be above the current price (\(format(reference)))" }
                if !isLong && price >= reference { return "For a short, the target must be below the current price (\(format(reference)))" }
            } else {
                if isLong && price <= callout.entryPrice { return "For a long, the target must be above entry (\(format(callout.entryPrice)))" }
                if !isLong && price >= callout.entryPrice { return "For a short, the target must be below entry (\(format(callout.entryPrice)))" }
            }
        }
        return nil
    }

    /// Posts the author's follow-up on their own open callout, in the callout's channel.
    /// - Parameters:
    ///   - parentAuthorId: the callout message's author, for callouts that predate `callout.authorId`.
    ///   - referencePrice: the live price the sheet checked against, if it had one.
    /// - Returns: the message as sent.
    @discardableResult
    func postUpdate(
        _ update: CalloutUpdate,
        on callout: TradeCallout,
        parentAuthorId: String?,
        communityId: String,
        channelId: String,
        referencePrice: Double? = nil
    ) async throws -> CommunityMessage {
        guard let user = FirebaseAuthService.shared.currentUser,
              user.id == (callout.authorId ?? parentAuthorId) else { throw CalloutUpdateError.notAuthor }
        guard callout.isOpen else { throw CalloutUpdateError.closed }
        if let error = Self.fieldError(for: update)
            ?? Self.levelError(for: update, on: callout, referencePrice: referencePrice ?? callout.lastPrice) {
            throw CalloutUpdateError.invalid(error)
        }

        var clean = update
        clean.note = update.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.note?.isEmpty == true { clean.note = nil }
        if !clean.kind.usesPercent { clean.percent = nil }
        if clean.kind == .note { clean.price = nil }

        var message = CommunityMessage(
            content: ChatText.clip(clean.summary(ticker: callout.ticker), max: ChatText.contentLimit),
            authorId: user.id,
            authorUsername: user.username,
            channelId: channelId,
            communityId: communityId,
            authorAvatarURL: user.profileImageUrl
        )
        message.id = Self.updateMessageId(for: clean.parentMessageId)
        message.calloutUpdate = clean

        let level: (field: String, value: Double)?
        switch clean.kind {
        case .moveStop: level = clean.price.map { (field: "stopPrice", value: $0) }
        case .moveTarget: level = clean.price.map { (field: "targetPrice", value: $0) }
        case .trim, .add, .note: level = nil
        }

        // The update message and, for a stop or target move, the parent's new level and
        // `callout.lastUpdateId` (= this message's id), in one batch.
        try await FirebaseServices.shared.sendCalloutUpdate(message, parentLevel: level)

        if clean.kind.notifiesMembers {
            let posted = message
            let authorId = user.id
            let username = user.username
            let ticker = callout.ticker
            Task {
                await self.notifyUpdate(posted, ticker: ticker, authorId: authorId, username: username)
            }
        }
        return message
    }

    /// `callout_update` for the community's members (not the author), like new callouts.
    private func notifyUpdate(_ message: CommunityMessage, ticker: String, authorId: String, username: String) async {
        let recipients = await TrackRecordWriter.shared.memberIds(communityId: message.communityId)
            .filter { $0 != authorId }
        guard !recipients.isEmpty else { return }
        await FirebaseServices.shared.createNotifications(
            to: recipients,
            type: "callout_update",
            title: ChatText.clip("\(username) updated $\(ticker)", max: 200),
            body: ChatText.clip(message.content, max: 1000),
            data: Self.communityRoute(communityId: message.communityId, channelId: message.channelId, messageId: message.id),
            communityId: message.communityId
        )
    }

    // MARK: - Results

    /// Posts the result message for a callout that has just closed. Call it only after the close
    /// was written to the message; `callout` must carry exactly the written `status`, `exitPrice`
    /// and `resultPercent`. Does nothing when the result is already posted. Failures are logged.
    /// - Parameters:
    ///   - exitCheck: "live" for auto-closes and checked manual closes, otherwise "unchecked".
    ///   - authorUsername, authorAvatarURL: from the callout message, when the caller has it.
    func postResult(
        for callout: TradeCallout,
        parentMessageId: String,
        communityId: String,
        channelId: String,
        exitCheck: TradeCallout.PriceCheck,
        authorUsername: String? = nil,
        authorAvatarURL: String? = nil
    ) async {
        guard let result = CalloutResult(closed: callout, parentMessageId: parentMessageId, exitCheck: exitCheck),
              let userId = Auth.auth().currentUser?.uid,
              (callout.authorId ?? userId) == userId,
              !postingResults.contains(parentMessageId) else { return }
        postingResults.insert(parentMessageId)
        defer { postingResults.remove(parentMessageId) }

        let resultId = Self.resultMessageId(for: parentMessageId)
        let ref = FirebaseServices.shared.channelMessageRef(communityId: communityId, channelId: channelId, messageId: resultId)
        // If this can't be read, post anyway: the fixed id means a duplicate is refused, not created.
        if let existing = try? await ref.getDocument(), existing.exists { return }

        let profile = await authorProfile(userId: userId, username: authorUsername, avatarURL: authorAvatarURL)
        var message = CommunityMessage(
            content: ChatText.clip(result.summary, max: ChatText.contentLimit),
            authorId: userId,
            authorUsername: profile.username,
            channelId: channelId,
            communityId: communityId,
            authorAvatarURL: profile.avatarURL
        )
        message.id = resultId
        message.calloutResult = result

        do {
            try await FirebaseServices.shared.sendCommunityMessage(message)
        } catch {
            TrackRecordWriter.log("couldn't post the callout result: \(error.localizedDescription)")
        }
    }

    /// The author's username and photo: from the caller, the signed-in profile, or their user doc.
    private func authorProfile(userId: String, username: String?, avatarURL: String?) async -> (username: String, avatarURL: String?) {
        if let username, !username.isEmpty { return (username, avatarURL) }
        if let user = FirebaseAuthService.shared.currentUser, user.id == userId {
            return (user.username, avatarURL ?? user.profileImageUrl)
        }
        let data = try? await db.collection("users").document(userId).getDocument().data()
        return (data?["username"] as? String ?? "", avatarURL ?? data?["profileImageUrl"] as? String)
    }
}
