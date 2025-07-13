//
//  AboutView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/12/25.
//


// File: Core/Settings/Views/AboutView.swift

import SwiftUI

struct AboutView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var showingTerms = false
    @State private var showingPrivacyPolicy = false
    @State private var showingLicenses = false
    @State private var showingReleaseNotes = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App Header
                    appHeaderSection
                    
                    // App Information
                    appInfoSection
                    
                    // Legal & Privacy
                    legalSection
                    
                    // Development Information
                    developmentSection
                    
                    // Support & Feedback
                    supportSection
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("About ArkadTrader")
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
        .sheet(isPresented: $showingTerms) {
            LegalDocumentView(documentType: .terms)
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            LegalDocumentView(documentType: .privacy)
        }
        .sheet(isPresented: $showingLicenses) {
            LicensesView()
        }
        .sheet(isPresented: $showingReleaseNotes) {
            ReleaseNotesView()
        }
    }
    
    // MARK: - App Header Section
    private var appHeaderSection: some View {
        VStack(spacing: 20) {
            // App Icon
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.arkadGold, Color.arkadGoldLight]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Text("AT")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                )
                .shadow(color: Color.arkadGold.opacity(0.4), radius: 10, x: 0, y: 5)
            
            // App Name and Version
            VStack(spacing: 8) {
                Text("ArkadTrader")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version \(appVersion) (Build \(buildNumber))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text("Trading. Simplified.")
                    .font(.caption)
                    .foregroundColor(.arkadGold)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
        )
    }
    
    // MARK: - App Information Section
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                InfoRow(
                    icon: "calendar",
                    title: "Release Date",
                    value: "January 2025",
                    color: .blue
                )
                
                InfoRow(
                    icon: "iphone",
                    title: "Compatibility",
                    value: "iOS 17.0 or later",
                    color: .green
                )
                
                InfoRow(
                    icon: "globe",
                    title: "Languages",
                    value: "English",
                    color: .purple
                )
                
                InfoRow(
                    icon: "externaldrive",
                    title: "App Size",
                    value: appSize,
                    color: .orange
                )
                
                Button(action: {
                    showingReleaseNotes = true
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Release Notes")
                            .foregroundColor(.primary)
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
    }
    
    // MARK: - Legal Section
    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Legal & Privacy")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                LegalRow(
                    icon: "doc.text",
                    title: "Terms of Service",
                    description: "Review our terms and conditions",
                    color: .blue
                ) {
                    showingTerms = true
                }
                
                LegalRow(
                    icon: "hand.raised",
                    title: "Privacy Policy",
                    description: "Learn how we protect your data",
                    color: .green
                ) {
                    showingPrivacyPolicy = true
                }
                
                LegalRow(
                    icon: "list.bullet",
                    title: "Open Source Licenses",
                    description: "Third-party libraries and acknowledgments",
                    color: .purple
                ) {
                    showingLicenses = true
                }
            }
        }
    }
    
    // MARK: - Development Section
    private var developmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Development")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                InfoRow(
                    icon: "person.circle",
                    title: "Developer",
                    value: "ArkadTrader Inc.",
                    color: .blue
                )
                
                InfoRow(
                    icon: "hammer",
                    title: "Built with",
                    value: "SwiftUI & Firebase",
                    color: .orange
                )
                
                InfoRow(
                    icon: "checkmark.shield",
                    title: "Security",
                    value: "256-bit SSL Encryption",
                    color: .green
                )
                
                InfoRow(
                    icon: "server.rack",
                    title: "Infrastructure",
                    value: "Enterprise-grade cloud hosting",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Support Section
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Support & Feedback")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                SupportActionRow(
                    icon: "envelope",
                    title: "Contact Support",
                    description: "Get help with your account",
                    color: .blue
                ) {
                    // TODO: Open contact support
                }
                
                SupportActionRow(
                    icon: "star",
                    title: "Rate ArkadTrader",
                    description: "Rate us on the App Store",
                    color: .yellow
                ) {
                    openAppStore()
                }
                
                SupportActionRow(
                    icon: "square.and.arrow.up",
                    title: "Share ArkadTrader",
                    description: "Tell your friends about us",
                    color: .green
                ) {
                    shareApp()
                }
                
                SupportActionRow(
                    icon: "globe",
                    title: "Visit Website",
                    description: "arkadtrader.com",
                    color: .purple
                ) {
                    openWebsite()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private var appSize: String {
        // This would typically be calculated dynamically
        "45.2 MB"
    }
    
    // MARK: - Helper Methods
    
    private func openAppStore() {
        // TODO: Replace with actual App Store URL
        if let url = URL(string: "https://apps.apple.com/app/arkadtrader") {
            UIApplication.shared.open(url)
        }
    }
    
    private func shareApp() {
        let activityVC = UIActivityViewController(
            activityItems: ["Check out ArkadTrader - Trading made simple! https://arkadtrader.com"],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func openWebsite() {
        if let url = URL(string: "https://arkadtrader.com") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.primary)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.gray)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

struct LegalRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
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

struct SupportActionRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Legal Document View
struct LegalDocumentView: View {
    let documentType: LegalDocumentType
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(documentType.content)
                        .font(.body)
                        .lineSpacing(4)
                }
                .padding()
            }
            .navigationTitle(documentType.title)
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
}

enum LegalDocumentType {
    case terms
    case privacy
    
    var title: String {
        switch self {
        case .terms: return "Terms of Service"
        case .privacy: return "Privacy Policy"
        }
    }
    
    var content: String {
        switch self {
        case .terms:
            return """
            TERMS OF SERVICE
            
            Last updated: January 2025
            
            1. ACCEPTANCE OF TERMS
            By accessing and using ArkadTrader, you accept and agree to be bound by the terms and provision of this agreement.
            
            2. DESCRIPTION OF SERVICE
            ArkadTrader is a trading platform that provides tools and services for investment tracking and portfolio management.
            
            3. USER RESPONSIBILITIES
            You are responsible for maintaining the confidentiality of your account and password and for restricting access to your computer.
            
            4. TRADING RISKS
            Trading securities involves risk. Past performance does not guarantee future results. You may lose money.
            
            5. LIMITATION OF LIABILITY
            ArkadTrader shall not be liable for any indirect, incidental, special, consequential, or punitive damages.
            
            6. MODIFICATIONS
            We reserve the right to modify these terms at any time. Changes will be effective immediately upon posting.
            
            For complete terms, visit: https://arkadtrader.com/terms
            """
            
        case .privacy:
            return """
            PRIVACY POLICY
            
            Last updated: January 2025
            
            1. INFORMATION WE COLLECT
            We collect information you provide directly to us, such as when you create an account, make trades, or contact us.
            
            2. HOW WE USE YOUR INFORMATION
            We use the information we collect to provide, maintain, and improve our services.
            
            3. INFORMATION SHARING
            We do not sell, trade, or rent your personal information to third parties.
            
            4. DATA SECURITY
            We implement appropriate security measures to protect your personal information.
            
            5. YOUR RIGHTS
            You have the right to access, update, or delete your personal information.
            
            6. COOKIES
            We use cookies to enhance your experience and analyze usage patterns.
            
            7. CONTACT US
            If you have questions about this privacy policy, contact us at privacy@arkadtrader.com.
            
            For complete privacy policy, visit: https://arkadtrader.com/privacy
            """
        }
    }
}

// MARK: - Licenses View
struct LicensesView: View {
    @Environment(\.dismiss) var dismiss
    
    private let licenses = [
        License(name: "Firebase", license: "Apache License 2.0"),
        License(name: "SwiftUI", license: "Apple Software License"),
        License(name: "Kingfisher", license: "MIT License"),
        License(name: "Alamofire", license: "MIT License")
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("Open Source Libraries") {
                    ForEach(licenses, id: \.name) { license in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(license.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(license.license)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Licenses")
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
}

struct License {
    let name: String
    let license: String
}

// MARK: - Release Notes View
struct ReleaseNotesView: View {
    @Environment(\.dismiss) var dismiss
    
    private let releases = [
        Release(
            version: "1.0.0",
            date: "January 2025",
            changes: [
                "Initial release of ArkadTrader",
                "Portfolio tracking and management",
                "Social trading features",
                "Broker integration support",
                "Real-time market data"
            ]
        )
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(releases, id: \.version) { release in
                    Section("Version \(release.version) - \(release.date)") {
                        ForEach(release.changes, id: \.self) { change in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.blue)
                                Text(change)
                                    .font(.body)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Release Notes")
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
}

struct Release {
    let version: String
    let date: String
    let changes: [String]
}

#Preview {
    AboutView()
        .environmentObject(FirebaseAuthService.shared)
}