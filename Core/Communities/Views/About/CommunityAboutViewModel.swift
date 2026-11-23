// File: Core/Communities/Views/About/CommunityAboutViewModel.swift
// Loads the Whop-style landing page (docs/backend-contracts.md, section 11, "Community
// landing page"): the leader's checked track record from traderStats/{ownerId}, what's
// inside (channels, courses, the next event, members) and the latest callout results.
// Each part loads on its own and hides itself when it can't be read (for example a paid
// community before subscribing).

import Foundation
import FirebaseFirestore

/// A `calloutResult` message from a callouts channel.
struct CalloutResultSummary: Identifiable, Equatable {
    let id: String
    let channelId: String
    let ticker: String
    let direction: TradeCallout.Direction?
    let status: TradeCallout.Status?
    let exitPrice: Double?
    let resultPercent: Double
    /// "live" when the exit was checked against a live quote
    let exitCheck: String?
    let postedAt: Date

    /// true for a live-checked exit, false for "unchecked", nil when the message doesn't say
    var isPriceChecked: Bool? {
        switch exitCheck {
        case "live": return true
        case "unchecked": return false
        default: return nil
        }
    }

    static func from(_ document: QueryDocumentSnapshot) -> CalloutResultSummary? {
        let data = document.data()
        guard (data["isDeleted"] as? Bool ?? false) == false,
              let result = data["calloutResult"] as? [String: Any],
              let ticker = result["ticker"] as? String,
              let percent = CommunityContentDecode.double(result["resultPercent"]) else { return nil }
        return CalloutResultSummary(
            id: document.documentID,
            channelId: data["channelId"] as? String ?? "",
            ticker: ticker,
            direction: (result["direction"] as? String).flatMap(TradeCallout.Direction.init(rawValue:)),
            status: (result["status"] as? String).flatMap(TradeCallout.Status.init(rawValue:)),
            exitPrice: CommunityContentDecode.double(result["exitPrice"]),
            resultPercent: percent,
            exitCheck: result["exitCheck"] as? String,
            postedAt: CommunityContentDecode.date(data["createdAt"]) ?? Date.distantPast
        )
    }
}

@MainActor
final class CommunityAboutViewModel: ObservableObject {
    enum StatsPhase: Equatable {
        case loading
        case loaded(TraderStats?)
        case failed
    }

    struct Leader: Equatable {
        let username: String
        let imageURL: String?
    }

    @Published private(set) var leader: Leader?
    @Published private(set) var statsPhase: StatsPhase = .loading
    /// nil while loading or when they can't be read
    @Published private(set) var channels: [Channel]?
    @Published private(set) var courseCount: Int?
    @Published private(set) var nextEvent: CommunityEvent?
    @Published private(set) var eventsReadable = false
    @Published private(set) var recentResults: [CalloutResultSummary] = []
    @Published private(set) var hasLoaded = false

    /// How many recent messages are read from each callouts channel to find results.
    /// Ordered by `createdAt` only, so no composite index is needed.
    private let messagesPerChannel = 30
    private let resultLimit = 5

    private var db: Firestore { FirebaseServices.shared.db }

    func load(community: Community) async {
        async let leaderTask: Void = loadLeader(ownerId: community.createdBy)
        async let statsTask: Void = loadStats(ownerId: community.createdBy)
        async let channelsTask: Void = loadChannelsAndResults(communityId: community.id)
        async let coursesTask: Void = loadCourseCount(communityId: community.id)
        async let eventTask: Void = loadNextEvent(communityId: community.id)
        _ = await (leaderTask, statsTask, channelsTask, coursesTask, eventTask)
        hasLoaded = true
    }

    // MARK: - Parts

    private func loadLeader(ownerId: String) async {
        guard !ownerId.isEmpty,
              let user = try? await FirebaseServices.shared.getUserById(userId: ownerId) else { return }
        leader = Leader(username: user.username, imageURL: user.profileImageUrl)
    }

    private func loadStats(ownerId: String) async {
        if case .loaded = statsPhase {} else { statsPhase = .loading }
        do {
            statsPhase = .loaded(try await TraderStatsService.shared.stats(userId: ownerId))
        } catch {
            statsPhase = .failed
        }
    }

    private func loadCourseCount(communityId: String) async {
        courseCount = try? await ClassroomService.shared.courseCount(communityId: communityId)
    }

    private func loadNextEvent(communityId: String) async {
        do {
            nextEvent = try await EventsService.shared.nextEvent(communityId: communityId)
            eventsReadable = true
        } catch {
            nextEvent = nil
            eventsReadable = false
        }
    }

    private func loadChannelsAndResults(communityId: String) async {
        guard let loaded = try? await FirebaseServices.shared.getCommunityChannels(communityId: communityId) else {
            channels = nil
            recentResults = []
            return
        }
        channels = loaded.sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            return lhs.name < rhs.name
        }

        let calloutChannels = loaded.filter { $0.type == .callouts }
        var results: [CalloutResultSummary] = []
        for channel in calloutChannels {
            guard let snapshot = try? await db.collection("communities").document(communityId)
                .collection("channels").document(channel.id)
                .collection("messages")
                .order(by: "createdAt", descending: true)
                .limit(to: messagesPerChannel)
                .getDocuments() else { continue }
            results += snapshot.documents.compactMap { CalloutResultSummary.from($0) }
        }
        recentResults = Array(results.sorted { $0.postedAt > $1.postedAt }.prefix(resultLimit))
    }
}
