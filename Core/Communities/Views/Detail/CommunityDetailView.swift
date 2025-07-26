// File: Core/Communities/Views/Detail/CommunityDetailView.swift
// ENHANCED VERSION - Professional UI with Channel Management

import SwiftUI

struct CommunityDetailView: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CommunityDetailViewModel()
    @State private var showMembersList = false
    @State private var showCommunitySettings = false
    @State private var showCreateChannel = false
    @State private var selectedChannel: Channel?
    @State private var showChannelOptions = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Enhanced Navigation Header
                enhancedNavigationHeader
                
                // Community Info Card
                enhancedCommunityInfoCard
                
                // Action Buttons Section
                enhancedActionButtons
                
                // Quick Stats Bar
                quickStatsBar
                
                // Enhanced Channels Section
                enhancedChannelsSection
            }
        }
        .background(
            LinearGradient(
                colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadCommunityData(community: community)
        }
        .sheet(isPresented: $showMembersList) {
            EnhancedMembersListSheet(community: community)
        }
        .sheet(isPresented: $showCommunitySettings) {
            EnhancedCommunitySettingsSheet(community: community)
        }
        .sheet(isPresented: $showCreateChannel) {
            CreateChannelSheet(community: community) {
                // Refresh channels after creation
                Task {
                    viewModel.refreshChannels()
                }
            }
        }
        .confirmationDialog("Channel Options", isPresented: $showChannelOptions, presenting: selectedChannel) { channel in
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

// MARK: - Enhanced Navigation Header
extension CommunityDetailView {
    private var enhancedNavigationHeader: some View {
        HStack {
            // Back Button
            Button(action: { dismiss() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            // Community Name
            Text(community.name)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(1)
            
            Spacer()
            
            // Settings Menu
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
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Enhanced Community Info Card
extension CommunityDetailView {
    private var enhancedCommunityInfoCard: some View {
        VStack(spacing: 24) {
            // Community Avatar with Status
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [communityColor, communityColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: communityColor.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Text(getCommunityInitials())
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Online indicator (if applicable)
                if viewModel.isUserMember {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: 30, y: 30)
                }
            }
            
            // Community Details
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text(community.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    if !community.description.isEmpty {
                        Text(community.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .padding(.horizontal, 8)
                    }
                }
                
                // Enhanced Badges
                HStack(spacing: 8) {
                    // Type Badge
                    Label(community.type.displayName, systemImage: getCommunityTypeIcon())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(communityColor)
                        .cornerRadius(12)
                    
                    // Privacy Badge
                    if community.isPrivate {
                        Label("Private", systemImage: "lock.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(12)
                    }
                    
                    // User Role Badge
                    if viewModel.isUserMember {
                        Text(viewModel.userRole.capitalized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(getRoleColor())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(getRoleColor().opacity(0.15))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
}

// MARK: - Enhanced Action Buttons
extension CommunityDetailView {
    private var enhancedActionButtons: some View {
        HStack(spacing: 12) {
            // Primary Action Button
            if viewModel.isUserMember {
                if viewModel.userRole == "owner" {
                    Button(action: { showCommunitySettings = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                            Text("Manage Community")
                        }
                    }
                    .buttonStyle(EnhancedPrimaryButtonStyle(color: .blue))
                } else {
                    Button(action: {
                        // Add confirmation dialog for leaving
                        viewModel.leaveCommunity()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "door.right.hand.open")
                            Text("Leave Community")
                        }
                    }
                    .buttonStyle(EnhancedPrimaryButtonStyle(color: .red))
                }
            } else {
                Button(action: { viewModel.joinCommunity() }) {
                    HStack(spacing: 8) {
                        Image(systemName: community.isPrivate ? "lock.fill" : "person.badge.plus")
                        Text(community.isPrivate ? "Request to Join" : "Join Community")
                    }
                }
                .buttonStyle(EnhancedPrimaryButtonStyle(color: communityColor))
            }
            
            // Secondary Actions
            Button(action: { showMembersList = true }) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(width: 48, height: 48)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(14)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

// MARK: - Quick Stats Bar
extension CommunityDetailView {
    private var quickStatsBar: some View {
        HStack {
            // Members Stat
            VStack(spacing: 4) {
                Text("\(community.memberCount)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 40)
            
            // Channels Stat
            VStack(spacing: 4) {
                Text("\(viewModel.channels.count)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Channels")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 40)
            
            // Activity Stat
            VStack(spacing: 4) {
                Text("Active")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text("Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

// MARK: - Enhanced Channels Section
extension CommunityDetailView {
    private var enhancedChannelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enhanced Section Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "number.square.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    Text("CHANNELS")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Channel count badge
                    Text("\(viewModel.channels.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(10)
                    
                    // Create Channel Button
                    if viewModel.canManageChannels {
                        Button(action: { showCreateChannel = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // Channels List
            LazyVStack(spacing: 0) {
                if viewModel.isLoading {
                    channelLoadingView
                } else if viewModel.channels.isEmpty {
                    enhancedEmptyChannelsView
                } else {
                    // Group channels by type
                    let groupedChannels = Dictionary(grouping: viewModel.channels) { $0.type }
                    let sortedTypes: [ChannelType] = [.text, .callouts, .voice]
                    
                    ForEach(sortedTypes, id: \.self) { channelType in
                        if let channels = groupedChannels[channelType], !channels.isEmpty {
                            channelGroupSection(type: channelType, channels: channels)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }
    
    private func channelGroupSection(type: ChannelType, channels: [Channel]) -> some View {
        VStack(spacing: 0) {
            // Group Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: type.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(type.displayName.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(channels.count)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Channels in Group
            ForEach(channels.sorted(by: { $0.name < $1.name })) { channel in
                NavigationLink(destination: ChannelChatView(community: community, channel: channel)) {
                    EnhancedChannelRow(channel: channel, canManage: viewModel.canManageChannels) {
                        selectedChannel = channel
                        showChannelOptions = true
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                if channel.id != channels.last?.id {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
    }
    
    private var channelLoadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.9)
            Text("Loading channels...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var enhancedEmptyChannelsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "number.square.dashed")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No channels yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Channels help organize conversations by topic")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            if viewModel.canManageChannels {
                VStack(spacing: 12) {
                    Button("Create Default Channels") {
                        Task {
                            await viewModel.setupDefaultChannels()
                        }
                    }
                    .buttonStyle(EnhancedPrimaryButtonStyle(color: communityColor))
                    
                    Button("Create Custom Channel") {
                        showCreateChannel = true
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 50)
    }
}

// MARK: - Enhanced Channel Row Component
struct EnhancedChannelRow: View {
    let channel: Channel
    let canManage: Bool
    let onOptionsPressed: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Channel Icon
            ZStack {
                Circle()
                    .fill(channelColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: channelIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(channelColor)
            }
            
            // Channel Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("#\(channel.name)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if channel.adminOnly {
                        Text("ADMIN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(6)
                    }
                    
                    if channel.isDefault {
                        Text("DEFAULT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(6)
                    }
                    
                    Spacer()
                }
                
                Text(channelDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Options & Arrow
            HStack(spacing: 8) {
                if canManage && !channel.isDefault {
                    Button(action: onOptionsPressed) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
        case .callouts: return "megaphone.fill"
        case .voice: return "speaker.wave.2.fill"
        }
    }
    
    private var channelDescription: String {
        switch channel.type {
        case .text:
            return channel.adminOnly ? "Admin-only discussion channel" : "General discussion and chat"
        case .callouts:
            return "Trading signals, callouts, and market alerts"
        case .voice:
            return "Voice chat and live discussions"
        }
    }
}

// MARK: - Enhanced Button Styles
struct EnhancedPrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: color.opacity(0.3), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
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
    
    private func getCommunityTypeIcon() -> String {
        switch community.type {
        case .dayTrading: return "chart.line.uptrend.xyaxis"
        case .swingTrading: return "chart.bar"
        case .options: return "function"
        case .crypto: return "bitcoinsign.circle"
        case .stocks: return "building.columns"
        case .general: return "person.3"
        }
    }
    
    private func getRoleColor() -> Color {
        switch viewModel.userRole.lowercased() {
        case "owner": return .purple
        case "admin": return .orange
        case "moderator": return .blue
        default: return .green
        }
    }
}

// MARK: - Enhanced Sheet Views
struct EnhancedMembersListSheet: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MembersListViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                // Header Stats
                HStack(spacing: 30) {
                    VStack {
                        Text("\(community.memberCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Total Members")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("12")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Online")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 20)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search members...", text: .constant(""))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                
                // Members List Placeholder
                List {
                    Text("Member management coming soon")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowSeparator(.hidden)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct EnhancedCommunitySettingsSheet: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Circle()
                            .fill(Color.blue)
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
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Community Management") {
                    NavigationLink(destination: Text("Edit Community")) {
                        Label("Edit Community", systemImage: "pencil")
                    }
                    
                    NavigationLink(destination: Text("Manage Channels")) {
                        Label("Manage Channels", systemImage: "number.square")
                    }
                    
                    NavigationLink(destination: Text("Member Management")) {
                        Label("Manage Members", systemImage: "person.3")
                    }
                    
                    NavigationLink(destination: Text("Community Rules")) {
                        Label("Community Rules", systemImage: "list.bullet")
                    }
                }
                
                Section("Settings") {
                    NavigationLink(destination: Text("Notifications")) {
                        Label("Notifications", systemImage: "bell")
                    }
                    
                    NavigationLink(destination: Text("Privacy")) {
                        Label("Privacy Settings", systemImage: "lock")
                    }
                }
                
                Section("Danger Zone") {
                    Button(role: .destructive, action: {}) {
                        Label("Delete Community", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Community Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
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

struct CreateChannelSheet: View {
    let community: Community
    let onChannelCreated: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var channelName = ""
    @State private var channelType: ChannelType = .text
    @State private var isAdminOnly = false
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Channel Details")) {
                    HStack {
                        Text("#")
                            .foregroundColor(.secondary)
                        TextField("channel-name", text: $channelName)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Picker("Channel Type", selection: $channelType) {
                        ForEach(ChannelType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    
                    Toggle("Admin Only", isOn: $isAdminOnly)
                }
                
                Section(footer: Text("Choose a short, memorable name for your channel. Use lowercase letters, numbers, and hyphens.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Create Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createChannel()
                    }
                    .disabled(channelName.isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createChannel() {
        isCreating = true
        
        let channel = Channel(
            name: channelName.lowercased().replacingOccurrences(of: " ", with: "-"),
            type: channelType,
            communityId: community.id,
            adminOnly: isAdminOnly
        )
        
        Task {
            do {
                try await FirebaseServices.shared.createChannel(channel)
                await MainActor.run {
                    onChannelCreated()
                    dismiss()
                }
            } catch {
                print("Error creating channel: \(error)")
                isCreating = false
            }
        }
    }
}

// MARK: - Supporting ViewModels
@MainActor
class MembersListViewModel: ObservableObject {
    @Published var members: [User] = []
    @Published var isLoading = false
    
    // Placeholder for member management
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
