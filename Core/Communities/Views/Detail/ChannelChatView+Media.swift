// File: Core/Communities/Views/Detail/ChannelChatView+Media.swift
// Channel chat attachments (photos, documents) and the emoji picker.

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import FirebaseStorage
import Photos
import MobileCoreServices

// MARK: - Media Handling Extensions
extension ChannelChatView {
    func handleImageUpload(_ image: UIImage) {
        // Chat attachments need Cloud Storage (Blaze plan); the attach button is hidden without it.
        guard AppConfig.mediaUploadsEnabled else {
            selectedImage = nil
            return
        }
        isUploadingMedia = true
        
        Task {
            do {
                let imageUrl = try await uploadImageToFirebase(image)
                await MainActor.run {
                    viewModel.sendMedia(MessageMedia(type: .image, url: imageUrl))
                    selectedImage = nil
                    isUploadingMedia = false
                }
            } catch {
                await MainActor.run {
                    uploadErrorMessage = "Couldn't upload the photo: \(error.localizedDescription)"
                    selectedImage = nil
                    isUploadingMedia = false
                }
            }
        }
    }
    
    func handleDocumentUpload(_ url: URL) {
        guard AppConfig.mediaUploadsEnabled else {
            selectedDocumentURL = nil
            return
        }
        isUploadingMedia = true
        
        Task {
            do {
                let documentUrl = try await uploadDocumentToFirebase(url)
                let fileName = url.lastPathComponent
                await MainActor.run {
                    viewModel.sendMedia(MessageMedia(type: .document, url: documentUrl, fileName: fileName))
                    selectedDocumentURL = nil
                    isUploadingMedia = false
                }
            } catch {
                await MainActor.run {
                    uploadErrorMessage = "Couldn't upload the file: \(error.localizedDescription)"
                    selectedDocumentURL = nil
                    isUploadingMedia = false
                }
            }
        }
    }
    
    func uploadImageToFirebase(_ image: UIImage) async throws -> String {
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "ImageUpload", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
        }
        
        
        let fileName = "\(UUID().uuidString).jpg"
        let storageRef = Storage.storage().reference().child("chat_images").child(fileName)
        
        
        do {
            
            // Upload the file using proper async/await pattern
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
                storageRef.putData(imageData, metadata: nil) { metadata, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let metadata = metadata {
                        continuation.resume(returning: metadata)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ImageUpload", code: 3, userInfo: [NSLocalizedDescriptionKey: "Upload failed with no error"]))
                    }
                }
            }
            
            // Add retry logic for download URL
            var downloadURL: URL?
            var attempts = 0
            let maxAttempts = 5
            
            while downloadURL == nil && attempts < maxAttempts {
                do {
                    attempts += 1
                    
                    downloadURL = try await storageRef.downloadURL()
                    
                } catch {
                    
                    if attempts < maxAttempts {
                        // Wait before retrying (exponential backoff)
                        let delay = Double(attempts) * 0.5 // 0.5s, 1s, 1.5s, 2s
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } else {
                        throw error
                    }
                }
            }
            
            guard let finalURL = downloadURL else {
                throw NSError(domain: "ImageUpload", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL after upload"])
            }
            
            return finalURL.absoluteString
            
        } catch {
            throw error
        }
    }
    
    func uploadDocumentToFirebase(_ url: URL) async throws -> String {
        
        guard let documentData = try? Data(contentsOf: url) else {
            throw NSError(domain: "DocumentUpload", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read document"])
        }
        
        
        let originalName = url.lastPathComponent
        let fileExtension = (originalName as NSString).pathExtension
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let storageRef = Storage.storage().reference().child("chat_documents").child(fileName)
        
        
        do {
            
            // Upload the file
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
                storageRef.putData(documentData, metadata: nil) { metadata, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let metadata = metadata {
                        continuation.resume(returning: metadata)
                    } else {
                        continuation.resume(throwing: NSError(domain: "DocumentUpload", code: 3, userInfo: [NSLocalizedDescriptionKey: "Upload failed with no error"]))
                    }
                }
            }
            
            // Add retry logic for download URL
            var downloadURL: URL?
            var attempts = 0
            let maxAttempts = 5
            
            while downloadURL == nil && attempts < maxAttempts {
                do {
                    attempts += 1
                    
                    downloadURL = try await storageRef.downloadURL()
                    
                } catch {
                    
                    if attempts < maxAttempts {
                        // Wait before retrying (exponential backoff)
                        let delay = Double(attempts) * 0.5 // 0.5s, 1s, 1.5s, 2s
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } else {
                        throw error
                    }
                }
            }
            
            guard let finalURL = downloadURL else {
                throw NSError(domain: "DocumentUpload", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL after upload"])
            }
            
            return finalURL.absoluteString
            
        } catch {
            throw error
        }
    }
}

// MARK: - Emoji Picker Overlay Extension
extension ChannelChatView {
    var emojiPickerOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    showEmojiPicker = false
                    emojiPickerForMessage = nil
                }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, DS.Spacing.s)

                HStack {
                    Text(emojiPickerForMessage != nil ? "React to message" : "Add emoji")
                        .font(.headline)
                    Spacer()
                    Button("Done") {
                        showEmojiPicker = false
                        emojiPickerForMessage = nil
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.goldText)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.m)

                emojiGrid
            }
            .background(
                UnevenRoundedRectangle(topLeadingRadius: DS.Radius.xl, topTrailingRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.surface)
                    .ignoresSafeArea(edges: .bottom)
            )
            .transition(.move(edge: .bottom))
        }
        .transition(.opacity)
        .animation(.snappy(duration: 0.3), value: showEmojiPicker)
    }
    
    var emojiGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 8) {
                ForEach(EmojiData.popularEmojis, id: \.self) { emoji in
                    Button(action: {
                        handleEmojiSelection(emoji)
                    }) {
                        Text(emoji)
                            .font(.title2)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Color.surfaceRaised))
                    }
                    .buttonStyle(EmojiButtonStyle())
                    .accessibilityLabel(emoji)
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.bottom, DS.Spacing.l)
        }
        .frame(height: 300)
    }
    
    func handleEmojiSelection(_ emoji: String) {
        if let message = emojiPickerForMessage {
            viewModel.addReaction(to: message.id, emoji: emoji)
        } else {
            if editingMessage != nil {
                editedContent += emoji
            } else {
                messageText += emoji
            }
        }
        
        showEmojiPicker = false
        emojiPickerForMessage = nil
    }
}
