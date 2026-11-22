// File: Core/Communities/Views/Detail/CommunityDetailView.swift
// A community's home page: header, stats, channels and about section.

import SwiftUI

struct CommunityDetailView: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = CommunityDetailViewModel()
    
    // View States
    @State private var showMembersList = false
    @State private var showCommunitySettings = false
    @State private var showCreateChannel = false
    @State private var selectedChannel: Channel?
    @State private var showChannelOptions = false
    @State private var channelToEdit: Channel?
    @State private var channelForInfo: Channel?
    @State private var showLeaderboard = false
    @State private var headerOffset: CGFloat = 0
    @State private var showJoinConfirmation = false
    @State private var animateEntry = false
    
    /// Latest copy of the community (refreshed after settings change), falling back to the one passed in.
    private var current: Community { viewModel.community ?? community }
    
    // UI Constants
    private let headerHeight: CGFloat = 300
    private let cornerRadius: CGFloat = 24
    
    var body: some View {
        ZStack {
            // Background Gradient
            backgroundGradient
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Parallax Header
                    parallaxHeader
                        .frame(height: headerHeight)
                        .offset(y: headerOffset > 0 ? -headerOffset : 0)
                        .scaleEffect(headerOffset > 0 ? 1 : 1 + (headerOffset / 500))
                    
                    // Main Content
                    VStack(spacing: 24) {
                        // Community Actions Card
                        enhancedCommunityActionsCard
                            .offset(y: -40)
                            .padding(.bottom, -40)
                        
                        // Quick Stats Grid
                        modernStatsGrid
                        
                        // Channels Section
                        enhancedChannelsSection
                    }
                    .padding(.bottom, 32)
                }
                .background(GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("scroll")).minY
                    )
                })
            }
            .coordinateSpace(name: "scroll")
            .ignoresSafeArea(edges: .top)
            
            // Floating Navigation Bar
            floatingNavigationBar
        }
        .navigationBarHidden(true)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            headerOffset = value
        }
        .onAppear {
            viewModel.loadCommunityData(community: community)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateEntry = true
            }
        }
        .sheet(isPresented: $showMembersList) {
            EnhancedMembersListSheet(community: community)
        }
        .sheet(isPresented: $showCommunitySettings, onDismiss: {
            Task { await viewModel.reloadCommunity() }
        }) {
            EnhancedCommunitySettingsSheet(community: current)
        }
        .sheet(isPresented: $showCreateChannel, onDismiss: {
            Task { await viewModel.reloadChannels() }
        }) {
            CreateChannelSheet(community: current)
        }
        .sheet(item: $channelToEdit, onDismiss: {
            Task { await viewModel.reloadChannels() }
        }) { channel in
            CreateChannelSheet(community: current, editing: channel)
        }
        .navigationDestination(isPresented: $showLeaderboard) {
            CommunityLeaderboardView(community: current)
        }
        .alert(
            channelForInfo.map { "#\($0.name)" } ?? "",
            isPresented: Binding(get: { channelForInfo != nil }, set: { if !$0 { channelForInfo = nil } }),
            presenting: channelForInfo
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { channel in
            Text(channelInfoText(channel))
        }
        .confirmationDialog("Channel Options", isPresented: $showChannelOptions) {
            if let channel = selectedChannel {
                if viewModel.canManageChannels && !channel.isDefault {
                    Button("Edit Channel") {
                        channelToEdit = channel
                    }
                    
                    Button("Delete Channel", role: .destructive) {
                        Task {
                            do {
                                try await viewModel.deleteChannel(channel)
                            } catch {
                                print("Error deleting channel: \(error)")
                            }
                        }
                    }
                }
                
                Button("Channel Info") {
                    channelForInfo = channel
                }
                
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func channelInfoText(_ channel: Channel) -> String {
        let posting = channel.adminOnly ? "Only admins can post." : "Everyone can post."
        let created = channel.createdAt.formatted(date: .abbreviated, time: .omitted)
        return "\(channel.type.displayName) channel · Created \(created)\n\(posting)"
    }

    private var communityColor: Color {
        current.type.tint
    }

    private func getCommunityInitials() -> String {
        let words = current.name.components(separatedBy: " ")
        if words.count >= 2 {
            let first = String(words[0].prefix(1))
            let second = String(words[1].prefix(1))
            return (first + second).uppercased()
        } else {
            return String(current.name.prefix(2)).uppercased()
        }
    }

    private func getCommunityTypeIcon() -> String {
        switch current.type {
        case .general: return "person.3"
        case .dayTrading: return "chart.line.uptrend.xyaxis"
        case .swingTrading: return "chart.bar"
        case .options: return "option"
        case .crypto: return "bitcoinsign.circle"
        case .stocks: return "building.columns"
        }
    }
    
    private func getRoleIcon() -> String {
        switch viewModel.userRole {
        case "owner": return "crown.fill"
        case "admin": return "shield.fill"
        case "moderator": return "star.fill"
        default: return "person.fill"
        }
    }

    private func getRoleColor() -> Color {
        switch viewModel.userRole {
        case "owner": return .purple
        case "admin": return .orange
        case "moderator": return .blue
        default: return .green
        }
    }
}

// MARK: - Background & Header Components
extension CommunityDetailView {
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private var parallaxHeader: some View {
        ZStack {
            // Banner image (if set) under a tinted gradient so text stays readable
            if let urlString = current.bannerURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    communityColor
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            
            LinearGradient(
                colors: [
                    communityColor.opacity(current.bannerURL == nil ? 0.9 : 0.55),
                    communityColor.opacity(current.bannerURL == nil ? 0.6 : 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Darken the bottom so the white title reads on light community colours
            LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom)

            // Content
            VStack(spacing: 20) {
                Spacer()
                
                // Community Avatar
                communityAvatar
                    .scaleEffect(animateEntry ? 1 : 0.5)
                    .opacity(animateEntry ? 1 : 0)
                
                // Community Info
                VStack(spacing: 8) {
                    Text(current.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                    
                    if !current.description.isEmpty {
                        Text(current.description)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 40)
                    }
                    
                    // Badges
                    HStack(spacing: 8) {
                        Label(current.type.displayName, systemImage: getCommunityTypeIcon())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(.white.opacity(0.2)))
                        
                        if current.isPrivate {
                            Label("Private", systemImage: "lock.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(.white.opacity(0.2)))
                        }
                    }
                }
                .offset(y: animateEntry ? 0 : 20)
                .opacity(animateEntry ? 1 : 0)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 50)
        }
    }
    
    private var communityAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 100, height: 100)
                .blur(radius: 20)
            
            Circle()
                .fill(Color.white)
                .frame(width: 80, height: 80)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                .overlay(
                    Group {
                        if let urlString = current.avatarURL, let url = URL(string: urlString) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                        } else {
                            Text(getCommunityInitials())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(communityColor)
                        }
                    }
                    .frame(width: 76, height: 76)
                    .clipShape(Circle())
                )
            
            if viewModel.isUserMember {
                Circle()
                    .fill(Color.green)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .offset(x: 28, y: 28)
            }
        }
    }
    
    private var floatingNavigationBar: some View {
        VStack {
            HStack {
                // Back Button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(headerOffset < -100 ? .primary : .white)
                        .frame(width: 40, height: 40)
                        .background(
                            .ultraThinMaterial,
                            in: Circle()
                        )
                }
                
                Spacer()
                
                // Title (appears on scroll)
                if headerOffset < -100 {
                    Text(current.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .transition(.opacity.combined(with: .scale))
                }
                
                Spacer()
                
                // Menu Button
                Menu {
                    if viewModel.isUserMember {
                        Button(action: { showCommunitySettings = true }) {
                            Label("Community Settings", systemImage: "gear")
                        }
                        
                        Button(action: { showMembersList = true }) {
                            Label("View Members", systemImage: "person.3")
                        }
                        
                        if viewModel.userRole != "owner" {
                            Button(role: .destructive, action: { viewModel.leaveCommunity() }) {
                                Label("Leave Community", systemImage: "door.right.hand.open")
                            }
                        }
                    } else {
                        Button(action: { showMembersList = true }) {
                            Label("View Members", systemImage: "person.3")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(headerOffset < -100 ? .primary : .white)
                        .frame(width: 40, height: 40)
                        .background(
                            .ultraThinMaterial,
                            in: Circle()
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .animation(.spring(response: 0.3), value: headerOffset)
            
            Spacer()
        }
    }
}

// MARK: - Enhanced Action Cards & Stats
extension CommunityDetailView {
    private var enhancedCommunityActionsCard: some View {
        VStack(spacing: 20) {
            // User Role & Status
            if viewModel.isUserMember {
                HStack {
                    Label(viewModel.userRole.capitalized, systemImage: getRoleIcon())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(getRoleColor())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(getRoleColor().opacity(0.1))
                        .cornerRadius(20)
                    
                    Spacer()
                    
                    Text("Member since Nov 2024")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Primary Actions
            HStack(spacing: 12) {
                // Primary Action Button
                if viewModel.isUserMember {
                    if viewModel.userRole == "owner" {
                        Button(action: { showCommunitySettings = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                Text("Manage Community")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.purple.gradient)
                            )
                        }
                    } else {
                        Button(action: { showCommunitySettings = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "gear")
                                Text("View Settings")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.arkadGold.gradient)
                            )
                        }
                    }
                } else {
                    Button(action: {
                        if current.isPrivate {
                            showJoinConfirmation = true
                        } else {
                            viewModel.joinCommunity()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: current.isPrivate ? "lock.fill" : "person.badge.plus")
                            Text(current.isPrivate ? "Request to Join" : "Join Community")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(communityColor.gradient)
                        )
                    }
                    .alert("Request to Join", isPresented: $showJoinConfirmation) {
                        Button("Cancel", role: .cancel) { }
                        Button("Send Request") {
                            viewModel.joinCommunity()
                        }
                    } message: {
                        Text("Your request will be sent to the community admins for approval.")
                    }
                }
                
                // Secondary Actions
                Button(action: { showMembersList = true }) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                }
                
                if viewModel.canManageChannels {
                    Button(action: { showCreateChannel = true }) {
                        Image(systemName: "plus.bubble.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.green)
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.green.opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
        .scaleEffect(animateEntry ? 1 : 0.9)
        .opacity(animateEntry ? 1 : 0)
    }
    
    private var modernStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            statCard(
                value: "\(current.memberCount)",
                label: "Members",
                icon: "person.3.fill",
                color: .blue
            )
            
            statCard(
                value: "\(viewModel.channels.count)",
                label: "Channels",
                icon: "bubble.left.and.bubble.right.fill",
                color: .purple
            )

            Button {
                showLeaderboard = true
            } label: {
                statCard(
                    value: "Ranks",
                    label: "Leaderboard",
                    icon: "trophy.fill",
                    color: .arkadGold
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open the community leaderboard")
        }
        .padding(.horizontal, 20)
        .opacity(animateEntry ? 1 : 0)
        .offset(y: animateEntry ? 0 : 20)
    }
    
    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Enhanced Channels Section
extension CommunityDetailView {
    private var enhancedChannelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Label("CHANNELS", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text("\(viewModel.channels.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(communityColor)
                        )
                }
                
                if viewModel.canManageChannels {
                    Button(action: { showCreateChannel = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Channels Content
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 70)
                            .shimmer()
                    }
                }
                .padding(.horizontal, 20)
            } else if viewModel.channels.isEmpty {
                enhancedEmptyChannelsView
            } else {
                VStack(spacing: 2) {
                    let groupedChannels = Dictionary(grouping: viewModel.channels) { $0.type }
                    let sortedTypes: [ChannelType] = [.text, .callouts, .voice]
                    
                    ForEach(sortedTypes, id: \.self) { channelType in
                        if let channels = groupedChannels[channelType], !channels.isEmpty {
                            channelGroupView(type: channelType, channels: channels)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .opacity(animateEntry ? 1 : 0)
        .offset(y: animateEntry ? 0 : 20)
    }
    
    private var enhancedEmptyChannelsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.3))
            
            VStack(spacing: 8) {
                Text("No channels yet")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Channels help organize conversations by topic")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if viewModel.canManageChannels {
                VStack(spacing: 12) {
                    Button("Create Default Channels") {
                        Task {
                            await viewModel.setupDefaultChannels()
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(communityColor.gradient)
                    )
                    
                    Button("Create Custom Channel") {
                        showCreateChannel = true
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
    }
    
    private func channelGroupView(type: ChannelType, channels: [Channel]) -> some View {
        VStack(spacing: 0) {
            // Group Header
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(type.displayName.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(channels.count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .padding(.vertical, 12)
            
            VStack(spacing: 8) {
                ForEach(channels.sorted(by: { $0.name < $1.name })) { channel in
                    NavigationLink(destination: ChannelChatView(community: community, channel: channel)) {
                        EnhancedChannelRow(channel: channel, canManage: viewModel.canManageChannels) {
                            selectedChannel = channel
                            showChannelOptions = true
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}


// MARK: - Supporting Components


// MARK: - Enhanced Community Settings Sheet
// ADD this import at the top of your CommunityDetailView.swift file:
import PhotosUI


// MARK: - Shimmer Effect Extension
extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 300 : -300)
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}
