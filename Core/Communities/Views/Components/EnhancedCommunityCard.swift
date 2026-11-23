// File: Core/Communities/Views/Components/EnhancedCommunityCard.swift
// Building blocks shared by the Communities screens: the rounded-square community avatar,
// list rows, card lists and the discovery spotlight card.

import SwiftUI

// MARK: - Avatar colours and formatting

enum CommunityPalette {
    /// Mid-tone colours that carry white initials in light and dark mode.
    private static let colors: [Color] = [
        Color(red: 0.345, green: 0.337, blue: 0.839), // indigo
        Color(red: 0.184, green: 0.435, blue: 0.929), // blue
        Color(red: 0.055, green: 0.541, blue: 0.541), // teal
        Color(red: 0.878, green: 0.478, blue: 0.122), // orange
        Color(red: 0.839, green: 0.271, blue: 0.435), // pink
        Color(red: 0.557, green: 0.306, blue: 0.776), // purple
        Color(red: 0.310, green: 0.388, blue: 0.471), // slate
        Color(red: 0.604, green: 0.420, blue: 0.247)  // bronze
    ]

    /// A stable colour for a name (FNV-1a hash, so it's the same on every launch and device).
    static func color(for seed: String) -> Color {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in seed.lowercased().utf8 {
            hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return colors[Int(hash % UInt64(colors.count))]
    }

    /// "Elite Traders" -> "ET", "Options" -> "OP", "" -> "?"
    static func initials(for name: String) -> String {
        let words = name.split(separator: " ").filter { !$0.isEmpty }
        if words.count >= 2 {
            return (String(words[0].prefix(1)) + String(words[1].prefix(1))).uppercased()
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "?" : String(trimmed.prefix(2)).uppercased()
    }
}

enum CommunityFormat {
    static func members(_ count: Int) -> String {
        count == 1 ? "1 member" : "\(count.formatted()) members"
    }

    /// "Day Trading · 128 members"
    static func summary(_ community: Community) -> String {
        "\(community.type.shortDisplayName) · \(members(community.memberCount))"
    }
}

// MARK: - Community Avatar

/// Rounded-square community avatar: the uploaded image, or initials on a colour derived from the name.
struct CommunityAvatar: View {
    let name: String
    var imageURL: String? = nil
    var size: CGFloat = 48

    init(community: Community, size: CGFloat = 48) {
        self.name = community.name
        self.imageURL = community.avatarURL
        self.size = size
    }

    init(name: String, imageURL: String? = nil, size: CGFloat = 48) {
        self.name = name
        self.imageURL = imageURL
        self.size = size
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
    }

    var body: some View {
        ZStack {
            shape.fill(CommunityPalette.color(for: name))
            Text(CommunityPalette.initials(for: name))
                .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            if let imageURL, !imageURL.isEmpty, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
                .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.hairline, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

// MARK: - Rows and lists

/// Avatar, name and "type · members" with an optional trailing accessory.
struct CommunityRowContent<Accessory: View>: View {
    let community: Community
    var subtitle: String? = nil
    var avatarSize: CGFloat = 48
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            CommunityAvatar(community: community, size: avatarSize)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(community.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    if community.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Private")
                    }
                }
                Text(subtitle ?? CommunityFormat.summary(community))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DS.Spacing.s)
            accessory()
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .contentShape(Rectangle())
    }
}

/// The grey disclosure chevron used at the end of tappable rows.
struct CommunityChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(.tertiaryLabel))
            .accessibilityHidden(true)
    }
}

/// A card holding rows separated by hairlines.
struct CommunityCardList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var dividerInset: CGFloat = 76
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(Color.hairline)
                        .frame(height: 1)
                        .padding(.leading, dividerInset)
                }
                row(item)
            }
        }
        .cardStyle(padding: 0)
    }
}

/// Small "Joined" marker for communities the user already belongs to.
struct JoinedTag: View {
    var body: some View {
        Tag(text: "Joined", systemImage: "checkmark", tint: .marketGreen)
    }
}

// MARK: - Spotlight card (Discover carousel)

/// Wide discovery card: banner strip, avatar, name, description, activity and a Join button.
struct EnhancedCommunityCard: View {
    let community: Community
    let isUserMember: Bool
    var width: CGFloat = 272
    let onTap: () -> Void
    let onJoin: () -> Void
    let onInfo: () -> Void

    private var bannerHeight: CGFloat { 84 }
    private var avatarSize: CGFloat { 56 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 0) {
                    banner
                    details
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())

            footer
        }
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous).fill(Color.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            IconButton(systemName: "info", accessibilityLabel: "About \(community.name)", size: 30, action: onInfo)
                .padding(10)
        }
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            bannerFill
                .frame(height: bannerHeight)
                .frame(maxWidth: .infinity)
                .clipped()

            CommunityAvatar(community: community, size: avatarSize)
                .overlay(
                    RoundedRectangle(cornerRadius: avatarSize * 0.28, style: .continuous)
                        .strokeBorder(Color.surface, lineWidth: 3)
                )
                .padding(.leading, DS.Spacing.l)
                .offset(y: avatarSize / 2)
        }
        .padding(.bottom, avatarSize / 2)
    }

    @ViewBuilder
    private var bannerFill: some View {
        let tint = CommunityPalette.color(for: community.name)
        if let urlString = community.bannerURL, !urlString.isEmpty, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    tint.opacity(0.18)
                }
            }
        } else {
            tint.opacity(0.18)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(community.name)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                if community.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(CommunityFormat.summary(community))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(community.description)
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.8))
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .padding(.top, 2)
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.top, DS.Spacing.s)
    }

    private var footer: some View {
        HStack(spacing: DS.Spacing.s) {
            if community.isRecentlyActive {
                HStack(spacing: 5) {
                    Circle().fill(Color.marketGreen).frame(width: 6, height: 6)
                    Text(community.lastActivityText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if isUserMember {
                JoinedTag()
            } else {
                Button("Join", action: onJoin)
                    .buttonStyle(PillButtonStyle(kind: .gold))
                    .accessibilityLabel("Join \(community.name)")
            }
        }
        .frame(minHeight: 34)
        .padding(.horizontal, DS.Spacing.l)
        .padding(.top, DS.Spacing.m)
        .padding(.bottom, DS.Spacing.l)
    }
}

// MARK: - Custom Shape for Rounded Corners (kept for the chat overlays)
struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview
#Preview {
    let sample = Community(
        name: "Crypto Traders",
        description: "Advanced cryptocurrency trading strategies and market analysis",
        type: .crypto,
        creatorId: "user123",
        memberCount: 247,
        isPrivate: false
    )

    ScrollView {
        VStack(spacing: 20) {
            EnhancedCommunityCard(community: sample, isUserMember: false, onTap: {}, onJoin: {}, onInfo: {})
            CommunityCardList(items: [sample]) { community in
                CommunityRowContent(community: community) { CommunityChevron() }
            }
        }
        .padding()
    }
    .screenBackground()
}
