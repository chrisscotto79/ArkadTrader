// File: Core/Settings/Views/SettingsView.swift
// Fixed Settings View with all navigation implemented

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    @State private var showEditProfile = false
    @State private var showNotificationSettings = false
    @State private var showPrivacySettings = false
    @State private var showTradingSettings = false
    @State private var showBrokerConnection = false
    @State private var showDataExport = false
    @State private var showHelpCenter = false
    @State private var showContactSupport = false
    @State private var showAbout = false

    
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
        .sheet(isPresented: $showPrivacySettings) {
            PrivacySettingsView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showTradingSettings) {
            TradingSettingsView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showBrokerConnection) {
            BrokerConnectionView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showDataExport) {
            DataExportView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showHelpCenter) {
            HelpCenterView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showContactSupport) {
            ContactSupportView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
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
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color.backgroundSecondary)
    }
    
    // MARK: - Settings List Section
    private var settingsListSection: some View {
        List {
            // Account Settings
            Section("Account") {
                SettingsRowView(
                    icon: "person.circle",
                    title: "Edit Profile",
                    color: .blue
                ) {
                    showEditProfile = true
                }
                
                SettingsRowView(
                    icon: "bell",
                    title: "Notifications",
                    color: .blue
                ) {
                    showNotificationSettings = true
                }
                
                SettingsRowView(
                    icon: "lock.shield",
                    title: "Privacy & Security",
                    color: .purple
                ) {
                    showPrivacySettings = true
                }
            }
            
            // Trading Settings
            Section("Trading") {
                SettingsRowView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Trading Preferences",
                    color: .marketGreen
                ) {
                    showTradingSettings = true
                }
                
                SettingsRowView(
                    icon: "link",
                    title: "Connect Broker",
                    color: .marketGreen
                ) {
                    showBrokerConnection = true
                }
                
                SettingsRowView(
                    icon: "doc.text",
                    title: "Export Data",
                    color: .marketGreen
                ) {
                    showDataExport = true
                }
            }
            
            // Support & About
            Section("Support") {
                SettingsRowView(
                    icon: "questionmark.circle",
                    title: "Help Center",
                    color: .gray
                ) {
                    showHelpCenter = true
                }
                
                SettingsRowView(
                    icon: "envelope",
                    title: "Contact Support",
                    color: .gray
                ) {
                    showContactSupport = true
                }
                
                SettingsRowView(
                    icon: "info.circle",
                    title: "About ArkadTrader",
                    color: .gray
                ) {
                    showAbout = true
                }
            }
            
            // Account Actions
            Section {
                SettingsRowView(
                    icon: "arrow.right.square",
                    title: "Logout",
                    color: .red
                ) {
                    Task {
                        await authService.logout()
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    // MARK: - Helper Properties
    private var initials: String {
        guard let user = authService.currentUser else { return "U" }
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first ?? Character("") : Character("")
        return "\(firstInitial)\(lastInitial)".uppercased()
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
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.textTertiary)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Broker Model
struct BrokerModel {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: Color
    let isAPISupported: Bool
    let features: [String]
}

// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    // Privacy preferences stored in UserDefaults
    @AppStorage("profile_visibility_public") private var profileVisibilityPublic = true
    @AppStorage("allow_message_requests") private var allowMessageRequests = true
    @AppStorage("show_trading_activity") private var showTradingActivity = true
    @AppStorage("allow_community_invites") private var allowCommunityInvites = true
    @AppStorage("data_analytics_enabled") private var dataAnalyticsEnabled = true
    @AppStorage("marketing_emails_enabled") private var marketingEmailsEnabled = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Privacy
                Section("Profile Privacy") {
                    privacyToggle(
                        title: "Public Profile",
                        description: "Allow others to find and view your profile",
                        icon: "person.circle",
                        color: .blue,
                        isOn: $profileVisibilityPublic
                    )
                    
                    privacyToggle(
                        title: "Show Trading Activity",
                        description: "Display your trades and performance publicly",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .green,
                        isOn: $showTradingActivity
                    )
                }
                
                // Communication Privacy
                Section("Communication") {
                    privacyToggle(
                        title: "Allow Message Requests",
                        description: "Let other users send you direct messages",
                        icon: "message",
                        color: .purple,
                        isOn: $allowMessageRequests
                    )
                    
                    privacyToggle(
                        title: "Community Invites",
                        description: "Allow invitations to join communities",
                        icon: "person.3",
                        color: .orange,
                        isOn: $allowCommunityInvites
                    )
                }
                
                // Data & Analytics
                Section("Data & Analytics") {
                    privacyToggle(
                        title: "Usage Analytics",
                        description: "Help improve ArkadTrader with usage data",
                        icon: "chart.bar",
                        color: .gray,
                        isOn: $dataAnalyticsEnabled
                    )
                    
                    privacyToggle(
                        title: "Marketing Emails",
                        description: "Receive updates about new features",
                        icon: "envelope",
                        color: .gray,
                        isOn: $marketingEmailsEnabled
                    )
                }
            }
            .navigationTitle("Privacy & Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func privacyToggle(
        title: String,
        description: String,
        icon: String,
        color: Color,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
