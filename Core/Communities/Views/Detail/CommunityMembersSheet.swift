// File: Core/Communities/Views/Detail/CommunityMembersSheet.swift
// Community member list sheet, its rows and view model.

import SwiftUI
import PhotosUI

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
                            .foregroundColor(.accentColor)
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
                        .foregroundColor(.accentColor)
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
                
                // Removed unnecessary nil check since joinedAt is non-optional
                Text("Joined \(member.joinedAt, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
            let loadedMembers = try await CommunityFirebaseService.shared.getCommunityMembersWithRoles(communityId: community.id)
            
            await MainActor.run {
                // Sort members by role priority and then by name
                self.members = self.sortMembers(loadedMembers)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load members: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func sortMembers(_ members: [CommunityMemberWithRole]) -> [CommunityMemberWithRole] {
        return members.sorted { member1, member2 in
            // First sort by role priority (owner -> admin -> moderator -> member)
            let role1Priority = getRolePriority(member1.role)
            let role2Priority = getRolePriority(member2.role)
            
            if role1Priority != role2Priority {
                return role1Priority < role2Priority
            }
            
            // Then sort by name alphabetically
            return member1.fullName.localizedCaseInsensitiveCompare(member2.fullName) == .orderedAscending
        }
    }
    
    private func getRolePriority(_ role: CommunityRole) -> Int {
        switch role {
        case .owner: return 0
        case .admin: return 1
        case .moderator: return 2
        case .member: return 3
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
