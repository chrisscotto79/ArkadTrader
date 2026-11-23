// File: Core/Safety/ReportTarget.swift
// What can be reported, and why. Matches `reports/{id}` in docs/backend-contracts.md.

import Foundation

/// Something a person can report. Pass it to `ReportSheet(target:)`.
enum ReportTarget: Hashable, Identifiable {
    case post(id: String, ownerId: String)
    case comment(id: String, postId: String, ownerId: String)
    case message(id: String, communityId: String, channelId: String, ownerId: String)
    case user(id: String)
    case community(id: String, ownerId: String)

    var id: String { "\(targetType)_\(targetId)" }

    /// `targetType` stored on the report
    var targetType: String {
        switch self {
        case .post: return "post"
        case .comment: return "comment"
        case .message: return "message"
        case .user: return "user"
        case .community: return "community"
        }
    }

    var targetId: String {
        switch self {
        case .post(let id, _),
             .comment(let id, _, _),
             .message(let id, _, _, _),
             .user(let id),
             .community(let id, _):
            return id
        }
    }

    /// The person responsible for the content (for a user report, that user)
    var targetOwnerId: String {
        switch self {
        case .post(_, let ownerId),
             .comment(_, _, let ownerId),
             .message(_, _, _, let ownerId),
             .community(_, let ownerId):
            return ownerId
        case .user(let id):
            return id
        }
    }

    var communityId: String? {
        switch self {
        case .message(_, let communityId, _, _): return communityId
        case .community(let id, _): return id
        default: return nil
        }
    }

    var channelId: String? {
        if case .message(_, _, let channelId, _) = self { return channelId }
        return nil
    }

    var postId: String? {
        if case .comment(_, let postId, _) = self { return postId }
        return nil
    }

    /// "post", "comment"… for copy
    var noun: String {
        switch self {
        case .post: return "post"
        case .comment: return "comment"
        case .message: return "message"
        case .user: return "account"
        case .community: return "community"
        }
    }
}

/// Why something is being reported. Raw values are the contract's `reason` strings.
enum ReportReason: String, CaseIterable, Identifiable {
    case spam
    case harassment
    case scamOrManipulation = "scam_or_manipulation"
    case hate
    case explicit
    case impersonation
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spam: return "Spam"
        case .harassment: return "Harassment or bullying"
        case .scamOrManipulation: return "Scam or market manipulation"
        case .hate: return "Hate speech"
        case .explicit: return "Explicit content"
        case .impersonation: return "Impersonation"
        case .other: return "Something else"
        }
    }

    var subtitle: String {
        switch self {
        case .spam: return "Repeated, unwanted or promotional content"
        case .harassment: return "Targeting or threatening someone"
        case .scamOrManipulation: return "Pump and dump, fake results, paid schemes"
        case .hate: return "Attacks on a group or identity"
        case .explicit: return "Sexual or graphic content"
        case .impersonation: return "Pretending to be someone else"
        case .other: return "Tell us more below"
        }
    }
}
