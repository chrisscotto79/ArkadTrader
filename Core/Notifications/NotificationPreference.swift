// File: Core/Notifications/NotificationPreference.swift
// The keys of `users/{uid}.notificationPrefs` (docs/backend-contracts.md, section 2).
// Every preference is on unless the user turns it off.

import SwiftUI

enum NotificationPreference: String, CaseIterable, Identifiable {
    case callouts
    case calloutResults
    case communityActivity
    case mentions
    case replies
    case follows
    case likes
    case priceAlerts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .callouts: return "New callouts"
        case .calloutResults: return "Callout results"
        case .communityActivity: return "Your communities"
        case .mentions: return "Mentions"
        case .replies: return "Replies"
        case .follows: return "New followers"
        case .likes: return "Likes"
        case .priceAlerts: return "Price alerts"
        }
    }

    var subtitle: String {
        switch self {
        case .callouts: return "When a trader posts a callout in a community you're in"
        case .calloutResults: return "When a callout hits its target or stop, or is closed"
        case .communityActivity:
            return AppConfig.paidCommunitiesEnabled
                ? "Callout updates, shared trades and events in your communities, plus new members and subscriptions in ones you own"
                : "Callout updates, shared trades and events in your communities, plus new members in ones you own"
        case .mentions: return "When someone mentions your @username"
        case .replies: return "When someone comments on your post"
        case .follows: return "When someone follows you"
        case .likes: return "When someone likes your post"
        case .priceAlerts:
            return AppConfig.serverFunctionsEnabled
                ? "When a price alert you set is reached"
                : "When a price alert you set is reached, while Arkad is open"
        }
    }

    var systemImage: String {
        switch self {
        case .callouts: return "megaphone.fill"
        case .calloutResults: return "flag.checkered"
        case .communityActivity: return "person.3.fill"
        case .mentions: return "at"
        case .replies: return "bubble.left.fill"
        case .follows: return "person.badge.plus"
        case .likes: return "heart.fill"
        case .priceAlerts: return "bell.badge.fill"
        }
    }

    /// The preference that controls a `notifications/{id}` type (docs/backend-contracts.md,
    /// section 2). nil for types no preference covers, which are always shown.
    init?(notificationType type: String) {
        switch type {
        case "callout": self = .callouts
        case "callout_result": self = .calloutResults
        case "mention": self = .mentions
        case "reply": self = .replies
        case "like": self = .likes
        case "follow": self = .follows
        case "member_joined", "subscription": self = .communityActivity
        // Community expansion (docs/backend-contracts.md, section 11): "Your communities"
        case "callout_update", "trade_share", "community_event": self = .communityActivity
        case "price_alert": self = .priceAlerts
        default: return nil
        }
    }

    struct PreferenceGroup: Identifiable {
        let title: String
        let items: [NotificationPreference]
        var id: String { title }
    }

    /// How the settings screen groups the preferences
    static let groups: [PreferenceGroup] = [
        PreferenceGroup(title: "Communities", items: [.callouts, .calloutResults, .communityActivity]),
        PreferenceGroup(title: "People", items: [.mentions, .replies, .follows, .likes]),
        PreferenceGroup(title: "Markets", items: [.priceAlerts])
    ]
}

/// Icon and colour for a `notifications/{id}` type, used by the inbox rows.
enum NotificationKind {
    static func systemImage(for type: String) -> String {
        switch type {
        case "callout": return "megaphone.fill"
        case "callout_result": return "flag.checkered"
        case "mention": return "at"
        case "reply": return "bubble.left.fill"
        case "like": return "heart.fill"
        case "follow": return "person.badge.plus"
        case "member_joined": return "person.3.fill"
        case "subscription": return "creditcard.fill"
        case "price_alert": return "bell.badge.fill"
        case "callout_update": return "arrow.triangle.branch"
        case "trade_share": return "chart.line.uptrend.xyaxis"
        case "community_event": return "calendar"
        default: return "bell.fill"
        }
    }

    static func tint(for type: String) -> Color {
        switch type {
        case "callout_result", "subscription": return .marketGreen
        case "like": return .marketRed
        case "mention", "reply": return .info
        case "price_alert": return .warning
        case "community_event": return .info
        default: return .goldText
        }
    }
}

/// Which notifications the inbox and the Home bell show the signed-in user.
@MainActor
enum InboxFilter {
    /// Hides notifications from people you've blocked. In free mode it also hides the types
    /// you turned off in `notificationPrefs`, because the sender's app creates them regardless.
    static func isVisible(type: String, fromUserId: String?) -> Bool {
        if let fromUserId, !fromUserId.isEmpty, BlockStore.shared.isBlocked(fromUserId) {
            return false
        }
        guard !AppConfig.serverFunctionsEnabled,
              let preference = NotificationPreference(notificationType: type) else { return true }
        return FirebaseAuthService.shared.currentUser?.isNotificationEnabled(preference.rawValue) ?? true
    }

    static func isVisible(_ entry: InboxEntry) -> Bool {
        isVisible(type: entry.notification.type, fromUserId: entry.fromUserId)
    }
}
