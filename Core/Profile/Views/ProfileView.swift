// File: Core/Profile/Views/ProfileView.swift
// Simplified Profile View

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Profile Header
                VStack(spacing: 10) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text(initials)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    Text(authService.currentUser?.fullName ?? "User")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("@\(authService.currentUser?.username ?? "username")")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    if let bio = authService.currentUser?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()
                
                // Stats
                HStack(spacing: 40) {
                    VStack {
                        Text("\(authService.currentUser?.followersCount ?? 0)")
                            .font(.headline)
                        Text("Followers")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack {
                        Text("\(authService.currentUser?.followingCount ?? 0)")
                            .font(.headline)
                        Text("Following")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack {
                        Text(String(format: "%.1f%%", authService.currentUser?.winRate ?? 0))
                            .font(.headline)
                        Text("Win Rate")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Buttons
                VStack(spacing: 10) {
                    Button("Edit Profile") {
                        showEditProfile = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Logout") {
                        Task {
                            await authService.logout()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
        }
    }
    
    private var initials: String {
        guard let fullName = authService.currentUser?.fullName else { return "U" }
        let names = fullName.split(separator: " ")
        let first = names.first?.first ?? Character("U")
        let last = names.count > 1 ? names.last?.first : nil
        return String(first) + (last != nil ? String(last!) : "")
    }
}

struct EditProfileView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var fullName = ""
    @State private var bio = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Full Name", text: $fullName)
                
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { saveProfile() }
            )
            .onAppear {
                fullName = authService.currentUser?.fullName ?? ""
                bio = authService.currentUser?.bio ?? ""
            }
        }
    }
    
    private func saveProfile() {
        Task {
            do {
                try await authService.updateProfile(fullName: fullName, bio: bio)
                dismiss()
            } catch {
                print("Error updating profile: \(error)")
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(FirebaseAuthService.shared)
}
