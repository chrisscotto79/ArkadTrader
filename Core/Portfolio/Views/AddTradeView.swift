//
//  AddTradeView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

// File: Core/Portfolio/Views/AddTradeView.swift

import SwiftUI

struct AddTradeView: View {
    @Binding var trades: [Trade]
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var ticker = ""
    @State private var tradeType: TradeType = .stock
    @State private var entryPrice = ""
    @State private var quantity = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Trade Details") {
                    TextField("Ticker Symbol", text: $ticker)
                        .autocapitalization(.allCharacters)
                    
                    Picker("Trade Type", selection: $tradeType) {
                        ForEach(TradeType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    TextField("Entry Price", text: $entryPrice)
                        .keyboardType(.decimalPad)
                    
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                }
                
                Section("Notes") {
                    TextField("Add notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
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
                    Button("Save") {
                        saveTrade()
                    }
                    .disabled(!isFormValid)
                }
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
    
    private func saveTrade() {
        guard let price = Double(entryPrice),
              let qty = Int(quantity),
              let userId = authViewModel.currentUser?.id else {
            return
        }
        
        var newTrade = Trade(ticker: ticker, tradeType: tradeType, entryPrice: price, quantity: qty, userId: userId)
        
        if !notes.isEmpty {
            newTrade.notes = notes
        }
        
        trades.append(newTrade)
        dismiss()
    }
}

#Preview {
    AddTradeView(trades: .constant([]))
        .environmentObject(AuthViewModel())
}
