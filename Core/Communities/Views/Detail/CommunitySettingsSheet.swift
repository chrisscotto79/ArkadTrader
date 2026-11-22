// File: Core/Communities/Views/Detail/CommunitySettingsSheet.swift
// Community settings sheet for owners and admins, including custom rules.

import SwiftUI
import PhotosUI

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
                                .foregroundColor(.accentColor)
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
                            .foregroundColor(.accentColor)
                        }
                    }
                }
                
                // Basic Settings (Only for owners)
                if viewModel.isOwner {
                    Section {
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
                    } header: {
                        Text("Community Settings")
                    } footer: {
                        Text("Private communities are hidden from Discover and search for anyone who isn't a member.")
                    }
                    
                    // Community Images Section
                    Section("Community Images") {
                        // Avatar/Profile Image
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Community Avatar")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 16) {
                                // Current avatar display
                                ZStack {
                                    Circle()
                                        .fill(getCommunityColor().opacity(0.1))
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(getCommunityColor().opacity(0.3), lineWidth: 2)
                                        )
                                    
                                    // Display current avatar or initials
                                    if let avatarURL = viewModel.settings.avatarURL {
                                        AsyncImage(url: URL(string: avatarURL)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 76, height: 76)
                                                .clipShape(Circle())
                                        } placeholder: {
                                            // Show initials while loading
                                            Text(getCommunityInitials())
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(getCommunityColor())
                                        }
                                    } else if let avatarImage = viewModel.avatarImage {
                                        Image(uiImage: avatarImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 76, height: 76)
                                            .clipShape(Circle())
                                    } else {
                                        Text(getCommunityInitials())
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(getCommunityColor())
                                    }
                                    
                                    // Upload progress overlay
                                    if viewModel.isUploadingAvatar {
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                ProgressView(value: viewModel.avatarUploadProgress)
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(1.2)
                                            )
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Choose a square image for your community avatar. Recommended size: 512x512px")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    HStack(spacing: 8) {
                                        // Photo picker for avatar
                                        PhotosPicker(
                                            selection: $viewModel.selectedAvatarItem,
                                            matching: .images,
                                            photoLibrary: .shared()
                                        ) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "photo")
                                                    .font(.caption)
                                                Text("Choose Image")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                            .foregroundColor(.accentColor)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color.accentColor.opacity(0.1))
                                            )
                                        }
                                        .disabled(viewModel.isUploadingAvatar)
                                        
                                        // Remove avatar button
                                        if viewModel.hasAvatarImage {
                                            Button(action: {
                                                Task {
                                                    await viewModel.removeAvatar()
                                                }
                                            }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "trash")
                                                        .font(.caption)
                                                    Text("Remove")
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                }
                                                .foregroundColor(.red)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.red.opacity(0.1))
                                                )
                                            }
                                            .disabled(viewModel.isLoading)
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        
                        // Divider
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Banner Image
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Community Banner")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            VStack(spacing: 12) {
                                // Current banner display
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(getCommunityColor().opacity(0.1))
                                        .frame(height: 120)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(getCommunityColor().opacity(0.3), lineWidth: 1)
                                        )
                                    
                                    // Display current banner or gradient
                                    if let bannerURL = viewModel.settings.bannerURL {
                                        AsyncImage(url: URL(string: bannerURL)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(height: 120)
                                                .clipped()
                                                .cornerRadius(12)
                                        } placeholder: {
                                            // Show gradient while loading
                                            LinearGradient(
                                                colors: [getCommunityColor(), getCommunityColor().opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                            .frame(height: 120)
                                            .cornerRadius(12)
                                        }
                                    } else if let bannerImage = viewModel.bannerImage {
                                        Image(uiImage: bannerImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 120)
                                            .clipped()
                                            .cornerRadius(12)
                                    } else {
                                        LinearGradient(
                                            colors: [getCommunityColor(), getCommunityColor().opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        .frame(height: 120)
                                        .cornerRadius(12)
                                        .overlay(
                                            VStack(spacing: 4) {
                                                Image(systemName: "photo.badge.plus")
                                                    .font(.title2)
                                                    .foregroundColor(.white.opacity(0.8))
                                                
                                                Text("Add Banner")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.white.opacity(0.8))
                                            }
                                        )
                                    }
                                    
                                    // Upload progress overlay
                                    if viewModel.isUploadingBanner {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.black.opacity(0.6))
                                            .frame(height: 120)
                                            .overlay(
                                                VStack(spacing: 8) {
                                                    ProgressView(value: viewModel.bannerUploadProgress)
                                                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                                        .frame(width: 100)
                                                    
                                                    Text("\(Int(viewModel.bannerUploadProgress * 100))%")
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.white)
                                                }
                                            )
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Choose a wide image for your community banner. Recommended size: 1200x400px (3:1 ratio)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    HStack(spacing: 8) {
                                        // Photo picker for banner
                                        PhotosPicker(
                                            selection: $viewModel.selectedBannerItem,
                                            matching: .images,
                                            photoLibrary: .shared()
                                        ) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "photo.on.rectangle")
                                                    .font(.caption)
                                                Text("Choose Banner")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                            .foregroundColor(.accentColor)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color.accentColor.opacity(0.1))
                                            )
                                        }
                                        .disabled(viewModel.isUploadingBanner)
                                        
                                        // Remove banner button
                                        if viewModel.hasBannerImage {
                                            Button(action: {
                                                Task {
                                                    await viewModel.removeBanner()
                                                }
                                            }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "trash")
                                                        .font(.caption)
                                                    Text("Remove")
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                }
                                                .foregroundColor(.red)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.red.opacity(0.1))
                                                )
                                            }
                                            .disabled(viewModel.isLoading)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                            }
                        }
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
                            .foregroundColor(viewModel.canSave ? .black : .gray)
                        }
                        .disabled(!viewModel.canSave || viewModel.isLoading)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.canSave ? Color.arkadGold : Color.gray.opacity(0.3))
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
                                .foregroundColor(.accentColor)
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
        community.type.tint
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
