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
                systemName: channel.displayIcon,
                tint: channel.displayTint,
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
/// The "Announcements" preset is an admin-only text channel with a megaphone icon.
struct CreateChannelSheet: View {
    let community: Community
    var editing: Channel?
    /// The community's channels, so a name can't be used twice
    var existingChannels: [Channel] = []
    @Environment(\.dismiss) private var dismiss

    @State private var channelName = ""
    @State private var preset: Preset = .text
    @State private var isAdminOnly = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    /// What the Type picker offers: the two channel types, plus Announcements.
    private enum Preset: String, CaseIterable, Identifiable {
        case text, callouts, announcements

        var id: String { rawValue }

        var title: String {
            switch self {
            case .text: return ChannelType.text.displayName
            case .callouts: return ChannelType.callouts.displayName
            case .announcements: return "Announcements"
            }
        }

        var icon: String {
            switch self {
            case .text: return ChannelType.text.icon
            case .callouts: return ChannelType.callouts.icon
            case .announcements: return "megaphone"
            }
        }

        var channelType: ChannelType { self == .callouts ? .callouts : .text }

        init(channel: Channel) {
            if channel.type == .callouts {
                self = .callouts
            } else {
                self = channel.isAnnouncements ? .announcements : .text
            }
        }
    }

    private var cleanedName: String {
        channelName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "#", with: "")
    }

    /// Why the name can't be used, or nil when it's fine (an empty name just disables Create)
    private var nameProblem: String? {
        let name = cleanedName
        guard !name.isEmpty else { return nil }
        if name.count < 2 { return "Use at least 2 characters." }
        if name.count > 50 { return "Use 50 characters or fewer." }
        let allowed = CharacterSet.lowercaseLetters.union(.decimalDigits).union(CharacterSet(charactersIn: "-_"))
        if name.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return "Use letters, numbers, hyphens and underscores."
        }
        if existingChannels.contains(where: { $0.name == name && $0.id != editing?.id }) {
            return "There's already a #\(name)."
        }
        return nil
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
                    if let nameProblem {
                        Text(nameProblem)
                            .font(.footnote)
                            .foregroundStyle(Color.marketRed)
                    }
                    Picker("Type", selection: $preset) {
                        ForEach(Preset.allCases) { option in
                            Label(option.title, systemImage: option.icon).tag(option)
                        }
                    }
                }
                .listRowBackground(Color.surface)

                Section {
                    Toggle("Only admins can post", isOn: $isAdminOnly)
                        .disabled(preset == .announcements)
                } footer: {
                    Text(preset == .announcements
                         ? "Only owners and admins post announcements. Members can read and react."
                         : "Members can still read and react. Use this for announcements and trade callouts.")
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
                            .disabled(cleanedName.isEmpty || nameProblem != nil)
                    }
                }
            }
            .onAppear {
                guard let editing else { return }
                channelName = editing.name
                // Legacy voice channels are edited (and saved) as text channels
                preset = Preset(channel: editing)
                isAdminOnly = editing.adminOnly
            }
            .onChange(of: preset) { oldValue, newValue in
                if newValue == .announcements {
                    isAdminOnly = true
                    if channelName.trimmingCharacters(in: .whitespaces).isEmpty { channelName = "announcements" }
                } else if oldValue == .announcements, cleanedName == "announcements", editing == nil {
                    channelName = ""
                }
            }
        }
    }

    /// The icon to store: the megaphone for Announcements, the type's own icon otherwise.
    private var iconForSave: String? {
        preset == .announcements ? Channel.announcementsIcon : nil
    }

    private func save() {
        guard !cleanedName.isEmpty, nameProblem == nil else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let adminOnly = preset == .announcements ? true : isAdminOnly
                if var channel = editing {
                    channel.name = cleanedName
                    channel.type = preset.channelType
                    channel.adminOnly = adminOnly
                    channel.icon = iconForSave
                    try await FirebaseServices.shared.updateChannel(channel)
                } else {
                    var channel = Channel(
                        name: cleanedName,
                        type: preset.channelType,
                        communityId: community.id,
                        isDefault: false,
                        adminOnly: adminOnly
                    )
                    channel.icon = iconForSave
                    try await FirebaseServices.shared.createChannel(channel)
                }
                dismiss()
            } catch {
                errorMessage = "Couldn't save the channel. Check your connection and try again."
                isSaving = false
            }
        }
    }
}
