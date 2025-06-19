// File: Shared/Components/TabBarView.swift

import SwiftUI

struct TabBarView: View {
    @State private var selectedTab = 0
    @StateObject private var messagingService = MessagingService.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .tag(1)
            
            PortfolioView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Portfolio")
                }
                .tag(2)
            
            MessagingView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Messages")
                }
                .badge(messagingService.unreadCount > 0 ? "\(messagingService.unreadCount)" : nil)
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(4)
        }
        .accentColor(.arkadGold)
    }
}

#Preview {
    TabBarView()
        .environmentObject(AuthViewModel())
}

// File: Core/Settings/Views/EnhancedSettingsView.swift

struct EnhancedSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                profileSection
                accountSection
                tradingSection
                privacySection
                notificationsSection
                supportSection
                dangerZoneSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                }
            }
            .alert("Logout", isPresented: $viewModel.showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    viewModel.logout()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
            .alert("Delete Account", isPresented: $viewModel.showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.deleteAccount()
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
        }
    }
    
    private var profileSection: some View {
        Section {
            NavigationLink(destination: EditProfileView()) {
                HStack {
                    Circle()
                        .fill(Color.arkadGold.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(initials)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.arkadGold)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(authViewModel.currentUser?.fullName ?? "User")
                            .font(.headline)
                        Text("@\(authViewModel.currentUser?.username ?? "username")")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("Edit")
                        .font(.caption)
                        .foregroundColor(.arkadGold)
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private var accountSection: some View {
        Section("Account") {
            SettingsRow(
                icon: "person.circle",
                title: "Edit Profile",
                color: .arkadGold,
                destination: EditProfileView()
            )
            
            SettingsRow(
                icon: "crown.fill",
                title: "Subscription",
                color: .arkadGold
            ) {
                // TODO: Navigate to subscription
            }
            
            SettingsRow(
                icon: "creditcard",
                title: "Billing",
                color: .arkadGold
            ) {
                // TODO: Navigate to billing
            }
            
            SettingsRow(
                icon: "doc.text",
                title: "Export Data",
                color: .arkadGold
            ) {
                viewModel.exportUserData()
            }
        }
    }
    
    private var tradingSection: some View {
        Section("Trading") {
            SettingsRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Trading Preferences",
                color: .marketGreen
            ) {
                // TODO: Trading settings
            }
            
            SettingsRow(
                icon: "link",
                title: "Connect Broker",
                color: .marketGreen
            ) {
                // TODO: Broker connection
            }
            
            SettingsRow(
                icon: "bell.badge",
                title: "Trade Alerts",
                color: .marketGreen
            ) {
                // TODO: Trade alerts settings
            }
        }
    }
    
    private var privacySection: some View {
        Section("Privacy") {
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.arkadGold)
                    .frame(width: 24)
                
                Text("Private Account")
                
                Spacer()
                
                Toggle("", isOn: $viewModel.isPrivateAccount)
                    .toggleStyle(SwitchToggleStyle(tint: .arkadGold))
                    .onChange(of: viewModel.isPrivateAccount) { newValue in
                        viewModel.updatePrivacy(newValue)
                    }
            }
            
            SettingsRow(
                icon: "eye.slash",
                title: "Blocked Users",
                color: .arkadGold
            ) {
                // TODO: Navigate to blocked users
            }
            
            SettingsRow(
                icon: "hand.raised",
                title: "Content Preferences",
                color: .arkadGold
            ) {
                // TODO: Navigate to content preferences
            }
        }
    }
    
    private var notificationsSection: some View {
        Section("Notifications") {
            HStack {
                Image(systemName: "bell")
                    .foregroundColor(.arkadGold)
                    .frame(width: 24)
                
                Text("Push Notifications")
                
                Spacer()
                
                Toggle("", isOn: $viewModel.pushNotifications)
                    .toggleStyle(SwitchToggleStyle(tint: .arkadGold))
                    .onChange(of: viewModel.pushNotifications) { newValue in
                        viewModel.updateNotifications(push: newValue)
                    }
            }
            
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(.arkadGold)
                    .frame(width: 24)
                
                Text("Email Notifications")
                
                Spacer()
                
                Toggle("", isOn: $viewModel.emailNotifications)
                    .toggleStyle(SwitchToggleStyle(tint: .arkadGold))
                    .onChange(of: viewModel.emailNotifications) { newValue in
                        viewModel.updateNotifications(email: newValue)
                    }
            }
            
            SettingsRow(
                icon: "bell.circle",
                title: "Notification Settings",
                color: .arkadGold
            ) {
                // TODO: Detailed notification settings
            }
        }
    }
    
    private var supportSection: some View {
        Section("Support") {
            SettingsRow(
                icon: "questionmark.circle",
                title: "Help Center",
                color: .gray
            ) {
                // TODO: Help center
            }
            
            SettingsRow(
                icon: "envelope",
                title: "Contact Support",
                color: .gray
            ) {
                // TODO: Contact support
            }
            
            SettingsRow(
                icon: "star",
                title: "Rate App",
                color: .gray
            ) {
                // TODO: Rate app
            }
            
            SettingsRow(
                icon: "info.circle",
                title: "About ArkadTrader",
                color: .gray
            ) {
                // TODO: About page
            }
            
            SettingsRow(
                icon: "doc.text",
                title: "Privacy Policy",
                color: .gray
            ) {
                // TODO: Privacy policy
            }
            
            SettingsRow(
                icon: "doc.text",
                title: "Terms of Service",
                color: .gray
            ) {
                // TODO: Terms of service
            }
        }
    }
    
    private var dangerZoneSection: some View {
        Section("Account Actions") {
            Button(action: {
                viewModel.showLogoutAlert = true
            }) {
                HStack {
                    Image(systemName: "arrow.right.square")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    Text("Logout")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            
            Button(action: {
                viewModel.showDeleteAccountAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    Text("Delete Account")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
        }
    }
    
    private var initials: String {
        guard let user = authViewModel.currentUser else { return "U" }
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first ?? Character("") : Character("")
        return String(firstInitial) + String(lastInitial)
    }
}

// File: Core/Settings/Views/DetailedSettingsViews.swift

struct NotificationSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        List {
            Section("Trading Notifications") {
                NotificationToggleRow(
                    title: "Trade Execution",
                    subtitle: "When your trades are executed",
                    isOn: .constant(true)
                )
                
                NotificationToggleRow(
                    title: "Price Alerts",
                    subtitle: "When your watchlist stocks hit target prices",
                    isOn: .constant(true)
                )
                
                NotificationToggleRow(
                    title: "Market Open/Close",
                    subtitle: "Daily market hours notifications",
                    isOn: .constant(false)
                )
                
                NotificationToggleRow(
                    title: "Earnings Announcements",
                    subtitle: "When companies in your portfolio report earnings",
                    isOn: .constant(true)
                )
            }
            
            Section("Social Notifications") {
                NotificationToggleRow(
                    title: "New Followers",
                    subtitle: "When someone follows you",
                    isOn: .constant(true)
                )
                
                NotificationToggleRow(
    title: "Post Likes",
                    subtitle: "When someone likes your posts",
                    isOn: .constant(true)
                )
                
                NotificationToggleRow(
                    title: "Comments",
                    subtitle: "When someone comments on your posts",
                    isOn: .constant(true)
                )
                
                NotificationToggleRow(
                    title: "Messages",
                    subtitle: "New direct messages",
                    isOn: .constant(true)
                )
            }
            
            Section("Leaderboard") {
                NotificationToggleRow(
                    title: "Rank Changes",
                    subtitle: "When your leaderboard position changes",
                    isOn: .constant(false)
                )
                
                NotificationToggleRow(
                    title: "Weekly Summary",
                    subtitle: "Your weekly trading performance",
                    isOn: .constant(true)
                )
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .arkadGold))
        }
        .padding(.vertical, 4)
    }
}

struct PrivacySettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        List {
            Section("Account Privacy") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Private Account")
                            .font(.body)
                        Text("Only approved followers can see your trades")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $viewModel.isPrivateAccount)
                        .toggleStyle(SwitchToggleStyle(tint: .arkadGold))
                }
                .padding(.vertical, 4)
            }
            
            Section("Trading Data") {
                PrivacyToggleRow(
                    title: "Show Portfolio Value",
                    subtitle: "Display your total portfolio value on your profile",
                    isOn: .constant(true)
                )
                
                PrivacyToggleRow(
                    title: "Show Trade History",
                    subtitle: "Allow others to see your past trades",
                    isOn: .constant(true)
                )
                
                PrivacyToggleRow(
                    title: "Show Performance Stats",
                    subtitle: "Display win rate and P&L on leaderboard",
                    isOn: .constant(true)
                )
            }
            
            Section("Social Features") {
                PrivacyToggleRow(
                    title: "Allow Messages",
                    subtitle: "Let other users send you direct messages",
                    isOn: .constant(true)
                )
                
                PrivacyToggleRow(
                    title: "Show Online Status",
                    subtitle: "Let others see when you're active",
                    isOn: .constant(false)
                )
            }
            
            Section("Data Usage") {
                Button("Download Your Data") {
                    // TODO: Implement data download
                }
                .foregroundColor(.arkadGold)
                
                Button("Request Data Deletion") {
                    // TODO: Implement data deletion request
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .arkadGold))
        }
        .padding(.vertical, 4)
    }
}

// Enhanced SettingsRow with destination support
struct SettingsRow<Destination: View>: View {
    let icon: String
    let title: String
    let color: Color
    let destination: Destination?
    let action: (() -> Void)?
    
    init(icon: String, title: String, color: Color, destination: Destination) {
        self.icon = icon
        self.title = title
        self.color = color
        self.destination = destination
        self.action = nil
    }
    
    init(icon: String, title: String, color: Color, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.color = color
        self.destination = nil
        self.action = action
    }
    
    var body: some View {
        Group {
            if let destination = destination {
                NavigationLink(destination: destination) {
                    rowContent
                }
            } else {
                Button(action: action ?? {}) {
                    rowContent
                }
            }
        }
    }
    
    private var rowContent: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24, alignment: .center)
            
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            if destination != nil {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
    }
}

// No-destination version for simpler cases
extension SettingsRow where Destination == EmptyView {
    init(icon: String, title: String, color: Color, action: @escaping () -> Void = {}) {
        self.icon = icon
        self.title = title
        self.color = color
        self.destination = nil
        self.action = action
    }
}
