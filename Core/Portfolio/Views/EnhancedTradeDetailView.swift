// File: Core/Portfolio/Views/EnhancedAddTradeView.swift
// Enhanced Add Trade View with stocks and options support

import SwiftUI

struct EnhancedAddTradeView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    // Basic Trade Info
    @State private var ticker = ""
    @State private var tradeType: TradeType = .stock
    @State private var entryPrice = ""
    @State private var quantity = ""
    @State private var entryDate = Date()
    
    // Options-specific fields
    @State private var optionType: OptionType = .call
    @State private var strikePrice = ""
    @State private var expirationDate = Date()
    
    // Additional Info
    @State private var strategy = ""
    @State private var notes = ""
    
    // UI State
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Trade Type Selection
                    tradeTypeSection
                    
                    // Basic Trade Information
                    basicTradeInfoSection
                    
                    // Options-specific fields (only shown for options)
                    if tradeType == .option {
                        optionsInfoSection
                    }
                    
                    // Additional Information
                    additionalInfoSection
                    
                    // Add Trade Button
                    addTradeButton
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Add Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task { await addTrade() }
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .alert("Trade Added", isPresented: $showAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Trade Type Section
    private var tradeTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trade Type")
                .font(.headline)
                .fontWeight(.semibold)
            
            Picker("Trade Type", selection: $tradeType) {
                ForEach(TradeType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.icon)
                        Text(type.displayName)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: tradeType) { _ in
                // Clear options-specific fields when switching away from options
                if tradeType != .option {
                    strikePrice = ""
                    expirationDate = Date()
                }
            }
        }
    }
    
    // MARK: - Basic Trade Info Section
    private var basicTradeInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trade Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Ticker Symbol
                FormField(
                    title: "Ticker Symbol",
                    text: $ticker,
                    placeholder: "AAPL",
                    keyboardType: .default,
                    autocapitalization: true
                )
                
                // Entry Price
                FormField(
                    title: "Entry Price",
                    text: $entryPrice,
                    placeholder: "150.00",
                    keyboardType: .decimalPad,
                    prefix: "$"
                )
                
                // Quantity
                FormField(
                    title: tradeType == .option ? "Contracts" : "Shares",
                    text: $quantity,
                    placeholder: tradeType == .option ? "10" : "100",
                    keyboardType: .numberPad
                )
                
                // Entry Date
                VStack(alignment: .leading, spacing: 8) {
                    Text("Entry Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    DatePicker("Entry Date", selection: $entryDate, displayedComponents: [.date])
                        .datePickerStyle(CompactDatePickerStyle())
                }
            }
        }
    }
    
    // MARK: - Options Info Section
    private var optionsInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Options Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Option Type (Call/Put)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Option Type")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Option Type", selection: $optionType) {
                        ForEach(OptionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Strike Price
                FormField(
                    title: "Strike Price",
                    text: $strikePrice,
                    placeholder: "155.00",
                    keyboardType: .decimalPad,
                    prefix: "$"
                )
                
                // Expiration Date
                VStack(alignment: .leading, spacing: 8) {
                    Text("Expiration Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    DatePicker("Expiration Date", selection: $expirationDate, in: Date()..., displayedComponents: [.date])
                        .datePickerStyle(CompactDatePickerStyle())
                }
            }
        }
    }
    
    // MARK: - Additional Info Section
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Strategy
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trading Strategy (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("e.g., Swing trading, Day trading, Long-term hold", text: $strategy)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Add any notes about this trade...", text: $notes, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(3...6)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Add Trade Button
    private var addTradeButton: some View {
        Button(action: {
            Task { await addTrade() }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Adding Trade...")
                } else {
                    Image(systemName: "plus.circle")
                    Text("Add Trade")
                }
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isFormValid && !isLoading ? Color.blue : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!isFormValid || isLoading)
    }
    
    // MARK: - Form Validation
    private var isFormValid: Bool {
        let basicValid = !ticker.isEmpty &&
                        !entryPrice.isEmpty &&
                        !quantity.isEmpty &&
                        Double(entryPrice) != nil &&
                        Int(quantity) != nil
        
        if tradeType == .option {
            let optionsValid = !strikePrice.isEmpty &&
                              Double(strikePrice) != nil &&
                              expirationDate > Date()
            return basicValid && optionsValid
        }
        
        return basicValid
    }
    
    // MARK: - Add Trade Function
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
        
        // Set entry date
        newTrade.entryDate = entryDate
        
        // Add strategy if provided
        if !strategy.isEmpty {
            newTrade.strategy = strategy
        }
        
        // Add notes if provided
        if !notes.isEmpty {
            newTrade.notes = notes
        }
        
        // For options, add additional info to notes
        if tradeType == .option {
            if let strike = Double(strikePrice) {
                let optionInfo = "\(optionType.displayName) option, Strike: $\(String(format: "%.2f", strike)), Exp: \(formatDate(expirationDate))"
                newTrade.notes = newTrade.notes?.isEmpty == false ?
                    "\(newTrade.notes!)\n\n\(optionInfo)" : optionInfo
            }
        }
        
        do {
            try await authService.addTrade(newTrade)
            alertMessage = "Trade added successfully!"
            showAlert = true
            
            // Refresh portfolio data
            portfolioViewModel.loadPortfolioData()
            
        } catch {
            alertMessage = "Failed to add trade: \(error.localizedDescription)"
            showAlert = true
        }
        
        isLoading = false
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views and Types

struct FormField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: Bool = false
    var prefix: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                if let prefix = prefix {
                    Text(prefix)
                        .foregroundColor(.gray)
                }
                
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .keyboardType(keyboardType)
                    .autocapitalization(autocapitalization ? .allCharacters : .none)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

enum OptionType: CaseIterable {
    case call, put
    
    var displayName: String {
        switch self {
        case .call: return "Call"
        case .put: return "Put"
        }
    }
}

#Preview {
    EnhancedAddTradeView()
        .environmentObject(FirebaseAuthService.shared)
        .environmentObject(PortfolioViewModel())
}
