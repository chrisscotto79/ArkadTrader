//
//  CommunityDetailView.swift
//  ArkadTrader
//
//  ENHANCED VERSION - Beautiful Discord-like Community Interface
//

import SwiftUI

struct CommunityDetailView: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    @StateObject private var detailViewModel = EnhancedCommunityDetailViewModel()
    @State private var showMembersList = false
    @State private var showCommunitySettings = false
    @State private var showCreateChannel = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar
            enhancedNavigationBar
            
            // Community Header
            enhancedCommunityHeader
            
            // Quick Actions Bar
            quickActionsBar
            
            // Channels List
            enhancedChannelsList
            
            Spacer()
        }
        .background(
            LinearGradient(
                colors: [Color(.systemGroupedBackground), Color(.systemBackground).opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationBarHidden(true)
        .sheet(isPresented: $showMembersList) {
            CommunityMembersView(community: community)
        }
        .sheet(isPresented: $showCommunitySettings) {
            CommunitySettingsView(community: community)
        }
        .sheet(isPresented: $showCreateChannel) {
            CreateChannelView(community: community)
        }
        .onAppear {
            print("🏘️ === ENHANCED CommunityDetailView APPEARED ===")
            print("   Community: \(community.name)")
            print("   ID: \(community.id)")
            print("   Type: \(community.type.displayName)")
            print("   Members: \(community.memberCount)")
            print("   Private: \(community.isPrivate)")
            print("   Creator: \(community.createdBy)")
            print("🏘️ === CommunityDetailView LOADED SUCCESSFULLY ===")
            
            detailViewModel.loadCommunityData(community: community)
        }
    }
}

// MARK: - Enhanced Navigation Bar
extension CommunityDetailView {
    private var enhancedNavigationBar: some View {
        HStack {
            // Back Button with animation
            Button(action: {
                print("⬅️ Back button tapped in CommunityDetailView")
                dismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Communities")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            
            Spacer()
            
            // Community Name with icon
            HStack(spacing: 8) {
                Circle()
                    .fill(communityColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(getCommunityInitials())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                Text(community.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Settings Button
            Button(action: {
                print("⚙️ Settings tapped for: \(community.name)")
                showCommunitySettings = true
            }) {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .background(
                        Circle()
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 2)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
        )
    }
}

// MARK: - Enhanced Community Header
extension CommunityDetailView {
    private var enhancedCommunityHeader: some View {
        VStack(spacing: 20) {
            // Community Avatar with glow effect
            ZStack {
                Circle()
                    .fill(communityColor.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .blur(radius: 10)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [communityColor, communityColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Text(getCommunityInitials())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .shadow(color: communityColor.opacity(0.4), radius: 10, x: 0, y: 5)
            }
            
            // Community Info
            VStack(spacing: 12) {
                Text(community.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // Stats Row
                HStack(spacing: 24) {
                    statItem(icon: "person.3.fill", value: "\(community.memberCount)", label: "Members", color: .blue)
                    statItem(icon: "message.fill", value: "2", label: "Channels", color: .green)
                    statItem(icon: "crown.fill", value: detailViewModel.isUserAdmin ? "Admin" : "Member", label: "Role", color: .orange)
                }
                
                // Community Type & Privacy
                HStack(spacing: 12) {
                    // Type Badge
                    HStack(spacing: 6) {
                        Image(systemName: getTypeIcon())
                            .font(.caption)
                        Text(community.type.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(communityColor)
                            .shadow(color: communityColor.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                    
                    // Privacy Badge
                    if community.isPrivate {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                            Text("Private")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.15))
                        )
                    }
                }
            }
            
            // Description
            if !community.description.isEmpty {
                Text(community.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }
    
    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Quick Actions Bar
extension CommunityDetailView {
    private var quickActionsBar: some View {
        HStack(spacing: 16) {
            // View Members
            quickActionButton(
                icon: "person.3.fill",
                title: "Members",
                color: .blue
            ) {
                showMembersList = true
            }
            
            // Invite People (if admin)
            if detailViewModel.isUserAdmin {
                quickActionButton(
                    icon: "person.badge.plus",
                    title: "Invite",
                    color: .green
                ) {
                    print("📤 Invite people tapped")
                    // TODO: Show invite sheet
                }
            }
            
            // Notifications
            quickActionButton(
                icon: "bell.fill",
                title: "Notifications",
                color: .orange
            ) {
                print("🔔 Notifications tapped")
                // TODO: Show notification settings
            }
            
            Spacer()
            
            // Leave/Manage Community
            if detailViewModel.isUserAdmin {
                quickActionButton(
                    icon: "gear",
                    title: "Manage",
                    color: .gray
                ) {
                    showCommunitySettings = true
                }
            } else {
                quickActionButton(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Leave",
                    color: .red
                ) {
                    print("🚪 Leave community tapped")
                    // TODO: Show leave confirmation
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private func quickActionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: color.opacity(0.2), radius: 3, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced Channels List
extension CommunityDetailView {
    private var enhancedChannelsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "number.square.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    Text("CHANNELS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                
                Spacer()
                
                if detailViewModel.isUserAdmin {
                    Button(action: {
                        print("➕ Add channel tapped")
                        showCreateChannel = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .background(
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .blue.opacity(0.3), radius: 3)
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Channels
            VStack(spacing: 0) {
                // Default Channels
                enhancedChannelRow(
                    name: "general",
                    icon: "number",
                    color: .blue,
                    description: "General discussion for all members",
                    isAdminOnly: false,
                    unreadCount: 0
                )
                
                Divider()
                    .padding(.leading, 72)
                
                enhancedChannelRow(
                    name: "callouts",
                    icon: "megaphone",
                    color: .orange,
                    description: "Trading callouts and signals",
                    isAdminOnly: true,
                    unreadCount: 3
                )
                
                // Custom Channels (placeholder for future implementation)
                if detailViewModel.hasCustomChannels {
                    Divider()
                        .padding(.leading, 72)
                    
                    // Example custom channel
                    enhancedChannelRow(
                        name: "strategies",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .purple,
                        description: "Share and discuss trading strategies",
                        isAdminOnly: false,
                        unreadCount: 1
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal, 20)
        }
    }
    
    private func enhancedChannelRow(name: String, icon: String, color: Color, description: String, isAdminOnly: Bool, unreadCount: Int) -> some View {
        Button(action: {
            print("💬 Enhanced channel tapped: #\(name)")
            print("   Community: \(community.name)")
            print("   Admin only: \(isAdminOnly)")
            // TODO: Navigate to channel chat view
        }) {
            HStack(spacing: 16) {
                // Channel Icon with background
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                // Channel Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("#\(name)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if isAdminOnly {
                            Text("ADMIN")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.15))
                                )
                        }
                        
                        Spacer()
                        
                        // Unread count badge
                        if unreadCount > 0 {
                            Text("\(unreadCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.red)
                                )
                        }
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Helper Properties & Methods
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
    
    private func getTypeIcon() -> String {
        switch community.type {
        case .dayTrading: return "chart.line.uptrend.xyaxis"
        case .swingTrading: return "waveform.path"
        case .options: return "arrow.up.arrow.down.circle"
        case .crypto: return "bitcoinsign.circle"
        case .stocks: return "building.columns"
        case .general: return "person.3.fill"
        }
    }
}

// MARK: - Enhanced ViewModel
@MainActor
class EnhancedCommunityDetailViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isUserAdmin = false
    @Published var hasCustomChannels = false
    @Published var memberCount = 0
    
    private let authService = FirebaseAuthService.shared
    
    func loadCommunityData(community: Community) {
        print("🔄 EnhancedCommunityDetailViewModel: Loading data for \(community.name)")
        
        // Check if user is admin (community creator)
        if let userId = authService.currentUser?.id {
            isUserAdmin = (community.createdBy == userId)
            print("   User is admin: \(isUserAdmin)")
        }
        
        memberCount = community.memberCount
        
        // For demo purposes, show custom channels for some communities
        hasCustomChannels = community.memberCount > 5
        
        print("   Enhanced community data loaded")
    }
}

// MARK: - Placeholder Views for Sheets
struct CommunityMembersView: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Members of \(community.name)")
                    .font(.title)
                    .padding()
                
                Text("Coming soon - member list functionality")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") { dismiss() }
            )
        }
    }
}

struct CommunitySettingsView: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Settings for \(community.name)")
                    .font(.title)
                    .padding()
                
                Text("Coming soon - community settings")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") { dismiss() }
            )
        }
    }
}

struct CreateChannelView: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Create Channel in \(community.name)")
                    .font(.title)
                    .padding()
                
                Text("Coming soon - channel creation")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Create Channel")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Create") { dismiss() }
            )
        }
    }
}

#Preview {
    let testCommunity = Community(
        name: "Elite Day Traders",
        description: "A premium community for experienced day traders sharing strategies, live market analysis, and trading signals with real-time support.",
        type: .dayTrading,
        creatorId: "test-user",
        memberCount: 247,
        isPrivate: false
    )
    
    return NavigationView {
        CommunityDetailView(community: testCommunity)
    }
    .environmentObject(FirebaseAuthService.shared)
}
