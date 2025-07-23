//
//  CommunityDetailView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/19/25.
//

import SwiftUI

struct CommunityDetailView: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Header
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                        Text("Communities")
                            .font(.body)
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: {
                    // TODO: Community settings
                }) {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            // Community Header
            VStack(spacing: 16) {
                // Community Name & Info
                VStack(spacing: 8) {
                    Text(community.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("\(community.memberCount) members")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Community Description
                if !community.description.isEmpty {
                    Text(community.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                // Community Type Badge
                Text(community.type.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(communityTypeColor)
                    .cornerRadius(8)
            }
            .padding(.vertical, 20)
            .background(Color(.systemGroupedBackground))
            
            // Channels Section
            VStack(spacing: 0) {
                // Section Header
                HStack {
                    Text("CHANNELS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    // TODO: Add channel button for admins
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemGroupedBackground))
                
                // Channels List
                VStack(spacing: 0) {
                    channelRow(name: "general", icon: "number", color: .blue, isAdminOnly: false)
                    Divider().padding(.leading, 56)
                    channelRow(name: "callouts", icon: "megaphone", color: .orange, isAdminOnly: true)
                }
                .background(Color(.systemBackground))
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .background(Color(.systemGroupedBackground))
    }
    
    private func channelRow(name: String, icon: String, color: Color, isAdminOnly: Bool) -> some View {
        Button(action: {
            print("Tapped channel: \(name)")
            // TODO: Navigate to channel view
        }) {
            HStack(spacing: 16) {
                // Channel Icon
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                
                // Channel Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("#\(name)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if isAdminOnly {
                        Text("Admin only")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Admin Badge
                if isAdminOnly {
                    Text("ADMIN")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var communityTypeColor: Color {
        switch community.type {
        case .dayTrading: return .red
        case .swingTrading: return .orange
        case .options: return .purple
        case .crypto: return .yellow
        case .stocks: return .green
        case .general: return .blue
        }
    }
}
