// File: Core/Communities/Views/Detail/ChatSupportViews.swift
// Small pieces used by the channel chat: media payload, mention suggestions, pickers and emoji data.

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import FirebaseStorage
import Photos
import MobileCoreServices

// MARK: - Media Content Structure (File Level)
struct MediaContent {
    let type: MediaType
    let url: String
    let fileName: String
    let fileSize: Int?
    
    enum MediaType {
        case image, document, video
    }
}

// MARK: - Mention Suggestion Row
struct MentionSuggestionRow: View {
    let user: User
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.m) {
                UserAvatar(username: user.username, imageURL: user.profileImageUrl, size: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.fullName.isEmpty ? user.username : user.fullName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Image Picker Component (File Level)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Document Picker Component (File Level)
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf, .plainText, .rtf, .spreadsheet, .presentation,
            .zip, .gzip, .image, .movie
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.selectedURL = url
            }
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

struct EmojiButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

// Emoji Data
struct EmojiData {
    static let popularEmojis = [
        "👍", "❤️", "😂", "😮", "😢", "😡", "👎", "🎉",
        "🔥", "💯", "⭐", "✅", "❌", "🚀", "💎", "📈",
        "📉", "💰", "🤑", "🎯", "⚡", "💪", "🙌", "👏",
        "🤔", "😎", "🤩", "😍", "🥳", "🤯", "😴", "🤪",
        "🙄", "😤", "🤬", "😱", "🥺", "😭", "🤝", "👋",
        "✋", "👌", "🤞", "🤟", "🤘", "👊", "✊", "👆",
        "🐂", "🐻", "📊", "📋", "💼", "💻", "📱", "⌚",
        "🎲", "🎰", "🏆", "🥇", "🥈", "🥉", "🎖️", "🏅"
    ]
}

// Helper for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// MARK: - Pinned Messages Sheet
/// Every pinned message in the channel. Tap one to jump to it; moderators can unpin.
struct PinnedMessagesSheet: View {
    let messages: [CommunityMessage]
    let userCache: [String: User]
    let canUnpin: Bool
    let previewText: (CommunityMessage) -> String
    let onSelect: (CommunityMessage) -> Void
    let onUnpin: (CommunityMessage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if messages.isEmpty {
                        EmptyStateView(
                            systemImage: "pin",
                            title: "No pinned messages",
                            message: "Owners and moderators can pin important messages from a message's menu."
                        )
                        .cardStyle(padding: 0)
                    } else {
                        CommunityCardList(items: messages, dividerInset: 60) { message in
                            row(message)
                        }
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.vertical, DS.Spacing.m)
            }
            .screenBackground()
            .navigationTitle("Pinned")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Color.goldText)
                }
            }
        }
    }

    private func row(_ message: CommunityMessage) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            Button {
                onSelect(message)
            } label: {
                HStack(alignment: .top, spacing: DS.Spacing.m) {
                    UserAvatar(
                        username: message.authorUsername,
                        imageURL: message.authorAvatarURL ?? userCache[message.authorId]?.profileImageUrl,
                        size: 32
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(message.authorUsername)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.primary)
                            Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(previewText(message))
                            .font(.subheadline)
                            .foregroundStyle(Color.primary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Jumps to the message")

            if canUnpin {
                Button {
                    onUnpin(message)
                } label: {
                    Image(systemName: "pin.slash")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.surfaceRaised))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Unpin")
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
    }
}
