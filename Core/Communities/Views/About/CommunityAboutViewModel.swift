// File: Core/Communities/Views/About/CommunityAboutViewModel.swift
// Loads the Whop-style landing page (docs/backend-contracts.md, section 11, "Community
// landing page"): the leader's track record from traderStats/{ownerId}, what's inside
// (channels, courses, the next event, members) and the leader's latest callout results.
// Each part loads on its own and hides itself when it can't be read (for example a paid
// community before subscribing).

import Foundation
import FirebaseFirestore

/// A `calloutResult` message from a callouts channel, checked against its parent callout.
struct CalloutResultSummary: Identifiable, Equatable {
    let id: String
    let channelId: String
    let ticker: String
    let direction: TradeCallout.Direction?
    let status: TradeCallout.Status?
    let exitPrice: Double?
    let resultPercent: Double
    /// True only when the parent callout's entry and the result's exit were both checked
    /// against a live quote (`priceCheck == "live"` and `exitCheck == "live"`).
    let isPriceChecked: Bool
    let postedAt: Date

    /// A result message, before its parent is checked: the fields it claims.
    struct Candidate {
        let id: String
        let channelId: String
        let authorId: String
        let parentMessageId: String
        let result: CalloutResult
        let postedAt: Date
    }

    static func candidate(_ document: QueryDocumentSnapshot) -> Candidate? {
        let data = document.data()
        guard (data["isDeleted"] as? Bool ?? false) == false,
              let raw = data["calloutResult"] as? [String: Any],
              let result = CalloutResult.fromFirestore(raw),
              let authorId = data["authorId"] as? String,
              // Result messages have the fixed id "<parentId>_result"
              document.documentID == CalloutFollowUps.resultMessageId(for: result.parentMessageId) else { return nil }
        return Candidate(
            id: document.documentID,
            channelId: data["channelId"] as? String ?? "",
            authorId: authorId,
            parentMessageId: result.parentMessageId,
            result: result,
            postedAt: CommunityContentDecode.date(data["createdAt"]) ?? Date.distantPast
        )
    }

    /// The summary, when the parent message is the same author's callout on the same ticker and
    /// direction. Nil otherwise (a result that doesn't match its callout isn't shown).
    static func verify(_ candidate: Candidate, parentData: [String: Any]?) -> CalloutResultSummary? {
        guard let parentData,
              (parentData["authorId"] as? String) == candidate.authorId,
              let callout = (parentData["callout"] as? [String: Any]).flatMap(TradeCallout.fromFirestore),
              callout.ticker == candidate.result.ticker,
              callout.direction == candidate.result.direction else { return nil }
        let result = candidate.result
        return CalloutResultSummary(
            id: candidate.id,
            channelId: candidate.channelId,
            ticker: result.ticker,
            direction: result.direction,
            status: result.status,
            exitPrice: result.exitPrice,
            resultPercent: result.resultPercent,
            isPriceChecked: callout.isPriceChecked && result.isPriceChecked,
            postedAt: candidate.postedAt
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
        var fullName: String? = nil
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
        async let channelsTask: Void = loadChannelsAndResults(communityId: community.id, leaderId: community.createdBy)
        async let coursesTask: Void = loadCourseCount(communityId: community.id)
        async let eventTask: Void = loadNextEvent(communityId: community.id)
        _ = await (leaderTask, statsTask, channelsTask, coursesTask, eventTask)
        hasLoaded = true
    }

    // MARK: - Parts

    private func loadLeader(ownerId: String) async {
        guard !ownerId.isEmpty,
              let user = try? await FirebaseServices.shared.getUserById(userId: ownerId) else { return }
        leader = Leader(username: user.username, imageURL: user.profileImageUrl, fullName: user.fullName)
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

    private func loadChannelsAndResults(communityId: String, leaderId: String) async {
        guard let loaded = try? await FirebaseServices.shared.getCommunityChannels(communityId: communityId) else {
            channels = nil
            recentResults = []
            return
        }
        channels = loaded.sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            return lhs.name < rhs.name
        }

        // The leader's result messages, each checked against its parent callout.
        let calloutChannels = loaded.filter { $0.type == .callouts }
        var candidates: [CalloutResultSummary.Candidate] = []
        var messagesById: [String: [String: Any]] = [:]
        for channel in calloutChannels {
            guard let snapshot = try? await db.collection("communities").document(communityId)
                .collection("channels").document(channel.id)
                .collection("messages")
                .order(by: "createdAt", descending: true)
                .limit(to: messagesPerChannel)
                .getDocuments() else { continue }
            for document in snapshot.documents {
                messagesById["\(channel.id)/\(document.documentID)"] = document.data()
                if let candidate = CalloutResultSummary.candidate(document), candidate.authorId == leaderId {
                    candidates.append(candidate)
                }
            }
        }

        var results: [CalloutResultSummary] = []
        for candidate in candidates.sorted(by: { $0.postedAt > $1.postedAt }) {
            guard results.count < resultLimit else { break }
            let key = "\(candidate.channelId)/\(candidate.parentMessageId)"
            var parent = messagesById[key]
            if parent == nil {
                parent = try? await FirebaseServices.shared.channelMessageRef(
                    communityId: communityId, channelId: candidate.channelId, messageId: candidate.parentMessageId
                ).getDocument().data()
            }
            if let summary = CalloutResultSummary.verify(candidate, parentData: parent) {
                results.append(summary)
            }
        }
        recentResults = results
    }
}
