// Core/Portfolio/Views/AddTradeView.swift
// Clean AddTradeView without conflicts

import SwiftUI

struct AddTradeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    
    @State private var ticker = ""
    @State private var tradeType: TradeType = .stock
    @State private var entryPrice = ""
    @State private var quantity = ""
    @State private var notes = ""
    @State private var strategy = ""
    @State private var selectedStrategy: AddTradeStrategy = .custom
    
    @State private var showingConfirmation = false
    @State private var isValidating = false
    @State private var validationMessage = ""
    @State private var isAddingTrade = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Trade Information") {
                    HStack {
                        Text("Ticker")
                        Spacer()
                        TextField("AAPL", text: $ticker)
                            .textCase(.uppercase)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: ticker) { _, newValue in
                                ticker = newValue.uppercased()
                                validateTicker()
                            }
                    }
                    
                    Picker("Trade Type", selection: $tradeType) {
                        ForEach(TradeType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    HStack {
                        Text("Entry Price")
                        Spacer()
                        TextField("0.00", text: $entryPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("0", text: $quantity)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    if !validationMessage.isEmpty {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section("Strategy") {
                    Picker("Trading Strategy", selection: $selectedStrategy) {
                        ForEach(AddTradeStrategy.allCases, id: \.self) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                    
                    if selectedStrategy == .custom {
                        TextField("Custom strategy description", text: $strategy, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
                
                Section("Notes") {
                    TextField("Trade notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Trade Summary") {
                    if isFormValid {
                        HStack {
                            Text("Total Investment")
                            Spacer()
                            Text("$\(String(format: "%.2f", totalInvestment))")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Position Size")
                            Spacer()
                            Text("\(quantity) shares")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Add Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Trade") {
                        showingConfirmation = true
                    }
                    .disabled(!isFormValid || isAddingTrade)
                    .overlay(
                        Group {
                            if isAddingTrade {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    )
                }
            }
        }
        .confirmationDialog("Confirm Trade", isPresented: $showingConfirmation, titleVisibility: .visible) {
            Button("Add Trade") {
                addTrade()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Add \(quantity) shares of \(ticker) at \(entryPrice.isEmpty ? "$0.00" : "$\(entryPrice)") per share?")
        }
        .alert("Trade Added", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Successfully added \(quantity) shares of \(ticker)")
        }
        .alert("Error", isPresented: $portfolioViewModel.showError) {
            Button("OK") { }
        } message: {
            Text(portfolioViewModel.errorMessage)
        }
    }
    
    private var isFormValid: Bool {
        !ticker.isEmpty &&
        !entryPrice.isEmpty &&
        !quantity.isEmpty &&
        Double(entryPrice) != nil &&
        Int(quantity) != nil &&
        Double(entryPrice)! > 0 &&
        Int(quantity)! > 0 &&
        validationMessage.isEmpty
    }
    
    private var totalInvestment: Double {
        guard let price = Double(entryPrice), let qty = Int(quantity) else { return 0 }
        return price * Double(qty)
    }
    
    private func validateTicker() {
        isValidating = true
        validationMessage = ""
        
        // Basic ticker validation
        if ticker.count > 5 {
            validationMessage = "Ticker too long"
        } else if ticker.contains(where: { !$0.isLetter }) {
            validationMessage = "Ticker should only contain letters"
        }
        
        isValidating = false
    }
    
    private func addTrade() {
        guard let price = Double(entryPrice),
              let qty = Int(quantity) else {
            return
        }
        
        isAddingTrade = true
        
        let finalStrategy = selectedStrategy == .custom ? strategy : selectedStrategy.displayName
        
        portfolioViewModel.addTradeSimple(
            ticker: ticker,
            tradeType: tradeType,
            entryPrice: price,
            quantity: qty,
            notes: notes.isEmpty ? nil : notes
        )
        
        isAddingTrade = false
        
        if !portfolioViewModel.showError {
            showSuccess = true
        }
    }
}

// MARK: - AddTrade Strategy Enum (renamed to avoid conflicts)
enum AddTradeStrategy: CaseIterable {
    case dayTrading
    case swingTrading
    case longTerm
    case momentum
    case valueInvesting
    case technicalAnalysis
    case custom
    
    var displayName: String {
        switch self {
        case .dayTrading: return "Day Trading"
        case .swingTrading: return "Swing Trading"
        case .longTerm: return "Long Term Hold"
        case .momentum: return "Momentum"
        case .valueInvesting: return "Value Investing"
        case .technicalAnalysis: return "Technical Analysis"
        case .custom: return "Custom Strategy"
        }
    }
}

#Preview {
    AddTradeView()
        .environmentObject(AuthViewModel())
        .environmentObject(PortfolioViewModel())
}
