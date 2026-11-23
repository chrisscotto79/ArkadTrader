// File: Core/Communities/Views/Share/ShareTradeToCommunitySheet.swift
// "Share to community" for one of your logged trades (docs/backend-contracts.md, section 11).
// Lists the communities you've joined and the channels you can post in (admin-only channels only
// for owners and admins, which is what firestore.rules allows), takes an optional note, and sends
// a channel message with `tradeShare { tradeId, ticker, tradeType, entryPrice, quantity, isOpen,
// exitPrice?, proof, note? }`.
//
// The rules compare every field with `trades/{tradeId}`, so the map is built from a fresh read of
// the trade document, with each value exactly as stored. Members get a `trade_share` notification
// when the channel is a callouts channel.
//
// Usage: `.sheet(item: $tradeToShare) { ShareTradeToCommunitySheet(trade: $0) }`

import SwiftUI

struct ShareTradeToCommunitySheet: View {
    let trade: Trade

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = ShareTradeToCommunityModel()
    @State private var selection: ShareTradeToCommunityModel.Destination?
    @State private var note = ""

    init(trade: Trade) {
        self.trade = trade
    }

    /// How the card previews the trade. Posting re-reads the trade doc, so the posted copy
    /// always matches what's stored.
    private var preview: TradeShareInfo {
        TradeShareInfo(
            tradeId: trade.id,
            ticker: trade.ticker,
            tradeType: trade.tradeType.rawValue,
            entryPrice: trade.entryPrice,
            quantity: trade.quantity,
            isOpen: trade.isOpen,
            exitPrice: trade.isOpen ? nil : trade.exitPrice,
            proof: ShareTradeToCommunityModel.proof(of: trade),
            note: note,
            side: trade.side.rawValue
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    TradeShareCard(share: preview)
                        .frame(maxWidth: .infinity)

                    destinationsSection

                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        sectionLabel("Note (optional)")
                        TextField("Why you took it, what you learned…", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .cardStyle(padding: DS.Spacing.l)
                            .onChange(of: note) { _, newValue in
                                if newValue.count > 500 { note = String(newValue.prefix(500)) }
                            }
                    }

                    if let sendError = model.sendError {
                        Label(sendError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.marketRed)
                            .padding(.horizontal, DS.Spacing.xs)
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.vertical, DS.Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("Share Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Color.goldText)
                }
            }
            .safeAreaInset(edge: .bottom) { shareBar }
            .task { await model.load() }
        }
        .presentationDragIndicator(.visible)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(.secondary)
            .padding(.leading, DS.Spacing.xs)
    }

    // MARK: - Destinations

    @ViewBuilder
    private var destinationsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            sectionLabel("Post to")
            if model.isLoading {
                HStack(spacing: DS.Spacing.s) {
                    ProgressView()
                    Text("Loading your communities…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: DS.Spacing.l)
            } else if let loadError = model.loadError {
                EmptyStateView(
                    systemImage: "wifi.exclamationmark",
                    title: "Couldn't load your communities",
                    message: loadError,
                    actionTitle: "Try again"
                ) {
                    Task { await model.load() }
                }
                .cardStyle(padding: 0)
            } else if model.groups.isEmpty {
                EmptyStateView(
                    systemImage: "person.3",
                    title: "No communities yet",
                    message: "Join a community to share your trades with its members."
                )
                .cardStyle(padding: 0)
            } else {
                ForEach(model.groups) { group in
                    communityCard(group)
                }
            }
        }
    }

    private func communityCard(_ group: ShareTradeToCommunityModel.Group) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Spacing.m) {
                CommunityAvatar(community: group.community, size: 32)
                Text(group.community.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.m)

            if let mutedUntil = group.mutedUntil {
                Rectangle().fill(Color.hairline).frame(height: 1)
                Label("You're muted here until \(mutedUntil.formatted(date: .abbreviated, time: .shortened))",
                      systemImage: "speaker.slash.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.l)
                    .padding(.vertical, DS.Spacing.m)
            } else if group.channels.isEmpty {
                Rectangle().fill(Color.hairline).frame(height: 1)
                Text("No channels you can post in")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.l)
                    .padding(.vertical, DS.Spacing.m)
            } else {
                ForEach(group.channels) { channel in
                    Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, DS.Spacing.l)
                    channelRow(channel, in: group)
                }
            }
        }
        .cardStyle(padding: 0)
    }

    private func channelRow(_ channel: Channel, in group: ShareTradeToCommunityModel.Group) -> some View {
        let destination = ShareTradeToCommunityModel.Destination(communityId: group.community.id, channelId: channel.id)
        let isSelected = selection == destination
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            selection = destination
        } label: {
            HStack(spacing: DS.Spacing.m) {
                IconWell(systemName: channel.displayIcon, tint: channel.displayTint, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text("#\(channel.name)")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    if channel.type == .callouts {
                        Text("Members are notified")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: DS.Spacing.s)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.goldText : Color(.tertiaryLabel))
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Share

    private var selectedChannel: (group: ShareTradeToCommunityModel.Group, channel: Channel)? {
        guard let selection,
              let group = model.groups.first(where: { $0.community.id == selection.communityId }),
              let channel = group.channels.first(where: { $0.id == selection.channelId }) else { return nil }
        return (group, channel)
    }

    private var shareBar: some View {
        Button {
            guard let target = selectedChannel else { return }
            Task {
                if await model.send(trade: trade, community: target.group.community, channel: target.channel, note: note) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                }
            }
        } label: {
            if model.isSending {
                ProgressView().tint(Color.onGold)
            } else {
                Label(selectedChannel.map { "Share to #\($0.channel.name)" } ?? "Choose a channel",
                      systemImage: "square.and.arrow.up")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(selectedChannel == nil || model.isSending)
        .padding(.horizontal, DS.pageMargin)
        .padding(.vertical, DS.Spacing.s)
        .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Model

@MainActor
final class ShareTradeToCommunityModel: ObservableObject {
    struct Destination: Hashable {
        let communityId: String
        let channelId: String
    }

    /// A joined community and the channels the user may post in.
    struct Group: Identifiable {
        let community: Community
        let channels: [Channel]
        /// Set while the user is muted there (they can't post)
        let mutedUntil: Date?
        var id: String { community.id }
    }

    @Published private(set) var groups: [Group] = []
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?
    @Published private(set) var isSending = false
    @Published var sendError: String?

    private let firebase = FirebaseServices.shared

    /// The trade's proof label. A trade without one is self-reported (docs/backend-contracts.md,
    /// section 0); `Trade.proof` already decodes it that way.
    static func proof(of trade: Trade) -> TradeProof {
        trade.proof
    }

    func load() async {
        guard let user = FirebaseAuthService.shared.currentUser else {
            isLoading = false
            loadError = "Sign in to share trades."
            return
        }
        isLoading = true
        loadError = nil
        let communities: [Community]
        do {
            communities = try await firebase.getUserCommunities(userId: user.id)
        } catch {
            isLoading = false
            loadError = "Check your connection and try again."
            return
        }

        var loaded: [Group] = []
        await withTaskGroup(of: Group?.self) { taskGroup in
            for community in communities {
                taskGroup.addTask { await Self.group(for: community, userId: user.id) }
            }
            for await group in taskGroup {
                if let group { loaded.append(group) }
            }
        }
        groups = loaded.sorted { $0.community.name.localizedCaseInsensitiveCompare($1.community.name) == .orderedAscending }
        isLoading = false
    }

    /// The channels `userId` can post in: everything, except admin-only channels unless they're
    /// the owner or an admin (firestore.rules: `channel.adminOnly == false || isAdmin(cid)`).
    /// Nil when they aren't a member.
    private static func group(for community: Community, userId: String) async -> Group? {
        let firebase = FirebaseServices.shared
        guard let status = try? await firebase.memberPostingStatus(
            communityId: community.id, userId: userId, createdBy: community.createdBy
        ), let role = status.role else { return nil }

        if let mutedUntil = status.mutedUntil, mutedUntil > Date() {
            return Group(community: community, channels: [], mutedUntil: mutedUntil)
        }
        let isAdmin = role == .owner || role == .admin
        let channels = (try? await firebase.getCommunityChannels(communityId: community.id)) ?? []
        let postable = channels
            .filter { !$0.adminOnly || isAdmin }
            // Callouts channels first: that's where trades usually go
            .sorted { ($0.type == .callouts ? 0 : 1) < ($1.type == .callouts ? 0 : 1) }
        return Group(community: community, channels: postable, mutedUntil: nil)
    }

    /// Sends the trade share. Returns true when it was posted.
    func send(trade: Trade, community: Community, channel: Channel, note: String) async -> Bool {
        guard !isSending else { return false }
        guard let user = FirebaseAuthService.shared.currentUser, trade.userId == user.id else {
            sendError = "You can only share your own trades."
            return false
        }
        isSending = true
        sendError = nil
        defer { isSending = false }

        // Fresh copy of the trade, so the shared values are exactly what the rules compare against
        let tradeDoc: [String: Any]
        do {
            guard let data = try await firebase.getTradeData(tradeId: trade.id) else {
                sendError = "This trade couldn't be found."
                return false
            }
            tradeDoc = data
        } catch {
            sendError = "Couldn't load the trade. Check your connection and try again."
            return false
        }
        guard (tradeDoc["userId"] as? String) == user.id,
              let shareData = TradeShareInfo.firestoreData(fromTradeDoc: tradeDoc, tradeId: trade.id, note: note),
              let share = TradeShareInfo.fromFirestore(shareData) else {
            sendError = "This trade is missing details and can't be shared."
            return false
        }

        var message = CommunityMessage(
            content: ChatText.clip(share.summary, max: ChatText.contentLimit),
            authorId: user.id,
            authorUsername: user.username,
            channelId: channel.id,
            communityId: community.id,
            authorAvatarURL: user.profileImageUrl
        )
        message.tradeShare = share

        do {
            try await firebase.sendCommunityMessage(message, overrides: ["tradeShare": shareData])
        } catch {
            sendError = "Couldn't share the trade: \(error.localizedDescription)"
            return false
        }

        if channel.type == .callouts {
            let posted = message
            let username = user.username
            Task {
                // Fanned out like new callouts (TrackRecordWriter.calloutPosted)
                let recipients = await TrackRecordWriter.shared.memberIds(communityId: community.id)
                    .filter { $0 != user.id }
                await FirebaseServices.shared.createNotifications(
                    to: recipients,
                    type: "trade_share",
                    title: ChatText.clip("\(username) shared a $\(share.ticker) trade in #\(channel.name)", max: 200),
                    body: ChatText.clip(posted.content, max: 1000),
                    data: CalloutFollowUps.communityRoute(communityId: community.id, channelId: channel.id,
                                                          messageId: posted.id)
                )
            }
        }
        return true
    }
}

#Preview {
    var trade = Trade(ticker: "AAPL", tradeType: .stock, entryPrice: 182.45, quantity: 10, userId: "me")
    trade.close(at: 190)
    return ShareTradeToCommunitySheet(trade: trade)
}
