//
//  ContactSupportView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/12/25.
//


// File: Core/Settings/Views/ContactSupportView.swift

import SwiftUI

struct ContactSupportView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedContactMethod: ContactMethod = .email
    @State private var selectedIssueCategory: IssueCategory = .general
    @State private var selectedPriority: Priority = .normal
    @State private var subject = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection
                    
                    // Contact Methods
                    contactMethodsSection
                    
                    // Support Form (if email is selected)
                    if selectedContactMethod == .email {
                        supportFormSection
                    }
                    
                    // Support Information
                    supportInfoSection
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Contact Support")
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
        .alert("Support Request Sent", isPresented: $showingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Your support request has been submitted. We'll get back to you within 24 hours.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "headphones.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 60))
            
            VStack(spacing: 8) {
                Text("How can we help?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Our support team is here to assist you with any questions or issues you may have.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.05))
        )
    }
    
    // MARK: - Contact Methods Section
    private var contactMethodsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contact Methods")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ContactMethodCard(
                    method: .email,
                    isSelected: selectedContactMethod == .email
                ) {
                    selectedContactMethod = .email
                }
                
                ContactMethodCard(
                    method: .liveChat,
                    isSelected: selectedContactMethod == .liveChat
                ) {
                    selectedContactMethod = .liveChat
                    openLiveChat()
                }
                
                ContactMethodCard(
                    method: .phone,
                    isSelected: selectedContactMethod == .phone
                ) {
                    selectedContactMethod = .phone
                    callSupport()
                }
            }
        }
    }
    
    // MARK: - Support Form Section
    private var supportFormSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Submit Support Request")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Issue Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Issue Category")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Category", selection: $selectedIssueCategory) {
                    ForEach(IssueCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Priority Level
            VStack(alignment: .leading, spacing: 8) {
                Text("Priority Level")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    ForEach(Priority.allCases, id: \.self) { priority in
                        Button(action: {
                            selectedPriority = priority
                        }) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(priority.color)
                                    .frame(width: 8, height: 8)
                                
                                Text(priority.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedPriority == priority ? priority.color.opacity(0.2) : Color.gray.opacity(0.1))
                            )
                            .foregroundColor(selectedPriority == priority ? priority.color : .primary)
                        }
                    }
                }
            }
            
            // Subject
            VStack(alignment: .leading, spacing: 8) {
                Text("Subject")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Brief description of your issue", text: $subject)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Message
            VStack(alignment: .leading, spacing: 8) {
                Text("Message")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextEditor(text: $message)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Submit Button
            Button(action: submitSupportRequest) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(isSubmitting ? "Submitting..." : "Submit Request")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isFormValid || isSubmitting)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
        )
    }
    
    // MARK: - Support Information Section
    private var supportInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Support Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                SupportInfoCard(
                    icon: "clock",
                    title: "Response Times",
                    content: "• High Priority: 2-4 hours\n• Normal Priority: 24 hours\n• Low Priority: 48-72 hours",
                    color: .orange
                )
                
                SupportInfoCard(
                    icon: "globe",
                    title: "Support Hours",
                    content: "Monday - Friday: 9:00 AM - 6:00 PM EST\nWeekends: 10:00 AM - 4:00 PM EST",
                    color: .green
                )
                
                SupportInfoCard(
                    icon: "envelope",
                    title: "Direct Contact",
                    content: "Email: support@arkadtrader.com\nPhone: 1-800-ARKAD-TRADE\n(1-800-275-23-87233)",
                    color: .blue
                )
                
                SupportInfoCard(
                    icon: "questionmark.circle",
                    title: "Before Contacting",
                    content: "• Check our Help Center for quick answers\n• Try restarting the app\n• Ensure you have the latest version",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Helper Methods
    
    private func submitSupportRequest() {
        isSubmitting = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isSubmitting = false
            
            // Simulate success/failure
            if Bool.random() {
                showingSuccessAlert = true
                // Clear form
                subject = ""
                message = ""
                selectedPriority = .normal
                selectedIssueCategory = .general
            } else {
                errorMessage = "Failed to submit support request. Please try again."
                showingErrorAlert = true
            }
        }
    }
    
    private func openLiveChat() {
        // TODO: Implement live chat functionality
        print("Opening live chat...")
    }
    
    private func callSupport() {
        // TODO: Implement phone call functionality
        if let phoneURL = URL(string: "tel://18002752387233") {
            UIApplication.shared.open(phoneURL)
        }
    }
}

// MARK: - Contact Method Enum
enum ContactMethod: String, CaseIterable {
    case email = "email"
    case liveChat = "live_chat"
    case phone = "phone"
    
    var displayName: String {
        switch self {
        case .email: return "Email Support"
        case .liveChat: return "Live Chat"
        case .phone: return "Phone Support"
        }
    }
    
    var description: String {
        switch self {
        case .email: return "Submit a detailed support request"
        case .liveChat: return "Chat with support in real-time"
        case .phone: return "Speak directly with our team"
        }
    }
    
    var icon: String {
        switch self {
        case .email: return "envelope"
        case .liveChat: return "message"
        case .phone: return "phone"
        }
    }
    
    var color: Color {
        switch self {
        case .email: return .blue
        case .liveChat: return .green
        case .phone: return .orange
        }
    }
    
    var availability: String {
        switch self {
        case .email: return "24/7"
        case .liveChat: return "Mon-Fri 9AM-6PM EST"
        case .phone: return "Mon-Fri 9AM-6PM EST"
        }
    }
}

// MARK: - Issue Category Enum
enum IssueCategory: String, CaseIterable {
    case general = "general"
    case trading = "trading"
    case account = "account"
    case technical = "technical"
    case billing = "billing"
    case security = "security"
    case feature = "feature"
    
    var displayName: String {
        switch self {
        case .general: return "General Question"
        case .trading: return "Trading Issue"
        case .account: return "Account Problem"
        case .technical: return "Technical Issue"
        case .billing: return "Billing Question"
        case .security: return "Security Concern"
        case .feature: return "Feature Request"
        }
    }
}

// MARK: - Priority Enum
enum Priority: String, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .normal: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

// MARK: - Supporting Views

struct ContactMethodCard: View {
    let method: ContactMethod
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: method.icon)
                    .foregroundColor(method.color)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(method.color.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(method.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(method.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(method.availability)
                        .font(.caption2)
                        .foregroundColor(method.color)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                if method == .email {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                } else {
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? method.color.opacity(0.05) : Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? method.color.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SupportInfoCard: View {
    let icon: String
    let title: String
    let content: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(content)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.05))
        )
    }
}

