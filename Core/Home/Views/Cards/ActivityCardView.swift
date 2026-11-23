// File: Core/Home/Views/Cards/ActivityCardView.swift
// An activity item (joined a community, closed a trade…) in the Following feed.

import SwiftUI

struct ActivityCardView: View {
    let activity: ActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            IconWell(systemName: activity.activityType.icon, tint: activity.activityType.color, size: 40)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: 6) {
                    Text("@\(activity.username)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text("· \(activity.createdAt.feedRelativeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }

                Text(activity.content)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(activity.activityType.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

// Colour for each activity type (readable in light and dark mode)
extension ActivityItem.ActivityType {
    var color: Color {
        switch self {
        case .newPost: return .info
        case .newTrade: return .marketGreen
        case .joinedCommunity: return .goldText
        case .tradeClosed: return .purple
        case .achievement: return .warning
        }
    }
}
