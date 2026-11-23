// File: Core/Communities/Views/Detail/ChannelInfoSheet.swift
// Sheet showing a channel's details.

import SwiftUI

struct ChannelInfoSheet: View {
    let community: Community
    let channel: Channel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    HStack(spacing: DS.Spacing.m) {
                        IconWell(
                            systemName: channel.displayIcon,
                            tint: channel.displayTint,
                            size: 52
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text("#\(channel.name)")
                                .font(.title3.weight(.bold))
                            Text("\(channel.isAnnouncements ? "Announcements" : channel.type.displayName) channel in \(community.name)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.m) {
                        infoRow(icon: channel.adminOnly ? "lock.fill" : "bubble.left.and.bubble.right.fill",
                                title: "Who can post",
                                value: channel.adminOnly ? "Owners and admins" : "Every member")
                        Rectangle().fill(Color.hairline).frame(height: 1)
                        infoRow(icon: "calendar",
                                title: "Created",
                                value: channel.createdAt.formatted(date: .abbreviated, time: .omitted))
                    }
                    .cardStyle(padding: DS.Spacing.l)

                    Text(channelDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.Spacing.xs)
                }
                .padding(DS.pageMargin)
            }
            .screenBackground()
            .navigationTitle("Channel Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Color.goldText)
                }
            }
        }
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private var channelDescription: String {
        let posting = channel.adminOnly
            ? "Only admins can post here; everyone can read and react."
            : "Every member can post here."
        switch channel.type {
        case .text, .voice:
            if channel.isAnnouncements {
                return "Announcements from the owners and admins of \(community.name). \(posting)"
            }
            return "A text channel for conversation in \(community.name). \(posting)"
        case .callouts:
            return "A channel for structured trade callouts in \(community.name). Tap \"Track in Portfolio\" on a callout to add it to your trades. \(posting)"
        }
    }
}
