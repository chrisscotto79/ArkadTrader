// File: Core/Portfolio/Views/AddTradeView.swift
// Modern Add Trade View with Beautiful UI

import SwiftUI

struct AddTradeView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    // Basic Trade Info
    @State private var ticker = ""
    @State private var tradeType: TradeType = .stock
    @State private var entryPrice = ""
    @State private var quantity = ""
    @State private var entryDate = Date()
    
    // Options specific
    @State private var optionType: TradeOptionType = .call
    @State private var strikePrice = ""
    @State private var expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
    
    // Additional Info
    @State private var strategy = ""
    @State private var notes = ""
    
    // UI State
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var currentStep = 1
    
    // Focus states
    @FocusState private var tickerFocused: Bool
    @FocusState private var priceFocused: Bool
    @FocusState private var quantityFocused: Bool
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color.arkadGold.opacity(0.05),
                    Color.white,
                    Color.arkadGold.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Header
                modernHeader
                
                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Progress Steps
                        progressIndicator
                        
                        // Main Content based on current step
                        Group {
                            switch currentStep {
                            case 1:
                                tradeTypeSelection
                            case 2:
                                tradeDetailsForm
                            case 3:
                                if tradeType == .option {
                                    optionsDetailsForm
                                } else {
                                    additionalDetailsForm
                                }
                            case 4:
                                if tradeType == .option {
                                    additionalDetailsForm
                                } else {
                                    confirmationView
                                }
                            case 5:
                                confirmationView
                            default:
                                tradeTypeSelection
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                
                // Bottom Action Area
                bottomActionArea
            }
        }
        .navigationBarHidden(true)
        .alert("Trade Status", isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("successfully") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Modern Header
    private var modernHeader: some View {
        VStack(spacing: 0) {
            HStack {
                // Cancel Button
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Title with animated step indicator
                VStack(spacing: 4) {
                    Text("Add Trade")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Step \(currentStep) of \(maxSteps)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .opacity(0.8)
                }
                
                Spacer()
                
                // Skip/Next Button
                Button(action: nextStep) {
                    Text(currentStep == maxSteps ? "Done" : "Next")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(canProceed ? .arkadGold : .gray)
                }
                .disabled(!canProceed)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Thin separator
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1)
        }
        .background(Color.white.opacity(0.95))
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: 12) {
            ForEach(1...maxSteps, id: \.self) { step in
                ZStack {
                    Circle()
                        .fill(step <= currentStep ? Color.arkadGold : Color.gray.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    if step < currentStep {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(step)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(step == currentStep ? .white : .gray)
                    }
                }
                .scaleEffect(step == currentStep ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                
                if step < maxSteps {
                    Rectangle()
                        .fill(step < currentStep ? Color.arkadGold : Color.gray.opacity(0.2))
                        .frame(height: 2)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Trade Type Selection (Step 1)
    private var tradeTypeSelection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Select Trade Type")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Choose the type of asset you're trading")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(TradeType.allCases, id: \.self) { type in
                    modernTradeTypeCard(for: type)
                }
            }
        }
    }
    
    private func modernTradeTypeCard(for type: TradeType) -> some View {
        let isSelected = tradeType == type
        
        return Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                tradeType = type
            }
        }) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected ?
                            LinearGradient(colors: [type.color, type.color.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? .white : type.color)
                }
                
                VStack(spacing: 4) {
                    Text(type.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: isSelected ? type.color.opacity(0.2) : Color.gray.opacity(0.08), radius: isSelected ? 12 : 6, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? type.color.opacity(0.3) : Color.clear, lineWidth: 2)
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }
    
    // MARK: - Trade Details Form (Step 2)
    private var tradeDetailsForm: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Trade Details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Enter your \(tradeType.displayName.lowercased()) trade information")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                // Ticker Symbol
                modernTextField(
                    title: "Ticker Symbol",
                    text: $ticker,
                    placeholder: "AAPL",
                    icon: "chart.line.uptrend.xyaxis",
                    focused: $tickerFocused,
                    keyboardType: .default,
                    textCase: .uppercase
                )
                
                HStack(spacing: 16) {
                    // Entry Price
                    modernTextField(
                        title: "Entry Price",
                        text: $entryPrice,
                        placeholder: "150.00",
                        icon: "dollarsign.circle.fill",
                        focused: $priceFocused,
                        keyboardType: .decimalPad,
                        prefix: "$"
                    )
                    
                    // Quantity
                    modernTextField(
                        title: tradeType == .option ? "Contracts" : "Shares",
                        text: $quantity,
                        placeholder: tradeType == .option ? "10" : "100",
                        icon: "number.circle.fill",
                        focused: $quantityFocused,
                        keyboardType: .numberPad
                    )
                }
                
                // Entry Date Card
                modernDateCard(
                    title: "Entry Date",
                    date: entryDate,
                    icon: "calendar.circle.fill"
                ) {
                    // Date picker action - for now just show current date
                }
            }
        }
    }
    
    // MARK: - Options Details Form (Step 3 for options)
    private var optionsDetailsForm: some View {
        VStack(spacing: 24) {
            optionsDetailsHeader
            optionFormFields
        }
    }

    private var optionsDetailsHeader: some View {
        VStack(spacing: 12) {
            Text("Options Details")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Specify your options contract details")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }

    private var optionFormFields: some View {
        VStack(spacing: 20) {
            optionTypeSelector

            modernTextField(
                title: "Strike Price",
                text: $strikePrice,
                placeholder: "155.00",
                icon: "target",
                keyboardType: .decimalPad,
                prefix: "$"
            )

            modernDateCard(
                title: "Expiration Date",
                date: expirationDate,
                icon: "timer.circle.fill"
            ) {
                // Optional expiration date picker action
            }
        }
    }

    private var optionTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .foregroundColor(.arkadGold)
                Text("Option Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            HStack(spacing: 12) {
                ForEach(TradeOptionType.allCases, id: \.self) { type in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            optionType = type
                        }
                    }) {
                        HStack {
                            Image(systemName: type.icon)
                            Text(type.displayName)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(optionType == type ? .white : type.color)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(optionType == type ? type.color : Color.gray.opacity(0.1))
                        )
                    }
                }

                Spacer()
            }
        }
    }
    
    // MARK: - Additional Details Form
    private var additionalDetailsForm: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Additional Details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Add context to your trade (optional)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                // Strategy
                modernTextField(
                    title: "Trading Strategy",
                    text: $strategy,
                    placeholder: "e.g., Swing Trading, Day Trading",
                    icon: "lightbulb.circle.fill",
                    keyboardType: .default
                )
                
                // Notes
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.arkadGold)
                        Text("Notes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.05))
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                            .frame(minHeight: 100)
                        
                        TextField("Add any notes about this trade...", text: $notes, axis: .vertical)
                            .padding(16)
                            .lineLimit(4...8)
                    }
                }
            }
        }
    }
    
    // MARK: - Confirmation View
    private var confirmationView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("Review Your Trade")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Double-check the details before adding")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            // Trade Summary Card
            VStack(spacing: 16) {
                tradeSummaryRow("Symbol", ticker.uppercased(), "chart.line.uptrend.xyaxis")
                tradeSummaryRow("Type", tradeType.displayName, tradeType.icon)
                tradeSummaryRow("Price", "$\(entryPrice)", "dollarsign.circle.fill")
                tradeSummaryRow(tradeType == .option ? "Contracts" : "Shares", quantity, "number.circle.fill")
                
                if tradeType == .option {
                    tradeSummaryRow("Option Type", optionType.displayName, optionType.icon)
                    tradeSummaryRow("Strike", "$\(strikePrice)", "target")
                }
                
                if !strategy.isEmpty {
                    tradeSummaryRow("Strategy", strategy, "lightbulb.circle.fill")
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .gray.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
    }
    
    private func tradeSummaryRow(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.arkadGold)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Modern Text Field
    private func modernTextField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        focused: FocusState<Bool>.Binding? = nil,
        keyboardType: UIKeyboardType = .default,
        textCase: Text.Case? = nil,
        prefix: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.arkadGold)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack {
                if let prefix = prefix {
                    Text(prefix)
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }
                
                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .textCase(textCase)
                    .focused(focused ?? FocusState<Bool>().projectedValue)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.05))
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Modern Date Card
    private func modernDateCard(title: String, date: Date, icon: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.arkadGold)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Button(action: action) {
                HStack {
                    Text(formatDate(date))
                        .foregroundColor(.primary)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.05))
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Bottom Action Area
    private var bottomActionArea: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1)
            
            HStack(spacing: 16) {
                if currentStep > 1 {
                    Button(action: previousStep) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if currentStep == maxSteps {
                        Task { await addTrade() }
                    } else {
                        nextStep()
                    }
                }) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(currentStep == maxSteps ? "Add Trade" : "Continue")
                            .fontWeight(.semibold)
                        
                        if currentStep < maxSteps {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                canProceed ?
                                LinearGradient(colors: [Color.arkadGold, Color.arkadGold.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color.gray, Color.gray], startPoint: .leading, endPoint: .trailing)
                            )
                    )
                    .shadow(color: canProceed ? .arkadGold.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
                .disabled(!canProceed || isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.95))
        }
    }
}

// MARK: - Helper Methods and Computed Properties
extension AddTradeView {
    private var maxSteps: Int {
        return tradeType == .option ? 5 : 4
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 1: return true // Can always proceed from trade type selection
        case 2: return !ticker.isEmpty && !entryPrice.isEmpty && !quantity.isEmpty &&
                       Double(entryPrice) != nil && Int(quantity) != nil
        case 3:
            if tradeType == .option {
                return !strikePrice.isEmpty && Double(strikePrice) != nil
            } else {
                return true // Additional details are optional
            }
        case 4, 5: return true
        default: return false
        }
    }
    
    private func nextStep() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = min(currentStep + 1, maxSteps)
        }
    }
    
    private func previousStep() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = max(currentStep - 1, 1)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    @MainActor
    private func addTrade() async {
        guard let userId = authService.currentUser?.id,
              let price = Double(entryPrice),
              let qty = Int(quantity) else { return }
        
        isLoading = true
        
        var newTrade = Trade(
            ticker: ticker.uppercased(),
            tradeType: tradeType,
            entryPrice: price,
            quantity: qty,
            userId: userId
        )
        
        newTrade.entryDate = entryDate
        if !strategy.isEmpty { newTrade.strategy = strategy }
        if !notes.isEmpty { newTrade.notes = notes }
        
        do {
            try await authService.addTrade(newTrade)
            alertMessage = "Trade added successfully! 🎉"
            showAlert = true
            portfolioViewModel.loadPortfolioData()
        } catch {
            alertMessage = "Failed to add trade: \(error.localizedDescription)"
            showAlert = true
        }
        
        isLoading = false
    }
}

// MARK: - Extensions
extension TradeType {
    var icon: String {
        switch self {
        case .stock: return "chart.line.uptrend.xyaxis"
        case .option: return "timer"
        case .crypto: return "bitcoinsign.circle"
        case .forex: return "dollarsign.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .stock: return .blue
        case .option: return .purple
        case .crypto: return .orange
        case .forex: return .green
        }
    }
    
    var description: String {
        switch self {
        case .stock: return "Equity shares"
        case .option: return "Call & Put contracts"
        case .crypto: return "Digital currency"
        case .forex: return "Currency pairs"
        }
    }
}

enum TradeOptionType: CaseIterable {
    case call, put
    
    var displayName: String {
        switch self {
        case .call: return "Call"
        case .put: return "Put"
        }
    }
    
    var icon: String {
        switch self {
        case .call: return "arrow.up.circle.fill"
        case .put: return "arrow.down.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .call: return .green
        case .put: return .red
        }
    }
}

#Preview {
    AddTradeView()
        .environmentObject(FirebaseAuthService.shared)
        .environmentObject(PortfolioViewModel())
}
