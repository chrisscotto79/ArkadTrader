// File: Core/Portfolio/Views/AddTradeView.swift
// Simplified Add Trade View

import SwiftUI

struct AddTradeView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var ticker = ""
    @State private var entryPrice = ""
    @State private var quantity = ""
    @State private var tradeType: TradeType = .stock
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Trade Details") {
                    TextField("Ticker (e.g. AAPL)", text: $ticker)
                        .textCase(.uppercase)
                    
                    Picker("Trade Type", selection: $tradeType) {
                        ForEach(TradeType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    TextField("Entry Price", text: $entryPrice)
                        .keyboardType(.decimalPad)
                    
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                }
                
                Section("Notes (Optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Trade")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Add") { addTrade() }
                    .disabled(!isFormValid)
            )
        }
    }
    
    private var isFormValid: Bool {
        !ticker.isEmpty &&
        !entryPrice.isEmpty &&
        !quantity.isEmpty &&
        Double(entryPrice) != nil &&
        Int(quantity) != nil
    }
    
    private func addTrade() {
        guard let userId = authService.currentUser?.id,
              let price = Double(entryPrice),
              let qty = Int(quantity) else { return }
        
        let trade = Trade(
            ticker: ticker,
            tradeType: tradeType,
            entryPrice: price,
            quantity: qty,
            userId: userId
        )
        
        var newTrade = trade
        newTrade.notes = notes.isEmpty ? nil : notes
        
        Task {
            do {
                try await authService.addTrade(newTrade)
                dismiss()
            } catch {
                print("Error adding trade: \(error)")
            }
        }
    }
}

#Preview {
    AddTradeView()
        .environmentObject(FirebaseAuthService.shared)
}
