// File: Core/Portfolio/Views/AddTradeView.swift
// Step-by-step form for logging a stock or options trade.

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
    
    // Stock-specific fields
    @State private var stopLossPrice = ""
    @State private var takeProfitPrice = ""
    @State private var sector = ""
    
    // Option-specific fields
    @State private var optionType: TradeOptionType = .call
    @State private var strikePrice = ""
    @State private var expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
    @State private var premium = ""
    @State private var contracts = ""
    
    // Additional Info
    @State private var strategy = ""
    @State private var notes = ""
    /// Public trades appear on the user's profile and in followers' Following feed.
    @State private var isPublic = true
    
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
                                tradeSpecificDetailsForm
                            case 3:
                                riskManagementForm
                            case 4:
                                additionalDetailsForm
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
                
                // Next / Add Button
                Button(action: {
                    if currentStep == maxSteps {
                        Task { await addTrade() }
                    } else {
                        nextStep()
                    }
                }) {
                    Text(currentStep == maxSteps ? "Add" : "Next")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(canProceed ? .arkadGold : .gray)
                }
                .disabled(!canProceed || isLoading)
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
                ForEach(supportedTradeTypes, id: \.self) { type in
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
                resetTradeSpecificFields()
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
    
    // MARK: - Trade Specific Details Form (Step 2)
    @ViewBuilder
    private var tradeSpecificDetailsForm: some View {
        switch tradeType {
        case .option:
            optionDetailsForm
        default:
            stockDetailsForm
        }
    }
    
    // MARK: - Stock Details Form
    private var stockDetailsForm: some View {
        VStack(spacing: 24) {
            formHeader(
                title: "Stock Details",
                subtitle: "Enter your stock trade information"
            )
            
            VStack(spacing: 20) {
                modernTextField(
                    title: "Stock Symbol",
                    text: $ticker,
                    placeholder: "AAPL",
                    icon: "chart.line.uptrend.xyaxis",
                    focused: $tickerFocused,
                    textCase: .uppercase
                )
                
                HStack(spacing: 16) {
                    modernTextField(
                        title: "Shares",
                        text: $quantity,
                        placeholder: "100",
                        icon: "number.circle.fill",
                        focused: $quantityFocused,
                        keyboardType: .numberPad
                    )
                    
                    modernTextField(
                        title: "Entry Price",
                        text: $entryPrice,
                        placeholder: "150.00",
                        icon: "dollarsign.circle.fill",
                        focused: $priceFocused,
                        keyboardType: .decimalPad,
                        prefix: "$"
                    )
                }
                
                modernTextField(
                    title: "Sector (Optional)",
                    text: $sector,
                    placeholder: "Technology, Healthcare, etc.",
                    icon: "building.2"
                )
                
                entryDateField
                
                validationMessageView
            }
        }
    }
    
    // MARK: - Option Details Form
    private var optionDetailsForm: some View {
        VStack(spacing: 24) {
            formHeader(
                title: "Options Contract",
                subtitle: "Specify your options contract details"
            )
            
            VStack(spacing: 20) {
                modernTextField(
                    title: "Underlying Symbol",
                    text: $ticker,
                    placeholder: "AAPL",
                    icon: "chart.line.uptrend.xyaxis",
                    textCase: .uppercase
                )
                
                optionTypeSelector
                
                HStack(spacing: 16) {
                    modernTextField(
                        title: "Strike Price",
                        text: $strikePrice,
                        placeholder: "155.00",
                        icon: "target",
                        keyboardType: .decimalPad,
                        prefix: "$"
                    )
                    
                    modernTextField(
                        title: "Cost per Contract",
                        text: $premium,
                        placeholder: "550.00",
                        icon: "dollarsign.circle",
                        keyboardType: .decimalPad,
                        prefix: "$"
                    )
                }
                
                Text("Enter what one contract cost (quoted premium × 100, e.g. 5.50 → 550). Use the same basis when you close the trade.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                modernTextField(
                    title: "Contracts",
                    text: $contracts,
                    placeholder: "10",
                    icon: "doc.text",
                    keyboardType: .numberPad
                )
                
                modernDatePickerField(
                    title: "Expiration Date",
                    date: $expirationDate,
                    icon: "timer.circle.fill"
                )
                
                entryDateField
                
                validationMessageView
            }
        }
    }
    
    // MARK: - Entry Date & Validation
    private var entryDateField: some View {
        modernDatePickerField(
            title: "Entry Date",
            date: $entryDate,
            icon: "calendar",
            range: ...Date()
        )
    }
    
    @ViewBuilder
    private var validationMessageView: some View {
        if let message = detailsValidationMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                Text(message)
                    .font(.caption)
                Spacer(minLength: 0)
            }
            .foregroundColor(.marketRed)
        }
    }
    
    // MARK: - Risk Management Form (Step 3)
    private var riskManagementForm: some View {
        VStack(spacing: 24) {
            formHeader(
                title: "Risk Management",
                subtitle: "Set your stop loss and take profit levels (optional)"
            )
            
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    modernTextField(
                        title: "Stop Loss",
                        text: $stopLossPrice,
                        placeholder: entryPriceHint(-5),
                        icon: "shield.fill",
                        keyboardType: .decimalPad,
                        prefix: "$"
                    )
                    
                    modernTextField(
                        title: "Take Profit",
                        text: $takeProfitPrice,
                        placeholder: entryPriceHint(10),
                        icon: "target",
                        keyboardType: .decimalPad,
                        prefix: "$"
                    )
                }
                
                if let entryPriceValue = parsedEntryPrice,
                   let stopLossValue = Double(stopLossPrice),
                   let takeProfitValue = Double(takeProfitPrice) {
                    riskRewardCalculator(
                        entryPrice: entryPriceValue,
                        stopLoss: stopLossValue,
                        takeProfit: takeProfitValue
                    )
                }
            }
        }
    }
    
    // MARK: - Additional Details Form (Step 4)
    private var additionalDetailsForm: some View {
        VStack(spacing: 24) {
            formHeader(
                title: "Additional Details",
                subtitle: "Add context to your trade (optional)"
            )
            
            VStack(spacing: 20) {
                modernTextField(
                    title: "Trading Strategy",
                    text: $strategy,
                    placeholder: "e.g., Swing Trading, Breakout",
                    icon: "lightbulb.circle.fill"
                )
                
                modernTextEditor(
                    title: "Notes",
                    text: $notes,
                    placeholder: "Add any notes about this trade...",
                    icon: "note.text"
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $isPublic) {
                        HStack {
                            Image(systemName: "eye")
                                .foregroundColor(.arkadGold)
                            Text("Show on my profile")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    .tint(.arkadGold)
                    
                    Text("Public trades appear on your profile and in your followers' Following feed.")
                        .font(.caption)
                        .foregroundColor(.gray)
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
    
    // MARK: - Confirmation View (Step 5)
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
            tradeSummaryCard
        }
    }
    
    // MARK: - Supporting Views
    
    private func formHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    private var optionTypeSelector: some View {
        modernSegmentedControl(
            title: "Option Type",
            selection: Binding(
                get: { optionType.displayName },
                set: { newValue in
                    if let type = TradeOptionType.allCases.first(where: { $0.displayName == newValue }) {
                        optionType = type
                    }
                }
            ),
            options: TradeOptionType.allCases.map(\.displayName),
            icon: "arrow.up.arrow.down.circle"
        )
    }
    
    private var tradeSummaryCard: some View {
        VStack(spacing: 16) {
            tradeSummaryRow("Symbol", displayTicker, tradeType.icon)
            tradeSummaryRow("Type", tradeType.displayName, "tag")
            tradeSummaryRow(tradeType == .option ? "Cost per Contract" : "Price", "$\(entryPriceText)", "dollarsign.circle")
            tradeSummaryRow(quantityLabel, quantityText, "number.circle")
            tradeSummaryRow("Entry Date", formatDate(entryDate), "calendar")
            
            if tradeType == .option {
                tradeSummaryRow("Option Type", optionType.displayName, optionType.icon)
                if !strikePrice.isEmpty {
                    tradeSummaryRow("Strike", "$\(strikePrice)", "target")
                }
                tradeSummaryRow("Expires", formatDate(expirationDate), "timer")
            }
            
            if !stopLossPrice.isEmpty {
                tradeSummaryRow("Stop Loss", "$\(stopLossPrice)", "shield.fill")
            }
            
            if !takeProfitPrice.isEmpty {
                tradeSummaryRow("Take Profit", "$\(takeProfitPrice)", "target")
            }
            
            if !strategy.isEmpty {
                tradeSummaryRow("Strategy", strategy, "lightbulb.circle")
            }
            
            tradeSummaryRow("Visibility", isPublic ? "On your profile" : "Only you", isPublic ? "eye" : "eye.slash")
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .gray.opacity(0.1), radius: 8, x: 0, y: 4)
        )
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
    
    private func riskRewardCalculator(entryPrice: Double, stopLoss: Double, takeProfit: Double) -> some View {
        let risk = abs(entryPrice - stopLoss)
        let reward = abs(takeProfit - entryPrice)
        let ratio = risk > 0 ? reward / risk : 0
        
        return VStack(spacing: 12) {
            Text("Risk/Reward Analysis")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                VStack {
                    Text("Risk")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("$\(risk, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                
                VStack {
                    Text("Reward")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("$\(reward, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                VStack {
                    Text("Ratio")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("1:\(ratio, specifier: "%.1f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ratio >= 2 ? .green : .orange)
                }
            }
            .padding(16)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Modern UI Components
    
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
    
    private func modernTextEditor(
        title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.arkadGold)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.05))
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    .frame(minHeight: 100)
                
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.gray)
                        .padding(16)
                }
                
                TextEditor(text: text)
                    .padding(12)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
            }
        }
    }
    
    private func modernSegmentedControl(
        title: String,
        selection: Binding<String>,
        options: [String],
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.arkadGold)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection.wrappedValue = option
                        }
                    }) {
                        Text(option)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selection.wrappedValue == option ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selection.wrappedValue == option ? Color.arkadGold : Color.clear)
                            )
                    }
                }
            }
            .background(Color.gray.opacity(0.05))
            .cornerRadius(16)
        }
    }
    
    private func modernDatePickerField(
        title: String,
        date: Binding<Date>,
        icon: String,
        range: PartialRangeThrough<Date>? = nil
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.arkadGold)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            if let range = range {
                DatePicker("", selection: date, in: range, displayedComponents: .date)
                    .labelsHidden()
                    .tint(.arkadGold)
            } else {
                DatePicker("", selection: date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(.arkadGold)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
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
    private var maxSteps: Int { 5 }
    
    /// Every asset type can be logged; quantities may be fractional (except option contracts).
    private var supportedTradeTypes: [TradeType] { TradeType.allCases }
    
    private var canProceed: Bool {
        switch currentStep {
        case 1: return supportedTradeTypes.contains(tradeType)
        default: return detailsValidationMessage == nil
        }
    }
    
    /// Raw entry-price text for the current asset type (options use the cost per contract).
    private var entryPriceText: String {
        tradeType == .option ? premium : entryPrice
    }
    
    /// Raw quantity text for the current asset type (options use contracts).
    private var quantityText: String {
        tradeType == .option ? contracts : quantity
    }
    
    private var parsedEntryPrice: Double? {
        let cleaned = entryPriceText
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }
    
    private var parsedQuantity: Double? {
        let cleaned = quantityText
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned), value > 0 else { return nil }
        // Option contracts are always whole numbers
        if tradeType == .option && value.rounded() != value { return nil }
        return value
    }
    
    /// Why the step-2 details can't be saved yet, or nil when they're valid.
    private var detailsValidationMessage: String? {
        let symbol = ticker.trimmingCharacters(in: .whitespaces)
        let isOption = tradeType == .option
        if symbol.isEmpty {
            return isOption ? "Enter the underlying symbol." : "Enter a stock symbol."
        }
        if quantityText.isEmpty {
            return isOption ? "Enter the number of contracts." : "Enter the number of shares."
        }
        if parsedQuantity == nil {
            return isOption ? "Contracts must be a whole number above 0." : "Shares must be a whole number above 0."
        }
        if entryPriceText.isEmpty {
            return isOption ? "Enter the cost per contract." : "Enter the entry price."
        }
        if parsedEntryPrice == nil {
            return "Price must be a number above 0."
        }
        if isOption {
            if !strikePrice.isEmpty && (Double(strikePrice) ?? 0) <= 0 {
                return "Strike price must be a number above 0."
            }
        }
        return nil
    }
    
    private var quantityLabel: String {
        tradeType == .option ? "Contracts" : "Shares"
    }
    
    private var displayTicker: String {
        ticker.trimmingCharacters(in: .whitespaces).uppercased()
    }
    
    private func entryPriceHint(_ percentage: Double) -> String {
        guard let price = parsedEntryPrice else { return "" }
        let adjustedPrice = price * (1 + percentage / 100)
        return String(format: "%.2f", adjustedPrice)
    }
    
    private func resetTradeSpecificFields() {
        quantity = ""
        entryPrice = ""
        stopLossPrice = ""
        takeProfitPrice = ""
        
        // Reset type-specific fields
        strikePrice = ""
        premium = ""
        contracts = ""
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
        guard !isLoading else { return }
        guard let userId = authService.currentUser?.id else {
            alertMessage = "You need to be signed in to add a trade."
            showAlert = true
            return
        }
        if let problem = detailsValidationMessage {
            alertMessage = problem
            showAlert = true
            return
        }
        guard let price = parsedEntryPrice, let finalQuantity = parsedQuantity else {
            alertMessage = "Check the price and quantity and try again."
            showAlert = true
            return
        }
        
        isLoading = true
        
        var newTrade = Trade(
            ticker: displayTicker,
            tradeType: tradeType,
            entryPrice: price,
            quantity: finalQuantity,
            userId: userId
        )
        
        newTrade.entryDate = entryDate
        newTrade.isPublic = isPublic
        if !strategy.isEmpty { newTrade.strategy = strategy }
        
        // Options keep their contract details in the notes
        var noteParts: [String] = []
        if tradeType == .option {
            var contractLine = optionType.displayName.uppercased()
            if let strike = Double(strikePrice), strike > 0 {
                contractLine += " · Strike \(strike.asCurrency)"
            }
            contractLine += " · Expires \(formatDate(expirationDate))"
            noteParts.append(contractLine)
        }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty { noteParts.append(trimmedNotes) }
        if !noteParts.isEmpty { newTrade.notes = noteParts.joined(separator: "\n\n") }
        
        // Add stop loss and take profit if provided
        if let stopLoss = Double(stopLossPrice), stopLoss > 0 {
            newTrade.setStopLoss(stopLoss)
        }
        if let takeProfit = Double(takeProfitPrice), takeProfit > 0 {
            newTrade.setTakeProfit(takeProfit)
        }
        
        // Add sector for stocks
        if tradeType == .stock && !sector.isEmpty {
            newTrade.sector = sector
        }
        
        do {
            try await authService.addTrade(newTrade)
            alertMessage = "Trade added successfully."
            showAlert = true
            portfolioViewModel.loadPortfolioData()
        } catch {
            alertMessage = "Failed to add trade: \(error.localizedDescription)"
            showAlert = true
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Enums (Keep your existing ones)

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
