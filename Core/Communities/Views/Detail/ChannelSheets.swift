// File: Core/Communities/Views/Detail/ChannelSheets.swift
// Channel list row and the create/edit channel sheet.

import SwiftUI
import PhotosUI

// MARK: - Channel Row
/// One channel in the community's channel list. Sits inside a card list.
struct EnhancedChannelRow: View {
    let channel: Channel
    let canManage: Bool
    let onOptionsPress: () -> Void
    
    private var isCallouts: Bool { channel.type == .callouts }

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(
                systemName: isCallouts ? "megaphone.fill" : "number",
                tint: isCallouts ? .goldText : .secondary,
                size: 36
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: DS.Spacing.s)

            if channel.adminOnly {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Admins only")
            }
            
            if canManage {
                Button(action: onOptionsPress) {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Options for #\(channel.name)")
            } else {
                CommunityChevron()
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        if isCallouts {
            return channel.adminOnly ? "Trade callouts from admins" : "Trade callouts"
        }
        return channel.adminOnly ? "Announcements from admins" : "Open to every member"
    }
}

/// Creates a new channel, or edits an existing one when `editing` is set.
struct CreateChannelSheet: View {
    let community: Community
    var editing: Channel?
    @Environment(\.dismiss) private var dismiss

    @State private var channelName = ""
    @State private var selectedType: ChannelType = .text
    @State private var isAdminOnly = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var cleanedName: String {
        channelName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "#", with: "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 4) {
                        Text("#").foregroundStyle(.secondary)
                        TextField("channel-name", text: $channelName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Picker("Type", selection: $selectedType) {
                        ForEach(ChannelType.selectableTypes, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                }
                .listRowBackground(Color.surface)

                Section {
                    Toggle("Only admins can post", isOn: $isAdminOnly)
                } footer: {
                    Text("Members can still read and react. Use this for announcements and trade callouts.")
                }
                .listRowBackground(Color.surface)

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.footnote).foregroundStyle(Color.marketRed)
                    }
                    .listRowBackground(Color.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .tint(Color.goldText)
            .navigationTitle(editing == nil ? "New Channel" : "Edit Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(editing == nil ? "Create" : "Save", action: save)
                            .fontWeight(.semibold)
                            .disabled(cleanedName.isEmpty)
                    }
                }
            }
            .onAppear {
                guard let editing else { return }
                channelName = editing.name
                // Legacy voice channels are edited (and saved) as text channels
                selectedType = editing.type == .voice ? .text : editing.type
                isAdminOnly = editing.adminOnly
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                if var channel = editing {
                    channel.name = cleanedName
                    channel.type = selectedType
                    channel.adminOnly = isAdminOnly
                    try await FirebaseServices.shared.updateChannel(channel)
                } else {
                    let channel = Channel(
                        name: cleanedName,
                        type: selectedType,
                        communityId: community.id,
                        isDefault: false,
                        adminOnly: isAdminOnly
                    )
                    try await FirebaseServices.shared.createChannel(channel)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
