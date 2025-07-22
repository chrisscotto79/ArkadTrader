
// File: Core/Communities/Views/Create/CreateCommunityView.swift
// Beautiful Multi-Step Community Creation View

import SwiftUI

struct CreateCommunityView: View {
    @StateObject private var viewModel = CommunityCreationViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1
    
    private let totalSteps = 4
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.1),
                        Color(.systemGroupedBackground),
                        Color.blue.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Step Progress Indicator
                    progressIndicator
                    
                    // Main Content
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            stepContent
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
                
                // Bottom Action Bar
                VStack {
                    Spacer()
                    actionBar
                }
            }
            .navigationTitle("Create Community")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: EmptyView()
            )
        }
        .alert("Success!", isPresented: $viewModel.showSuccess) {
            Button("Great!") {
                dismiss()
            }
        } message: {
            Text("Your community has been created successfully!")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - Step Progress Indicator
    private var progressIndicator: some View {
        VStack(spacing: 16) {
            HStack {
                ForEach(1...totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .scaleEffect(step == currentStep ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3), value: currentStep)
                    
                    if step < totalSteps {
                        Rectangle()
                            .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 2)
                            .animation(.easeInOut, value: currentStep)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Text(stepTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 1:
            basicInfoStep
        case 2:
            categoryStep
        case 3:
            settingsStep
        case 4:
            reviewStep
        default:
            EmptyView()
        }
    }
    
    // MARK: - Step 1: Basic Info
    private var basicInfoStep: some View {
        VStack(spacing: 24) {
            // Header
            stepHeader(
                title: "Basic Information",
                subtitle: "Give your community a name and description that clearly explains its purpose"
            )
            
            // Community Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Community Name")
                    .font(.headline)
                    .fontWeight(.medium)
                
                TextField("Enter community name", text: $viewModel.name)
                    .textFieldStyle(ModernTextFieldStyle())
                    .overlay(alignment: .trailing) {
                        validationIcon(for: viewModel.nameValidation)
                    }
                
                HStack {
                    if let error = viewModel.nameValidation.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Text(viewModel.nameCharacterCount)
                        .font(.caption)
                        .foregroundColor(viewModel.nameCharacterCountColor)
                }
            }
            
            // Community Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)
                    .fontWeight(.medium)
                
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                        )
                        .frame(height: 100)
                    
                    TextEditor(text: $viewModel.description)
                        .padding(12)
                        .background(Color.clear)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(height: 100)
                    
                    if viewModel.description.isEmpty {
                        Text("Describe what your community is about, what members can expect, and any trading focus areas...")
                            .font(.body)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    validationIcon(for: viewModel.descriptionValidation)
                        .padding(12)
                }
                
                HStack {
                    if let error = viewModel.descriptionValidation.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Text(viewModel.characterCountText)
                        .font(.caption)
                        .foregroundColor(viewModel.characterCountColor)
                }
            }
            
            // Tips Card
            tipsCard([
                "Choose a clear, descriptive name",
                "Explain your trading focus and goals",
                "Mention experience level (beginner/advanced)",
                "Keep it professional and welcoming"
            ])
        }
        .padding(.top, 20)
    }
    
    // MARK: - Step 2: Category Selection
    private var categoryStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                title: "Trading Category",
                subtitle: "Select the primary trading focus that best describes your community"
            )
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(CommunityType.allCases, id: \.self) { type in
                    categoryCard(type)
                }
            }
            
            tipsCard([
                "This helps traders find communities that match their interests",
                "You can discuss other topics, but this is your main focus",
                "Category affects which traders will discover your community"
            ])
        }
        .padding(.top, 20)
    }
    
    private func categoryCard(_ type: CommunityType) -> some View {
        Button(action: { viewModel.type = type }) {
            VStack(spacing: 12) {
                Image(systemName: getCategoryIcon(for: type))
                    .font(.system(size: 32))
                    .foregroundColor(viewModel.type == type ? .white : getCommunityTypeColor(for: type))
                
                Text(type.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.type == type ? .white : .primary)
                
                Text(getCategoryDescription(for: type))
                    .font(.caption)
                    .foregroundColor(viewModel.type == type ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(viewModel.type == type ? getCommunityTypeColor(for: type) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                viewModel.type == type ? getCommunityTypeColor(for: type) : Color.gray.opacity(0.2),
                                lineWidth: 2
                            )
                    )
            )
            .scaleEffect(viewModel.type == type ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: viewModel.type)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Step 3: Settings
    private var settingsStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                title: "Community Settings",
                subtitle: "Configure privacy and other settings for your community"
            )
            
            // Privacy Setting
            VStack(spacing: 16) {
                privacyOption(
                    title: "Public Community",
                    subtitle: "Anyone can find and join your community",
                    icon: "globe",
                    isSelected: !viewModel.isPrivate,
                    action: { viewModel.isPrivate = false }
                )
                
                privacyOption(
                    title: "Private Community",
                    subtitle: "Users must request to join your community",
                    icon: "lock.fill",
                    isSelected: viewModel.isPrivate,
                    action: { viewModel.isPrivate = true }
                )
            }
            
            // Guidelines
            VStack(alignment: .leading, spacing: 16) {
                Text("Community Guidelines")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                ForEach(viewModel.getGuidelines(), id: \.title) { guideline in
                    guidelineRow(guideline)
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .padding(.top, 20)
    }
    
    private func privacyOption(title: String, subtitle: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray.opacity(0.5))
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func guidelineRow(_ guideline: CommunityGuideline) -> some View {
        HStack(spacing: 12) {
            Image(systemName: guideline.icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(guideline.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(guideline.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Step 4: Review
    private var reviewStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                title: "Review & Create",
                subtitle: "Review your community details before creating"
            )
            
            // Community Preview Card
            VStack(spacing: 16) {
                Text("Community Preview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                // Mock Community Card
                HStack(spacing: 16) {
                    Circle()
                        .fill(getCommunityTypeColor(for: viewModel.type))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text(getInitials(from: viewModel.name))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(viewModel.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if viewModel.isPrivate {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Text(viewModel.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        HStack {
                            Text("1 member")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(viewModel.type.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(getCommunityTypeColor(for: viewModel.type))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(getCommunityTypeColor(for: viewModel.type).opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .cornerRadius(16)
            
            // Summary
            VStack(spacing: 12) {
                summaryRow("Name", viewModel.name)
                summaryRow("Category", viewModel.type.displayName)
                summaryRow("Privacy", viewModel.isPrivate ? "Private" : "Public")
                summaryRow("Description", viewModel.description, isMultiline: true)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .padding(.top, 20)
    }
    
    private func summaryRow(_ label: String, _ value: String, isMultiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                if !isMultiline {
                    Spacer()
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            if isMultiline {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            if label != "Description" {
                Divider()
            }
        }
    }
    
    // MARK: - Supporting Views
    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
    }
    
    private func tipsCard(_ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                
                Text("Tips")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(.blue)
                        .fontWeight(.bold)
                    
                    Text(tip)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func validationIcon(for state: ValidationState) -> some View {
        Group {
            switch state {
            case .valid:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .invalid:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            case .none:
                EmptyView()
            }
        }
        .font(.title3)
    }
    
    // MARK: - Bottom Action Bar
    private var actionBar: some View {
        HStack(spacing: 16) {
            if currentStep > 1 {
                Button("Back") {
                    withAnimation(.spring(response: 0.3)) {
                        currentStep -= 1
                    }
                }
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, lineWidth: 2)
                )
            }
            
            Button(currentStep == totalSteps ? "Create Community" : "Next") {
                if currentStep == totalSteps {
                    viewModel.createCommunity()
                } else {
                    withAnimation(.spring(response: 0.3)) {
                        currentStep += 1
                    }
                }
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if currentStep == totalSteps {
                        viewModel.isCreating ? Color.gray : (canProceed ? Color.blue : Color.gray)
                    } else {
                        canProceed ? Color.blue : Color.gray
                    }
                }
            )
            .cornerRadius(12)
            .disabled(!canProceed || (currentStep == totalSteps && viewModel.isCreating))
            .overlay(
                Group {
                    if currentStep == totalSteps && viewModel.isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                }
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemGroupedBackground))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
    }
    
    // MARK: - Computed Properties
    private var stepTitle: String {
        switch currentStep {
        case 1: return "Step 1: Basic Info"
        case 2: return "Step 2: Category"
        case 3: return "Step 3: Settings"
        case 4: return "Step 4: Review"
        default: return ""
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return viewModel.nameValidation.isValid && viewModel.descriptionValidation.isValid
        case 2, 3:
            return true
        case 4:
            return viewModel.isFormValid && !viewModel.isCreating
        default:
            return false
        }
    }
    
    // MARK: - Helper Methods
    private func getCategoryIcon(for type: CommunityType) -> String {
        switch type {
        case .dayTrading: return "chart.line.uptrend.xyaxis"
        case .swingTrading: return "waveform.path"
        case .options: return "arrow.up.arrow.down.circle"
        case .crypto: return "bitcoinsign.circle"
        case .stocks: return "building.columns"
        case .general: return "person.3.fill"
        }
    }
    
    private func getCommunityTypeColor(for type: CommunityType) -> Color {
        switch type {
        case .dayTrading: return .red
        case .swingTrading: return .orange
        case .options: return .purple
        case .crypto: return .yellow
        case .stocks: return .green
        case .general: return .blue
        }
    }
    
    private func getCategoryDescription(for type: CommunityType) -> String {
        switch type {
        case .dayTrading: return "Short-term trades, quick profits"
        case .swingTrading: return "Medium-term position trading"
        case .options: return "Options strategies & analysis"
        case .crypto: return "Digital asset trading"
        case .stocks: return "Equity market investing"
        case .general: return "All trading topics welcome"
        }
    }
    
    private func getInitials(from name: String) -> String {
        if name.isEmpty { return "?" }
        
        let words = name.components(separatedBy: " ")
        if words.count >= 2 {
            let first = String(words[0].prefix(1))
            let second = String(words[1].prefix(1))
            return (first + second).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}

// MARK: - Modern Text Field Style
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    CreateCommunityView()
}
