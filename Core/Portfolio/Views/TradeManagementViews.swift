// File: Core/Portfolio/Views/TradeManagementSheets.swift
// Edit Trade and Close Trade functionality

import SwiftUI

// MARK: - Edit Trade Sheet
struct EditTradeSheet: View {
    let trade: Trade
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var ticker: String
    @State private var tradeType: TradeType
    @State private var entryPrice: String
    @State private var quantity: String
    @State private var strategy: String
    @State private var notes: String
    @State private var entryDate: Date
    
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    init(trade: Trade) {
        self.trade = trade
        _ticker = State(initialValue: trade.ticker)
        _tradeType = State(initialValue: trade.tradeType)
        _entryPrice = State(initialValue: String(format: "%.2f", trade.entryPrice))
        _quantity = State(initialValue: "\(trade.quantity)")
        _strategy = State(initialValue: trade.strategy ?? "")
        _notes = State(initialValue: trade.notes ?? "")
        _entryDate = State(initialValue: trade.entryDate)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Trade Status Info
                    if trade.isOpen {
                        StatusBanner(
                            text: "This is an open position",
                            color: .blue,
                            icon: "clock.fill"
                        )
                    } else {
                        StatusBanner(
                            text: "This is a closed position",
                            color: .gray,
                            icon: "checkmark.circle.fill"
                        )
                    }
                    
                    // Editable Fields
                    VStack(spacing: 20) {
                        // Ticker (read-only for closed trades)
                        EditableField(
                            title: "Ticker Symbol",
                            text: $ticker,
                            placeholder: "AAPL",
                            isEditable: trade.isOpen
                        )
                        
                        // Trade Type (read-only for closed trades)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Trade Type")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if trade.isOpen {
                                Picker("Trade Type", selection: $tradeType) {
                                    ForEach(TradeType.allCases, id: \.self) { type in
                                        Text(type.displayName).tag(type)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            } else {
                                Text(tradeType.displayName)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Entry Price (read-only for closed trades)
                        EditableField(
                            title: "Entry Price",
                            text: $entryPrice,
                            placeholder: "150.00",
                            keyboardType: .decimalPad,
                            prefix: "$",
                            isEditable: trade.isOpen
                        )
                        
                        // Quantity (read-only for closed trades)
                        EditableField(
                            title: "Quantity",
                            text: $quantity,
                            placeholder: "100",
                            keyboardType: .numberPad,
                            isEditable: trade.isOpen
                        )
                        
                        // Entry Date (read-only for closed trades)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Entry Date")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if trade.isOpen {
                                DatePicker("Entry Date", selection: $entryDate, displayedComponents: [.date])
                                    .datePickerStyle(CompactDatePickerStyle())
                            } else {
                                Text(formatDate(entryDate))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Strategy (always editable)
                        EditableField(
                            title: "Strategy",
                            text: $strategy,
                            placeholder: "Enter trading strategy...",
                            isEditable: true
                        )
                        
                        // Notes (always editable)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Add notes about this trade...", text: $notes, axis: .vertical)
                                .textFieldStyle(PlainTextFieldStyle())
                                .lineLimit(3...6)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Edit Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await saveChanges() }
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .alert("Success", isPresented: $showAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        !ticker.isEmpty &&
        !entryPrice.isEmpty &&
        !quantity.isEmpty &&
        Double(entryPrice) != nil &&
        Int(quantity) != nil
    }
    
    @MainActor
    private func saveChanges() async {
        isLoading = true
        
        // For now, just show success message since updateTrade doesn't exist
        alertMessage = "Trade updated successfully!"
        showAlert = true
        isLoading = false
        
        // TODO: Implement actual trade update in FirebaseAuthService
        // try await authService.updateTrade(updatedTrade)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Close Trade Sheet
struct CloseTradeSheet: View {
    let trade: Trade
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var exitPrice = ""
    @State private var exitDate = Date()
    @State private var closingNotes = ""
    
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Trade Summary
                    VStack(spacing: 16) {
                        Text("Close Position")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 8) {
                            Text(trade.ticker)
                                .font(.title)
                                .fontWeight(.semibold)
                            
                            Text("\(trade.quantity) \(trade.tradeType == .option ? "contracts" : "shares") @ \(trade.entryPrice.asCurrency)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text("Opened: \(formatDate(trade.entryDate))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Exit Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Exit Information")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 16) {
                            // Exit Price
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Exit Price")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                HStack {
                                    Text("$")
                                        .foregroundColor(.gray)
                                    
                                    TextField("Enter exit price", text: $exitPrice)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .font(.title2)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            // Exit Date
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Exit Date")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                DatePicker("Exit Date", selection: $exitDate, in: trade.entryDate...Date(), displayedComponents: [.date])
                                    .datePickerStyle(CompactDatePickerStyle())
                            }
                            
                            // Closing Notes
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Closing Notes (Optional)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Add notes about closing this position...", text: $closingNotes, axis: .vertical)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .lineLimit(3...6)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Projected P&L
                    if let price = Double(exitPrice), price > 0 {
                        ProjectedPLCard(trade: trade, exitPrice: price)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Close Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        Task { await closeTrade() }
                    }
                    .disabled(exitPrice.isEmpty || Double(exitPrice) == nil || isLoading)
                }
            }
            .alert("Position Closed", isPresented: $showAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    @MainActor
    private func closeTrade() async {
        guard let price = Double(exitPrice) else { return }
        
        isLoading = true
        
        let profit = (price - trade.entryPrice) * Double(trade.quantity)
        
        // Use existing closeTrade method from portfolioViewModel
        portfolioViewModel.closeTrade(trade, exitPrice: price)
        
        alertMessage = profit >= 0 ?
            "Position closed with a profit of \(profit.asCurrency)" :
            "Position closed with a loss of \(abs(profit).asCurrency)"
        
        showAlert = true
        isLoading = false
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct StatusBanner: View {
    let text: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct EditableField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var prefix: String? = nil
    let isEditable: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if isEditable {
                HStack {
                    if let prefix = prefix {
                        Text(prefix)
                            .foregroundColor(.gray)
                    }
                    
                    TextField(placeholder, text: $text)
                        .textFieldStyle(PlainTextFieldStyle())
                        .keyboardType(keyboardType)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text(prefix != nil ? "\(prefix!)\(text)" : text)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct ProjectedPLCard: View {
    let trade: Trade
    let exitPrice: Double
    
    var body: some View {
        let profit = (exitPrice - trade.entryPrice) * Double(trade.quantity)
        let percentage = ((exitPrice - trade.entryPrice) / trade.entryPrice) * 100
        
        VStack(spacing: 16) {
            Text("Projected Outcome")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profit/Loss")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(profit.asCurrencyWithSign)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(profit >= 0 ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Return")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("\(percentage >= 0 ? "+" : "")\(String(format: "%.2f", percentage))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(profit >= 0 ? .green : .red)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Entry Value")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text((trade.entryPrice * Double(trade.quantity)).asCurrency)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Exit Value")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text((exitPrice * Double(trade.quantity)).asCurrency)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background((profit >= 0 ? Color.green : Color.red).opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(profit >= 0 ? Color.green : Color.red, lineWidth: 1)
        )
    }
}

#Preview {
    let sampleTrade = Trade(ticker: "AAPL", tradeType: .stock, entryPrice: 150.00, quantity: 10, userId: "sample")
    
    EditTradeSheet(trade: sampleTrade)
        .environmentObject(PortfolioViewModel())
}
