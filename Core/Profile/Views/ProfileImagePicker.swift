//
//  ProfileImagePicker.swift
//  ArkadTrader
//
//  Created by chris scotto on 8/2/25.
//


// File: Core/Profile/Views/ProfileImagePicker.swift
// Modern Profile Image Picker with Camera and Photo Library Support

import SwiftUI
import PhotosUI
import UIKit

struct ProfileImagePicker: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingActionSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.arkadGold.opacity(0.8))
                    
                    Text("Profile Picture")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose a photo that represents you")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Current Image Preview (if any)
                if let selectedImage = selectedImage {
                    VStack(spacing: 16) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.arkadGold)
                        
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.arkadGold, lineWidth: 3)
                            )
                            .shadow(color: Color.arkadGold.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Photo Library Button (iOS 16+ PhotosPicker)
                    if #available(iOS 16.0, *) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title3)
                                Text("Choose from Library")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.arkadGold, Color.arkadGoldLight]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                            .shadow(color: Color.arkadGold.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    await MainActor.run {
                                        selectedImage = image
                                    }
                                }
                            }
                        }
                    } else {
                        // Fallback for iOS 15 and earlier
                        Button(action: {
                            sourceType = .photoLibrary
                            showingImagePicker = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title3)
                                Text("Choose from Library")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.arkadGold, Color.arkadGoldLight]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                            .shadow(color: Color.arkadGold.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                    }
                    
                    // Camera Button
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button(action: {
                            sourceType = .camera
                            showingImagePicker = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.title3)
                                Text("Take Photo")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.arkadGold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white)
                                    .shadow(color: Color.arkadGold.opacity(0.2), radius: 6, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.arkadGold, lineWidth: 2)
                            )
                        }
                    }
                    
                    // Remove Photo Button (if image exists)
                    if selectedImage != nil {
                        Button(action: {
                            selectedImage = nil
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "trash.fill")
                                    .font(.title3)
                                Text("Remove Photo")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.red.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("Profile Picture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                    .fontWeight(.semibold)
                    .disabled(selectedImage == nil)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            LegacyImagePicker(sourceType: sourceType, selectedImage: $selectedImage)
        }
    }
}

// MARK: - Legacy Image Picker for iOS 15 and Camera Support

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