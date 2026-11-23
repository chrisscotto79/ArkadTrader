// File: Core/Notifications/DeepLink.swift
// A place in the app that a notification can open. Built from the `data` map that Cloud
// Functions put on each notification and copy into the push payload
// (docs/backend-contracts.md, section 2: route, communityId, channelId, messageId, postId, userId, symbol;
// section 11 adds eventId, which opens the community for now).

import Foundation

enum DeepLink: Equatable, Sendable {
    case community(id: String)
    case channel(communityId: String, channelId: String, messageId: String?)
    case post(id: String)
    /// nil means the signed-in user's own profile
    case profile(userId: String?)
    case portfolio
    case learn
    case watchlist(symbol: String?)

    /// Reads a push payload (`userInfo`), where the data keys sit at the top level.
    init?(payload: [AnyHashable: Any]) {
        func value(_ key: String) -> String? {
            guard let text = payload[key] as? String, !text.isEmpty else { return nil }
            return text
        }

        guard let route = value("route") else { return nil }

        switch route {
        case "community":
            // callout_update, trade_share and community_event use route "community" and may name
            // a channel and message (docs/backend-contracts.md, section 11).
            guard let communityId = value("communityId") else { return nil }
            if let channelId = value("channelId") {
                self = .channel(communityId: communityId, channelId: channelId, messageId: value("messageId"))
            } else {
                self = .community(id: communityId)
            }
        case "channel":
            guard let communityId = value("communityId") else { return nil }
            if let channelId = value("channelId") {
                self = .channel(communityId: communityId, channelId: channelId, messageId: value("messageId"))
            } else {
                self = .community(id: communityId)
            }
        case "post":
            guard let postId = value("postId") else { return nil }
            self = .post(id: postId)
        case "profile":
            self = .profile(userId: value("userId"))
        case "portfolio":
            self = .portfolio
        case "learn":
            self = .learn
        case "watchlist":
            self = .watchlist(symbol: value("symbol"))
        default:
            return nil
        }
    }

    /// Reads the `data` map of a `notifications/{id}` document.
    init?(data: [String: Any]) {
        var payload: [AnyHashable: Any] = [:]
        for (key, value) in data {
            payload[key] = value
        }
        self.init(payload: payload)
    }
}
