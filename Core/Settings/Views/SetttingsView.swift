// File: Core/Settings/Views/SettingsView.swift
// Fixed Settings View with proper authentication service

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    @State private var showEditProfile = false
    @State private var showNotificationSettings = false

    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Profile header section
                profileHeaderSection
                
                // Settings list
                settingsListSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showNotificationSettings) {
            NotificationSettingsView()
                .environmentObject(authService)
        }
    }
    
    // MARK: - Profile Header Section
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // User avatar and info
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.arkadGold, Color.arkadGoldLight]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .overlay(
                        Text(initials)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.arkadGold.opacity(0.4), radius: 8, x: 0, y: 4)
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    Text(authService.currentUser?.fullName ?? "Unknown User")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text("@\(authService.currentUser?.username ?? "username")")
                        .font(.subheadline)
                        .foregroundColor(.arkadGold)
                        .fontWeight(.medium)
                    
                    if let email = authService.currentUser?.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                
                Spacer()
                
                // Edit profile button
                Button(action: { showEditProfile = true }) {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .foregroundColor(.arkadGold)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.arkadGold.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.arkadGold.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - Settings List Section
    private var settingsListSection: some View {
        List {
            // Account Settings
            Section("Account") {
                SettingsRowView(
                    icon: "person.circle",
                    title: "Edit Profile",
                    color: .arkadGold
                ) {
                    showEditProfile = true
                }
                
                SettingsRowView(
                    icon: "bell",
                    title: "Notifications",
                    color: .blue
                ) {
                    // TODO: Navigate to notifications settings
                }
                
                SettingsRowView(
                    icon: "lock.shield",
                    title: "Privacy & Security",
                    color: .purple
                ) {
                    // TODO: Navigate to privacy settings
                }
            }
            
            // Trading Settings
            Section("Trading") {
                SettingsRowView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Trading Preferences",
                    color: .marketGreen
                ) {
                    // TODO: Navigate to trading settings
                }
                
                SettingsRowView(
                    icon: "link",
                    title: "Connect Broker",
                    color: .marketGreen
                ) {
                    // TODO: Navigate to broker connection
                }
                
                SettingsRowView(
                    icon: "doc.text",
                    title: "Export Data",
                    color: .marketGreen
                ) {
                    // TODO: Navigate to data export
                }
            }
            
            // Support & About
            Section("Support") {
                SettingsRowView(
                    icon: "questionmark.circle",
                    title: "Help Center",
                    color: .gray
                ) {
                    // TODO: Navigate to help center
                }
                
                SettingsRowView(
                    icon: "envelope",
                    title: "Contact Support",
                    color: .gray
                ) {
                    // TODO: Navigate to contact support
                }
                
                SettingsRowView(
                    icon: "info.circle",
                    title: "About ArkadTrader",
                    color: .gray
                ) {
                    // TODO: Navigate to about page
                }
            }
            
            // Logout Section
            Section {
                Button(action: {
                    Task {
                        await authService.logout()
                        dismiss()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.right.square")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        Text("Logout")
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Computed Properties
    private var initials: String {
        guard let user = authService.currentUser else { return "U" }
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first : nil
        
        if let lastInitial = lastInitial {
            return String(firstInitial) + String(lastInitial)
        } else {
            return String(firstInitial)
        }
    }
}

// MARK: - Settings Row View
struct SettingsRowView: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24, alignment: .center)
                
                Text(title)
                    .foregroundColor(.textPrimary)
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
        .environmentObject(FirebaseAuthService.shared)
}
