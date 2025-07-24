// File: Core/Communities/Views/Detail/CommunityDetailView.swift
// COMPLETELY REWRITTEN - Clean, Simple, Working Implementation

import SwiftUI

struct CommunityDetailView: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CommunityDetailViewModel()
    @State private var showMembersList = false
    @State private var showCommunitySettings = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Navigation Header
                navigationHeader
                
                // Community Info Card
                communityInfoCard
                
                // Action Buttons
                actionButtons
                
                // Channels Section
                channelsSection
            }
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadCommunityData(community: community)
        }
        .sheet(isPresented: $showMembersList) {
            MembersListSheet(community: community)
        }
        .sheet(isPresented: $showCommunitySettings) {
            CommunitySettingsSheet(community: community)
        }
    }
}

// MARK: - Navigation Header
extension CommunityDetailView {
    private var navigationHeader: some View {
        HStack {
            Button("Back") {
                dismiss()
            }
            .foregroundColor(.blue)
            
            Spacer()
            
            Text(community.name)
                .font(.headline)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: { showCommunitySettings = true }) {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Community Info Card
extension CommunityDetailView {
    private var communityInfoCard: some View {
        VStack(spacing: 20) {
            // Community Avatar
            Circle()
                .fill(communityColor)
                .frame(width: 80, height: 80)
                .overlay(
                    Text(getCommunityInitials())
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // Community Details
            VStack(spacing: 12) {
                Text(community.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if !community.description.isEmpty {
                    Text(community.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                
                // Stats
                HStack(spacing: 30) {
                    VStack {
                        Text("\(community.memberCount)")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Members")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(viewModel.channels.count)")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Channels")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text(viewModel.userRole.capitalized)
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Role")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Badges
                HStack(spacing: 12) {
                    // Type Badge
                    Text(community.type.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(communityColor)
                        .cornerRadius(12)
                    
                    // Privacy Badge
                    if community.isPrivate {
                        Text("Private")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Action Buttons
extension CommunityDetailView {
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Primary Action Button
            if viewModel.isUserMember {
                if viewModel.userRole == "owner" {
                    Button("Manage Community") {
                        showCommunitySettings = true
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .blue))
                } else {
                    Button("Leave Community") {
                        viewModel.leaveCommunity()
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .red))
                }
            } else {
                Button(community.isPrivate ? "Request to Join" : "Join Community") {
                    viewModel.joinCommunity()
                }
                .buttonStyle(PrimaryButtonStyle(color: communityColor))
            }
            
            // Members Button
            Button(action: { showMembersList = true }) {
                Image(systemName: "person.3")
                    .foregroundColor(.blue)
            }
            .frame(width: 44, height: 44)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Channels Section
extension CommunityDetailView {
    private var channelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("CHANNELS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                if viewModel.canManageChannels {
                    Button("Setup") {
                        Task {
                            await viewModel.setupDefaultChannels()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // Channels List
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading channels...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                } else if viewModel.channels.isEmpty {
                    emptyChannelsView
                } else {
                    ForEach(viewModel.channels) { channel in
                        NavigationLink(destination: ChannelChatView(community: community, channel: channel)) {
                            ChannelRow(channel: channel)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if channel.id != viewModel.channels.last?.id {
                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private var emptyChannelsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "number.square.dashed")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No channels yet")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Channels help organize conversations by topic")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if viewModel.canManageChannels {
                Button("Create Default Channels") {
                    Task {
                        await viewModel.setupDefaultChannels()
                    }
                }
                .buttonStyle(PrimaryButtonStyle(color: communityColor))
            }
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Channel Row Component
struct ChannelRow: View {
    let channel: Channel
    
    var body: some View {
        HStack(spacing: 12) {
            // Channel Icon
            Circle()
                .fill(channelColor.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: channelIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(channelColor)
                )
            
            // Channel Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("#\(channel.name)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if channel.adminOnly {
                        Text("ADMIN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                Text(channelDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    private var channelColor: Color {
        switch channel.type {
        case .text: return .blue
        case .callouts: return .orange
        case .voice: return .green
        }
    }
    
    private var channelIcon: String {
        switch channel.type {
        case .text: return "number"
        case .callouts: return "megaphone"
        case .voice: return "speaker.wave.2"
        }
    }
    
    private var channelDescription: String {
        switch channel.type {
        case .text:
            return channel.adminOnly ? "Admin-only discussion" : "General discussion"
        case .callouts:
            return "Trading signals and callouts"
        case .voice:
            return "Voice chat channel"
        }
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Helper Methods
extension CommunityDetailView {
    private var communityColor: Color {
        switch community.type {
        case .dayTrading: return .red
        case .swingTrading: return .orange
        case .options: return .purple
        case .crypto: return .yellow
        case .stocks: return .green
        case .general: return .blue
        }
    }
    
    private func getCommunityInitials() -> String {
        let words = community.name.components(separatedBy: " ")
        if words.count >= 2 {
            let first = String(words[0].prefix(1))
            let second = String(words[1].prefix(1))
            return (first + second).uppercased()
        } else {
            return String(community.name.prefix(2)).uppercased()
        }
    }
}

// MARK: - Sheet Views
struct MembersListSheet: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Members of \(community.name)")
                    .font(.title2)
                    .padding()
                
                Text("Member management coming soon")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct CommunitySettingsSheet: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Community Info")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(community.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(community.type.displayName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Members")
                        Spacer()
                        Text("\(community.memberCount)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Actions")) {
                    Button("Edit Community") {
                        // TODO: Edit functionality
                    }
                    
                    Button("Manage Members") {
                        // TODO: Member management
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    let testCommunity = Community(
        name: "Elite Traders",
        description: "A premium community for day traders sharing strategies and real-time market analysis.",
        type: .dayTrading,
        creatorId: "test-user",
        memberCount: 156,
        isPrivate: false
    )
    
    NavigationView {
        CommunityDetailView(community: testCommunity)
    }
    .environmentObject(FirebaseAuthService.shared)
}
