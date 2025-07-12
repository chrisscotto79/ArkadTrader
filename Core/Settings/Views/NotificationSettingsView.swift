// File: Core/Settings/Views/NotificationSettingsView.swift

import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    // Notification preferences stored in UserDefaults
    @AppStorage("push_notifications_enabled") private var pushNotificationsEnabled = true
    @AppStorage("email_notifications_enabled") private var emailNotificationsEnabled = true
    
    // Trading notifications
    @AppStorage("notify_trade_executions") private var notifyTradeExecutions = true
    @AppStorage("notify_price_alerts") private var notifyPriceAlerts = true
    @AppStorage("notify_market_updates") private var notifyMarketUpdates = false
    
    // Social notifications
    @AppStorage("notify_new_followers") private var notifyNewFollowers = true
    @AppStorage("notify_post_likes") private var notifyPostLikes = true
    @AppStorage("notify_comments") private var notifyComments = true
    @AppStorage("notify_mentions") private var notifyMentions = true
    
    // Community notifications
    @AppStorage("notify_community_invites") private var notifyCommunityInvites = true
    @AppStorage("notify_community_updates") private var notifyCommunityUpdates = true
    
    var body: some View {
        NavigationView {
            List {
                // Master Controls
                Section {
                    Toggle(isOn: $pushNotificationsEnabled) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Push Notifications")
                                    .fontWeight(.medium)
                                Text("Receive notifications on your device")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .onChange(of: pushNotificationsEnabled) { newValue in
                        if newValue {
                            Task {
                                await requestNotificationPermission()
                            }
                        }
                    }
                    
                    Toggle(isOn: $emailNotificationsEnabled) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Email Notifications")
                                    .fontWeight(.medium)
                                Text("Receive important updates via email")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                // Trading Notifications
                Section("Trading Activity") {
                    notificationToggle(
                        title: "Trade Executions",
                        description: "When your trades are executed",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .marketGreen,
                        isOn: $notifyTradeExecutions,
                        isEnabled: pushNotificationsEnabled
                    )
                    
                    notificationToggle(
                        title: "Price Alerts",
                        description: "When price targets are reached",
                        icon: "bell.and.waveform",
                        color: .marketGreen,
                        isOn: $notifyPriceAlerts,
                        isEnabled: pushNotificationsEnabled
                    )
                    
                    notificationToggle(
                        title: "Market Updates",
                        description: "Important market news and events",
                        icon: "newspaper",
                        color: .marketGreen,
                        isOn: $notifyMarketUpdates,
                        isEnabled: pushNotificationsEnabled
                    )
                }
                .disabled(!pushNotificationsEnabled)
                
                // Social Notifications
                Section("Social Activity") {
                    notificationToggle(
                        title: "New Followers",
                        description: "When someone follows you",
                        icon: "person.badge.plus",
                        color: .purple,
                        isOn: $notifyNewFollowers,
                        isEnabled: pushNotificationsEnabled
                    )
                    
                    notificationToggle(
                        title: "Post Likes",
                        description: "When someone likes your posts",
                        icon: "heart",
                        color: .purple,
                        isOn: $notifyPostLikes,
                        isEnabled: pushNotificationsEnabled
                    )
                    
                    notificationToggle(
                        title: "Comments",
                        description: "When someone comments on your posts",
                        icon: "message",
                        color: .purple,
                        isOn: $notifyComments,
                        isEnabled: pushNotificationsEnabled
                    )
                    
                    notificationToggle(
                        title: "Mentions",
                        description: "When someone mentions you",
                        icon: "at",
                        color: .purple,
                        isOn: $notifyMentions,
                        isEnabled: pushNotificationsEnabled
                    )
                }
                .disabled(!pushNotificationsEnabled)
                
                // Community Notifications
                Section("Communities") {
                    notificationToggle(
                        title: "Community Invites",
                        description: "When you're invited to join",
                        icon: "person.3",
                        color: .orange,
                        isOn: $notifyCommunityInvites,
                        isEnabled: pushNotificationsEnabled
                    )
                    
                    notificationToggle(
                        title: "Community Updates",
                        description: "Important community announcements",
                        icon: "megaphone",
                        color: .orange,
                        isOn: $notifyCommunityUpdates,
                        isEnabled: pushNotificationsEnabled
                    )
                }
                .disabled(!pushNotificationsEnabled)
                
                // Additional Settings
                Section {
                    Button(action: {
                        openSystemNotificationSettings()
                    }) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            
                            Text("System Notification Settings")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
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
    
    private func notificationToggle(
        title: String,
        description: String,
        icon: String,
        color: Color,
        isOn: Binding<Bool>,
        isEnabled: Bool
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isEnabled ? color : .gray)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.medium)
                        .foregroundColor(isEnabled ? .primary : .gray)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .disabled(!isEnabled)
    }
    
    // MARK: - Helper Methods
    
    private func requestNotificationPermission() async {
        // This would integrate with your actual notification service
        // For now, we'll just save the preference
        
        #if !targetEnvironment(simulator)
        // Request notification permissions on real device
        // This would typically use UNUserNotificationCenter
        #endif
    }
    
    private func openSystemNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NotificationSettingsView()
        .environmentObject(FirebaseAuthService.shared)
}
