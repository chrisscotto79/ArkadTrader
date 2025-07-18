//
//  ActivityCardView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/16/25.
//

import SwiftUI

struct ActivityCardView: View {
    let activity: ActivityItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Activity type icon
            ZStack {
                Circle()
                    .fill(activity.activityType.color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: activity.activityType.icon)
                    .foregroundColor(activity.activityType.color)
                    .font(.system(size: 18, weight: .medium))
            }
            
            // Activity content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("@\(activity.username)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(activity.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(activity.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                
                // Activity type badge
                Text(activity.activityType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(activity.activityType.color.opacity(0.1))
                    .foregroundColor(activity.activityType.color)
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// Extension for activity type colors
extension ActivityItem.ActivityType {
    var color: Color {
        switch self {
        case .newPost: return .blue
        case .newTrade: return .green
        case .joinedCommunity: return .orange
        case .tradeClosed: return .purple
        case .achievement: return .yellow
        }
    }
}
