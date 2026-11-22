// File: Core/Communities/Views/Detail/ChannelSheets.swift
// Channel list row and the create/edit channel sheet.

import SwiftUI
import PhotosUI

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
                        Text("#").foregroundColor(.secondary)
                        TextField("channel-name", text: $channelName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Picker("Type", selection: $selectedType) {
                        ForEach(ChannelType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                }

                Section {
                    Toggle("Only admins can post", isOn: $isAdminOnly)
                } footer: {
                    Text("Members can still read and react. Use this for announcements and trade callouts.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.footnote).foregroundColor(.marketRed)
                    }
                }
            }
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
                selectedType = editing.type
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
