// File: Core/Profile/Views/ProfileComponents.swift
// Fixed to use FirebaseAuthService instead of AuthViewModel

import SwiftUI

// MARK: - Enhanced Settings View
struct EnhancedSettingsView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section {
                    HStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text(initials)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authService.currentUser?.fullName ?? "User")
                                .font(.headline)
                            Text("@\(authService.currentUser?.username ?? "username")")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Button("Edit") {
                            showEditProfile = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                
                // Account Settings
                Section("Account") {
                    SettingsRow(icon: "person.circle", title: "Edit Profile", color: .blue) {
                        showEditProfile = true
                    }
                    
                    SettingsRow(icon: "crown.fill", title: "Subscription", color: .blue) {
                        // TODO: Navigate to subscription
                    }
                    
                    SettingsRow(icon: "bell", title: "Notifications", color: .blue) {
                        // TODO: Navigate to notifications
                    }
                    
                    SettingsRow(icon: "lock", title: "Privacy & Security", color: .blue) {
                        // TODO: Navigate to privacy
                    }
                }
                
                // Trading Settings
                Section("Trading") {
                    SettingsRow(icon: "chart.line.uptrend.xyaxis", title: "Trading Preferences", color: .green) {
                        // TODO: Trading settings
                    }
                    
                    SettingsRow(icon: "link", title: "Connect Broker", color: .green) {
                        // TODO: Broker connection
                    }
                    
                    SettingsRow(icon: "doc.text", title: "Export Data", color: .green) {
                        // TODO: Data export
                    }
                }
                
                // Support & About
                Section("Support") {
                    SettingsRow(icon: "questionmark.circle", title: "Help Center", color: .gray) {
                        // TODO: Help center
                    }
                    
                    SettingsRow(icon: "envelope", title: "Contact Support", color: .gray) {
                        // TODO: Contact support
                    }
                    
                    SettingsRow(icon: "info.circle", title: "About ArkadTrader", color: .gray) {
                        // TODO: About page
                    }
                }
                
                // Logout
                Section {
                    Button(action: {
                        Task {
                            await authService.logout()
                        }
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .foregroundColor(.red)
                            Text("Logout")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(authService)
        }
    }
    
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

// MARK: - Settings Row
struct SettingsRow: View {
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
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
