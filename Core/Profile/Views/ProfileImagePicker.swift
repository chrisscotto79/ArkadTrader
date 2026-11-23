// File: Core/Profile/Views/ProfileImagePicker.swift
// Choose a profile photo from the library or the camera, with a live preview.

import SwiftUI
import PhotosUI
import UIKit

struct ProfileImagePicker: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                Spacer(minLength: DS.Spacing.l)

                preview

                VStack(spacing: 6) {
                    Text("Profile photo")
                        .font(.title2.weight(.bold))
                    Text("Choose a photo that represents you. It's shown on your profile, posts and in communities.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, DS.Spacing.l)

                Spacer()

                actions
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.bottom, DS.Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .screenBackground()
            .navigationTitle("Profile Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.goldText)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.goldText)
                    .disabled(selectedImage == nil)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            LegacyImagePicker(sourceType: sourceType, selectedImage: $selectedImage)
                .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedImage = image
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preview

    private var preview: some View {
        ZStack {
            Circle()
                .fill(Color.surfaceRaised)

            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 148, height: 148)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(selectedImage == nil ? Color.hairline : Color.arkadGold, lineWidth: selectedImage == nil ? 1 : 3)
        )
        .accessibilityLabel(selectedImage == nil ? "No photo selected" : "Selected photo")
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: DS.Spacing.m) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Choose from library", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(PrimaryButtonStyle())

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    sourceType = .camera
                    showingImagePicker = true
                } label: {
                    Label("Take photo", systemImage: "camera")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if selectedImage != nil {
                Button(role: .destructive) {
                    withAnimation(.snappy(duration: 0.25)) {
                        selectedImage = nil
                        selectedPhotoItem = nil
                    }
                } label: {
                    Text("Remove selection")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.marketRed)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Camera / Legacy Image Picker

struct LegacyImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: LegacyImagePicker

        init(_ parent: LegacyImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }

            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ProfileImagePicker(selectedImage: .constant(nil))
}
