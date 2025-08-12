// File: Core/Communities/Views/Detail/CommunityDetailView.swift
// Enhanced Modern UI/UX Version - Combined Implementation

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
    @State private var headerOffset: CGFloat = 0
    @State private var showJoinConfirmation = false
    @State private var animateEntry = false
    
    // UI Constants
    private let headerHeight: CGFloat = 260
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
        .sheet(isPresented: $showCommunitySettings) {
            EnhancedCommunitySettingsSheet(community: community)
        }
        .sheet(isPresented: $showCreateChannel) {
            CreateChannelSheet(community: community)
        }
        .confirmationDialog("Channel Options", isPresented: $showChannelOptions) {
            if let channel = selectedChannel {
                if viewModel.canManageChannels && !channel.isDefault {
                    Button("Edit Channel") {
                        // TODO: Implement edit channel
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
                    // TODO: Show channel info
                }
                
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    // MARK: - Helper Functions
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

    private func getCommunityTypeIcon() -> String {
        switch community.type {
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
            // Background with gradient overlay
            LinearGradient(
                colors: [
                    communityColor.opacity(0.9),
                    communityColor.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Pattern overlay
            GeometryReader { geometry in
                ForEach(0..<10, id: \.self) { _ in
                    Circle()
                        .fill(Color.white.opacity(0.03))
                        .frame(width: CGFloat.random(in: 50...150))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: 2)
                }
            }
            
            // Content
            VStack(spacing: 20) {
                Spacer()
                
                // Community Avatar
                communityAvatar
                    .scaleEffect(animateEntry ? 1 : 0.5)
                    .opacity(animateEntry ? 1 : 0)
                
                // Community Info
                VStack(spacing: 8) {
                    Text(community.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if !community.description.isEmpty {
                        Text(community.description)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 40)
                    }
                    
                    // Badges
                    HStack(spacing: 8) {
                        Label(community.type.displayName, systemImage: getCommunityTypeIcon())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(.white.opacity(0.2)))
                        
                        if community.isPrivate {
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
                    Text(getCommunityInitials())
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(communityColor)
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
                    Text(community.name)
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
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.blue.gradient)
                            )
                        }
                    }
                } else {
                    Button(action: {
                        if community.isPrivate {
                            showJoinConfirmation = true
                        } else {
                            viewModel.joinCommunity()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: community.isPrivate ? "lock.fill" : "person.badge.plus")
                            Text(community.isPrivate ? "Request to Join" : "Join Community")
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
                        .foregroundColor(.blue)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.blue.opacity(0.1))
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
                value: "\(community.memberCount)",
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
            
            statCard(
                value: "Active",
                label: "Status",
                icon: "chart.line.uptrend.xyaxis",
                color: .green,
                isLive: true
            )
        }
        .padding(.horizontal, 20)
        .opacity(animateEntry ? 1 : 0)
        .offset(y: animateEntry ? 0 : 20)
    }
    
    private func statCard(value: String, label: String, icon: String, color: Color, isLive: Bool = false) -> some View {
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
                HStack(spacing: 4) {
                    Text(value)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    if isLive {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .overlay(
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(2)
                                    .opacity(0)
                                    .animation(
                                        Animation.easeInOut(duration: 1.5)
                                            .repeatForever(autoreverses: false),
                                        value: isLive
                                    )
                            )
                    }
                }
                
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
                            .foregroundColor(.blue)
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
                    .foregroundColor(.blue)
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

// MARK: - Enhanced Channel Row Component
struct EnhancedChannelRow: View {
    let channel: Channel
    let canManage: Bool
    let onOptionsPress: () -> Void
    
    var body: some View {
        HStack {
            // Channel icon
            Image(systemName: channel.type.icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            // Channel info
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // Options button for managers
            if canManage {
                Button(action: onOptionsPress) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Supporting Components
struct CreateChannelSheet: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateChannelViewModel()
    
    @State private var channelName = ""
    @State private var channelDescription = ""
    @State private var selectedType: ChannelType = .text
    @State private var isAdminOnly = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Channel name", text: $channelName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Description (optional)", text: $channelDescription)
                }
                
                Section {
                    Picker("Channel Type", selection: $selectedType) {
                        ForEach(ChannelType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }
                
                Section {
                    Toggle("Admin-only posting", isOn: $isAdminOnly)
                }
                
                Section {
                    Button(action: createChannel) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Create Channel")
                                .bold()
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(channelName.isEmpty || viewModel.isLoading)
                }
            }
            .navigationTitle("New Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createChannel() {
        Task {
            do {
                let channel = Channel(
                    name: channelName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                    type: selectedType,
                    communityId: community.id,
                    isDefault: false,
                    adminOnly: isAdminOnly
                )
                
                try await viewModel.createChannel(channel)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

class CreateChannelViewModel: ObservableObject {
    @Published var isLoading = false
    private let firebaseService = FirebaseServices.shared
    
    func createChannel(_ channel: Channel) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await firebaseService.createChannel(channel)
        } catch {
            throw error
        }
    }
}

// MARK: - Enhanced Members List Sheet
struct EnhancedMembersListSheet: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MembersListViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                if !viewModel.members.isEmpty {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search members...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                
                // Members List
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading members...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredMembers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.4))
                        
                        VStack(spacing: 8) {
                            Text("No members found")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if searchText.isEmpty {
                                Text("This community doesn't have any members yet")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("No members match '\(searchText)'")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        if !viewModel.errorMessage.isEmpty {
                            Button("Retry") {
                                Task {
                                    await viewModel.loadMembers(for: community)
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredMembers) { member in
                                MembersListRow(member: member, community: community)
                                
                                if member.id != filteredMembers.last?.id {
                                    Divider()
                                        .padding(.leading, 72)
                                }
                            }
                        }
                        .padding(.top, 16)
                    }
                }
                
                // Error Message
                if !viewModel.errorMessage.isEmpty {
                    VStack(spacing: 12) {
                        Text(viewModel.errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            Task {
                                await viewModel.loadMembers(for: community)
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Members (\(viewModel.members.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if viewModel.members.isEmpty {
                Task {
                    await viewModel.loadMembers(for: community)
                }
            }
        }
    }
    
    private var filteredMembers: [CommunityMemberWithRole] {
        if searchText.isEmpty {
            return viewModel.members.sorted { (member1: CommunityMemberWithRole, member2: CommunityMemberWithRole) in
                // Sort by role priority first, then by name
                if member1.role.rawValue != member2.role.rawValue {
                    return getRolePriority(member1.role) > getRolePriority(member2.role)
                }
                return member1.fullName < member2.fullName
            }
        } else {
            return viewModel.members.filter { (member: CommunityMemberWithRole) in
                member.fullName.localizedCaseInsensitiveContains(searchText) ||
                member.username.localizedCaseInsensitiveContains(searchText)
            }.sorted { (member1: CommunityMemberWithRole, member2: CommunityMemberWithRole) in
                if member1.role.rawValue != member2.role.rawValue {
                    return getRolePriority(member1.role) > getRolePriority(member2.role)
                }
                return member1.fullName < member2.fullName
            }
        }
    }
    
    private func getRolePriority(_ role: CommunityRole) -> Int {
        switch role {
        case .owner: return 4
        case .admin: return 3
        case .moderator: return 2
        case .member: return 1
        }
    }
    
}

// MARK: - Members List Row Component
struct MembersListRow: View {
    let member: CommunityMemberWithRole
    let community: Community
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(getRoleColor(member.role).gradient)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(getInitials(from: member.fullName))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // Member Info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(member.fullName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if member.role == .owner {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                HStack(spacing: 12) {
                    Label(member.role.rawValue.capitalized, systemImage: getRoleIcon(member.role))
                        .font(.subheadline)
                        .foregroundColor(getRoleColor(member.role))
                    
                    Text("@\(member.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if member.joinedAt != nil {
                    Text("Joined \(member.joinedAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status Indicator
            VStack(spacing: 4) {
                Circle()
                    .fill(member.isOnline ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                Text(member.isOnline ? "Online" : "Offline")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private func getInitials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1))
            let last = String(components[1].prefix(1))
            return (first + last).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    private func getRoleColor(_ role: CommunityRole) -> Color {
        switch role {
        case .owner: return .purple
        case .admin: return .orange
        case .moderator: return .blue
        case .member: return .green
        }
    }
    
    private func getRoleIcon(_ role: CommunityRole) -> String {
        switch role {
        case .owner: return "crown.fill"
        case .admin: return "shield.fill"
        case .moderator: return "star.fill"
        case .member: return "person.fill"
        }
    }
}

// MARK: - Members List ViewModel
class MembersListViewModel: ObservableObject {
    @Published var members: [CommunityMemberWithRole] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let firebaseService = FirebaseServices.shared
    
    func loadMembers(for community: Community) async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            let loadedMembers = try await firebaseService.getCommunityMembers(communityId: community.id)
            
            await MainActor.run {
                // Sort members by role priority and then by name
                
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load members: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

// MARK: - Enhanced Community Settings Sheet
struct EnhancedCommunitySettingsSheet: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CommunitySettingsViewModel
    @State private var showingDeleteAlert = false
    
    init(community: Community) {
        self.community = community
        self._viewModel = StateObject(wrappedValue: CommunitySettingsViewModel(community: community))
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Community Info Section
                Section {
                    HStack {
                        Circle()
                            .fill(getCommunityColor())
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text(getCommunityInitials())
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(community.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text(community.type.displayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.isOwner {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Community Rules Section
                Section("Community Rules & Guidelines") {
                    if viewModel.isLoadingRules {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading rules...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if viewModel.communityRules.isEmpty {
                        VStack(spacing: 8) {
                            Text("No community rules set")
                                .foregroundColor(.secondary)
                            
                            if viewModel.isOwner {
                                Button("Create Default Trading Rules") {
                                    Task {
                                        await viewModel.loadCommunityRules()
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(viewModel.communityRules) { rule in
                            CommunityRuleRow(
                                rule: rule,
                                isOwner: viewModel.isOwner,
                                onDelete: {
                                    Task {
                                        await viewModel.deleteRule(rule)
                                    }
                                }
                            )
                        }
                        
                        if viewModel.isOwner {
                            Button("Add Custom Rule") {
                                viewModel.showingAddRule = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                // Basic Settings (Only for owners)
                if viewModel.isOwner {
                    Section("Community Settings") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Community Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("Enter community name", text: $viewModel.settings.name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("Enter community description", text: $viewModel.settings.description, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...6)
                        }
                        
                        Toggle("Private Community", isOn: $viewModel.settings.isPrivate)
                    }
                    
                    // Save Button
                    Section {
                        Button(action: {
                            Task {
                                await viewModel.updateCommunity()
                                if viewModel.errorMessage.isEmpty {
                                    dismiss()
                                }
                            }
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Save Changes")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(viewModel.canSave ? .white : .gray)
                        }
                        .disabled(!viewModel.canSave || viewModel.isLoading)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.canSave ? Color.blue : Color.gray.opacity(0.3))
                        )
                    }
                    
                    // Danger Zone
                    Section("Danger Zone") {
                        Button(role: .destructive, action: {
                            showingDeleteAlert = true
                        }) {
                            Label("Delete Community", systemImage: "trash")
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                
                // Member Management Section (For owners)
                if viewModel.isOwner {
                    Section("Members (\(viewModel.members.count))") {
                        if viewModel.isLoadingMembers {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading members...")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        } else if viewModel.members.isEmpty {
                            VStack(spacing: 8) {
                                Text("No members found")
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                                
                                Button("Reload Members") {
                                    Task {
                                        await viewModel.loadMembers()
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                        } else {
                            ForEach(viewModel.members) { member in
                                MemberRow(
                                    member: member,
                                    isOwner: viewModel.isOwner,
                                    onRoleChange: { newRole in
                                        Task {
                                            await viewModel.updateMemberRole(member, to: newRole)
                                        }
                                    },
                                    onRemove: {
                                        viewModel.selectedMemberForRemoval = member
                                    }
                                )
                            }
                        }
                    }
                } else {
                    // Non-owner view
                    Section("Community Info") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("You can view community information but only the owner can modify settings.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(community.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Privacy")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(community.isPrivate ? "Private" : "Public")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Error Display
                if !viewModel.errorMessage.isEmpty {
                    Section {
                        Text(viewModel.errorMessage)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Community Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if viewModel.hasChanges {
                            viewModel.resetSettings()
                        }
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .disabled(viewModel.isLoading)
                }
            }
            .alert("Delete Community", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteCommunity()
                        if viewModel.errorMessage.isEmpty {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(community.name)\"? This action cannot be undone and will remove all channels and messages.")
            }
            .alert("Remove Member",
                   isPresented: .constant(viewModel.selectedMemberForRemoval != nil),
                   presenting: viewModel.selectedMemberForRemoval) { member in
                Button("Cancel", role: .cancel) {
                    viewModel.selectedMemberForRemoval = nil
                }
                Button("Remove", role: .destructive) {
                    Task {
                        await viewModel.removeMember(member)
                        viewModel.selectedMemberForRemoval = nil
                    }
                }
            } message: { member in
                Text("Are you sure you want to remove \(member.fullName) from the community?")
            }
        }
        .onAppear {
            // Automatically load members when the settings view appears
            if viewModel.isOwner && viewModel.members.isEmpty {
                Task {
                    await viewModel.loadMembers()
                }
            }
            
            // Also load community rules
            if viewModel.communityRules.isEmpty {
                Task {
                    await viewModel.loadCommunityRules()
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddRule) {
            AddCustomRuleSheet { title, description, isRequired in
                Task {
                    await viewModel.addCustomRule(title: title, description: description, isRequired: isRequired)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getCommunityColor() -> Color {
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

// MARK: - Member Row Component
struct MemberRow: View {
    let member: CommunityMemberWithRole
    let isOwner: Bool
    let onRoleChange: (CommunityRole) -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(getRoleColor(member.role).gradient)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(getInitials(from: member.fullName))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            // Member Info
            VStack(alignment: .leading, spacing: 4) {
                Text(member.fullName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 8) {
                    Label(member.role.rawValue.capitalized, systemImage: getRoleIcon(member.role))
                        .font(.caption)
                        .foregroundColor(getRoleColor(member.role))
                    
                    Text("@\(member.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Actions (only for non-owners)
            if member.role != .owner && isOwner {
                Menu {
                    // Role change options
                    ForEach(getAllRoles().filter { $0 != .owner && $0 != member.role }, id: \.self) { role in
                        Button(action: {
                            onRoleChange(role)
                        }) {
                            Label("Make \(role.rawValue.capitalized)", systemImage: getRoleIcon(role))
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove Member", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                }
            } else if member.role == .owner {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func getInitials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1))
            let last = String(components[1].prefix(1))
            return (first + last).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    private func getRoleColor(_ role: CommunityRole) -> Color {
        switch role {
        case .owner: return .purple
        case .admin: return .orange
        case .moderator: return .blue
        case .member: return .green
        }
    }
    
    private func getRoleIcon(_ role: CommunityRole) -> String {
        switch role {
        case .owner: return "crown.fill"
        case .admin: return "shield.fill"
        case .moderator: return "star.fill"
        case .member: return "person.fill"
        }
    }
    
    private func getAllRoles() -> [CommunityRole] {
        return [.owner, .admin, .moderator, .member]
    }
}

// MARK: - Community Rule Row Component
struct CommunityRuleRow: View {
    let rule: CommunityRule
    let isOwner: Bool
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(rule.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if rule.isRequired {
                    Text("REQUIRED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(6)
                }
                
                if !rule.isDefault && isOwner {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            
            Text(rule.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Custom Rule Sheet
struct AddCustomRuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var isRequired = true
    
    let onSave: (String, String, Bool) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rule Details") {
                    TextField("Rule Title", text: $title)
                    TextField("Rule Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    Toggle("Required for all members", isOn: $isRequired)
                }
            }
            .navigationTitle("Add Custom Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(title, description, isRequired)
                        dismiss()
                    }
                    .disabled(title.isEmpty || description.isEmpty)
                }
            }
        }
    }
}
