// File: Core/Portfolio/Views/TradeManagementViews.swift
// Complete Enhanced Trade Management with Unified Interface - FIXED

import SwiftUI

// MARK: - Unified Trade Actions Sheet (MAIN INTERFACE)
struct TradeActionsSheet: View {
    let trade: Trade
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedAction: TradeAction = .view
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    
    // Edit states
    @State private var ticker: String
    @State private var tradeType: TradeType
    @State private var entryPrice: String
    @State private var quantity: String
    @State private var strategy: String
    @State private var notes: String
    @State private var entryDate: Date
    
    // Close states
    @State private var exitPrice = ""
    @State private var exitDate = Date()
    @State private var closingNotes = ""
    
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
            VStack(spacing: 0) {
                // Action Selector Tabs
                actionSelector
                
                // Content based on selected action
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedAction {
                        case .view:
                            tradeViewContent
                        case .edit:
                            tradeEditContent
                        case .close:
                            tradeCloseContent
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(trade.ticker)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    actionButton
                }
            }
            .alert("Success", isPresented: $showAlert) {
                Button("OK") {
                    if selectedAction == .close {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .confirmationDialog("Delete Trade", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task { await deletePosition() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to permanently delete this trade? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Action Selector
    private var actionSelector: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(TradeAction.allCases, id: \.self) { action in
                    if action.isAvailable(for: trade) {
                        actionTab(action)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func actionTab(_ action: TradeAction) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedAction = action
            }
        }) {
            VStack(spacing: 6) {
                Image(systemName: action.icon)
                    .font(.system(size: 16, weight: .medium))
                
                Text(action.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(selectedAction == action ? .arkadGold : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(selectedAction == action ? Color.arkadGold.opacity(0.1) : Color.clear)
            )
            .overlay(
                Rectangle()
                    .fill(selectedAction == action ? Color.arkadGold : Color.clear)
                    .frame(height: 2)
                    .offset(y: 18)
                , alignment: .bottom
            )
        }
    }
    
    // MARK: - View Content
    private var tradeViewContent: some View {
        VStack(spacing: 20) {
            // Status Badge
            HStack {
                Label(
                    trade.isOpen ? "Open Position" : "Closed Position",
                    systemImage: trade.isOpen ? "clock.fill" : "checkmark.circle.fill"
                )
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(trade.isOpen ? .blue : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((trade.isOpen ? Color.blue : Color.gray).opacity(0.1))
                .cornerRadius(20)
                
                Spacer()
                
                // P&L Badge for closed trades
                if !trade.isOpen {
                    Text(trade.profitLoss.asCurrencyWithSign)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(trade.profitLoss >= 0 ? Color.green : Color.red)
                        .cornerRadius(20)
                }
            }
            
            // Trade Details Card
            VStack(spacing: 16) {
                DetailRow(title: "Trade Type", value: trade.tradeType.displayName)
                DetailRow(title: "Entry Price", value: trade.entryPrice.asCurrency)
                DetailRow(title: "Quantity", value: "\(trade.quantity)")
                DetailRow(title: "Total Value", value: (trade.entryPrice * Double(trade.quantity)).asCurrency)
                DetailRow(title: "Entry Date", value: formatDate(trade.entryDate))
                
                if !trade.isOpen, let exitPrice = trade.exitPrice, let exitDate = trade.exitDate {
                    Divider()
                    DetailRow(title: "Exit Price", value: exitPrice.asCurrency)
                    DetailRow(title: "Exit Date", value: formatDate(exitDate))
                    DetailRow(title: "Hold Time", value: formatHoldTime(from: trade.entryDate, to: exitDate))
                    DetailRow(
                        title: "Profit/Loss",
                        value: trade.profitLoss.asCurrencyWithSign,
                        valueColor: trade.profitLoss >= 0 ? .green : .red
                    )
                    DetailRow(
                        title: "Return %",
                        value: String(format: "%.2f%%", (trade.profitLoss / (trade.entryPrice * Double(trade.quantity))) * 100),
                        valueColor: trade.profitLoss >= 0 ? .green : .red
                    )
                }
                
                if let strategy = trade.strategy, !strategy.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Strategy")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(strategy)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                if let notes = trade.notes, !notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(notes)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Quick Actions
            VStack(spacing: 12) {
                if trade.isOpen {
                    TradeActionRow(
                        title: "Quick Close at Entry Price",
                        subtitle: "Close position at break-even instantly",
                        icon: "xmark.circle.fill",
                        color: .orange,
                        action: { Task { await quickClosePosition() } }
                    )
                } else {
                    TradeActionRow(
                        title: "Reopen Position",
                        subtitle: "Mark position as open again",
                        icon: "arrow.clockwise.circle.fill",
                        color: .blue,
                        action: { Task { await reopenPosition() } }
                    )
                }
                
                TradeActionRow(
                    title: "Delete Trade",
                    subtitle: "Permanently remove this trade",
                    icon: "trash.circle.fill",
                    color: .red,
                    action: { showDeleteConfirmation = true }
                )
            }
        }
    }
    
    // MARK: - Edit Content
    private var tradeEditContent: some View {
        VStack(spacing: 20) {
            // Edit Warning for Closed Trades
            if !trade.isOpen {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("Some fields are read-only for closed positions")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Editable Fields
            VStack(spacing: 16) {
                TradeEditField(
                    title: "Ticker Symbol",
                    text: $ticker,
                    placeholder: "AAPL",
                    isEditable: trade.isOpen
                )
                
                if trade.isOpen {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trade Type")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Trade Type", selection: $tradeType) {
                            ForEach(TradeType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                } else {
                    TradeEditField(
                        title: "Trade Type",
                        text: .constant(tradeType.displayName),
                        placeholder: "",
                        isEditable: false
                    )
                }
                
                TradeEditField(
                    title: "Entry Price",
                    text: $entryPrice,
                    placeholder: "0.00",
                    keyboardType: .decimalPad,
                    prefix: "$",
                    isEditable: trade.isOpen
                )
                
                TradeEditField(
                    title: "Quantity",
                    text: $quantity,
                    placeholder: "100",
                    keyboardType: .numberPad,
                    isEditable: trade.isOpen
                )
                
                if trade.isOpen {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Entry Date")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        DatePicker("Entry Date", selection: $entryDate, displayedComponents: [.date])
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                } else {
                    TradeEditField(
                        title: "Entry Date",
                        text: .constant(formatDate(entryDate)),
                        placeholder: "",
                        isEditable: false
                    )
                }
                
                TradeEditField(
                    title: "Strategy",
                    text: $strategy,
                    placeholder: "Enter trading strategy...",
                    isEditable: true
                )
                
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
                
                // Calculated Values Display
                if let entryPriceDouble = Double(entryPrice), let quantityInt = Int(quantity), entryPriceDouble > 0, quantityInt > 0 {
                    VStack(spacing: 8) {
                        Divider()
                        
                        HStack {
                            Text("Total Position Value")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text((entryPriceDouble * Double(quantityInt)).asCurrency)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.arkadGold)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - Close Content
    private var tradeCloseContent: some View {
        VStack(spacing: 20) {
            // Current Position Summary
            VStack(spacing: 12) {
                Text("Close Position")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 8) {
                    Text("\(trade.quantity) shares at \(trade.entryPrice.asCurrency)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("Entered on \(formatDate(trade.entryDate))")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("Position Value: \((trade.entryPrice * Double(trade.quantity)).asCurrency)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(12)
            
            // Exit Details
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exit Price *")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("0.00", text: $exitPrice)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            HStack {
                                Text("$")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 12)
                                Spacer()
                            }
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exit Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    DatePicker("Exit Date", selection: $exitDate, displayedComponents: [.date])
                        .datePickerStyle(CompactDatePickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Closing Notes (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Add closing notes...", text: $closingNotes, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(2...4)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Projected P&L
            if let price = Double(exitPrice), price > 0 {
                let projectedPL = (price - trade.entryPrice) * Double(trade.quantity)
                let returnPercentage = (projectedPL / (trade.entryPrice * Double(trade.quantity))) * 100
                
                VStack(spacing: 12) {
                    Text("Projected Results")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Profit/Loss:")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text(projectedPL.asCurrencyWithSign)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(projectedPL >= 0 ? .green : .red)
                        }
                        
                        HStack {
                            Text("Return:")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text("\(String(format: "%.2f", returnPercentage))%")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(projectedPL >= 0 ? .green : .red)
                        }
                        
                        HStack {
                            Text("Total Value:")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text((price * Double(trade.quantity)).asCurrency)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding()
                .background((projectedPL >= 0 ? Color.green : Color.red).opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke((projectedPL >= 0 ? Color.green : Color.red).opacity(0.3), lineWidth: 1)
                )
            }
            
            // Quick Close Options
            VStack(spacing: 8) {
                Text("Quick Close Options")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                
                HStack(spacing: 12) {
                    QuickCloseButton(title: "Break Even", action: {
                        exitPrice = String(format: "%.2f", trade.entryPrice)
                    })
                    
                    QuickCloseButton(title: "+5%", action: {
                        exitPrice = String(format: "%.2f", trade.entryPrice * 1.05)
                    })
                    
                    QuickCloseButton(title: "+10%", action: {
                        exitPrice = String(format: "%.2f", trade.entryPrice * 1.10)
                    })
                    
                    QuickCloseButton(title: "-5%", action: {
                        exitPrice = String(format: "%.2f", trade.entryPrice * 0.95)
                    })
                }
            }
        }
    }
    
    // MARK: - Action Button
    private var actionButton: some View {
        Button(action: {
            Task { await performAction() }
        }) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(selectedAction.buttonTitle)
                        .fontWeight(.semibold)
                    
                    if selectedAction != .view {
                        Image(systemName: selectedAction.buttonIcon)
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isActionValid && !isLoading ? Color.arkadGold : Color.gray)
            .cornerRadius(8)
        }
        .disabled(isLoading || !isActionValid)
    }
    
    private var isActionValid: Bool {
        switch selectedAction {
        case .view:
            return true
        case .edit:
            return !ticker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !entryPrice.isEmpty &&
                   !quantity.isEmpty &&
                   Double(entryPrice) != nil &&
                   Int(quantity) != nil &&
                   Double(entryPrice)! > 0 &&
                   Int(quantity)! > 0
        case .close:
            return !exitPrice.isEmpty && Double(exitPrice) != nil && Double(exitPrice)! > 0
        }
    }
    
    // MARK: - Actions
    @MainActor
    private func performAction() async {
        isLoading = true
        
        switch selectedAction {
        case .view:
            break
        case .edit:
            await saveTradeEdits()
        case .close:
            await closePosition()
        }
        
        isLoading = false
    }
    
    @MainActor
    private func saveTradeEdits() async {
        do {
            var updatedTrade = trade
            updatedTrade.ticker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            updatedTrade.tradeType = tradeType
            updatedTrade.entryPrice = Double(entryPrice) ?? trade.entryPrice
            updatedTrade.quantity = Int(quantity) ?? trade.quantity
            updatedTrade.strategy = strategy.isEmpty ? nil : strategy
            updatedTrade.notes = notes.isEmpty ? nil : notes
            updatedTrade.entryDate = entryDate
            
            try await portfolioViewModel.updateTrade(updatedTrade)
            
            alertMessage = "Trade updated successfully!"
            showAlert = true
            
            // Switch back to view mode to see changes
            selectedAction = .view
        } catch {
            alertMessage = "Failed to update trade: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    @MainActor
    private func closePosition() async {
        guard let price = Double(exitPrice) else { return }
        
        // Update notes if closing notes were added
        if !closingNotes.isEmpty {
            let currentNotes = notes.isEmpty ? "" : notes + "\n\n"
            notes = currentNotes + "Closing notes: " + closingNotes
        }
        
        portfolioViewModel.closeTrade(trade, exitPrice: price)
        
        let profit = (price - trade.entryPrice) * Double(trade.quantity)
        alertMessage = profit >= 0 ?
            "Position closed with a profit of \(profit.asCurrency)" :
            "Position closed with a loss of \(abs(profit).asCurrency)"
        
        showAlert = true
    }
    
    @MainActor
    private func quickClosePosition() async {
        portfolioViewModel.closeTrade(trade, exitPrice: trade.entryPrice)
        
        alertMessage = "Position closed at break-even (\(trade.entryPrice.asCurrency))"
        showAlert = true
    }
    
    @MainActor
    private func reopenPosition() async {
        do {
            try await portfolioViewModel.reopenTrade(trade)
            alertMessage = "Position reopened successfully!"
            showAlert = true
        } catch {
            alertMessage = "Failed to reopen position: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    @MainActor
    private func deletePosition() async {
        do {
            try await portfolioViewModel.deleteTrade(trade)
            alertMessage = "Trade deleted successfully!"
            showAlert = true
            dismiss()
        } catch {
            alertMessage = "Failed to delete trade: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatHoldTime(from startDate: Date, to endDate: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        if days == 0 {
            return "Same day"
        } else if days == 1 {
            return "1 day"
        } else {
            return "\(days) days"
        }
    }
}

// MARK: - Supporting Views and Types

enum TradeAction: CaseIterable {
    case view, edit, close
    
    var title: String {
        switch self {
        case .view: return "View"
        case .edit: return "Edit"
        case .close: return "Close"
        }
    }
    
    var icon: String {
        switch self {
        case .view: return "eye.fill"
        case .edit: return "pencil"
        case .close: return "xmark.circle"
        }
    }
    
    var buttonTitle: String {
        switch self {
        case .view: return "Done"
        case .edit: return "Save Changes"
        case .close: return "Close Position"
        }
    }
    
    var buttonIcon: String {
        switch self {
        case .view: return "checkmark"
        case .edit: return "checkmark"
        case .close: return "xmark.circle"
        }
    }
    
    func isAvailable(for trade: Trade) -> Bool {
        switch self {
        case .view, .edit:
            return true
        case .close:
            return trade.isOpen
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

struct TradeEditField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var prefix: String?
    var isEditable: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if isEditable {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        HStack {
                            if let prefix = prefix {
                                Text(prefix)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 12)
                            }
                            Spacer()
                        }
                    )
            } else {
                Text((prefix ?? "") + text)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct TradeActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickCloseButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.arkadGold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.arkadGold.opacity(0.1))
                .cornerRadius(6)
        }
    }
}

// MARK: - Legacy Components (For Backward Compatibility)

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
    var prefix: String?
    var isEditable: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if isEditable {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        HStack {
                            if let prefix = prefix {
                                Text(prefix)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 12)
                            }
                            Spacer()
                        }
                    )
            } else {
                Text((prefix ?? "") + text)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Original Enhanced Edit Trade Sheet (Standalone)
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
                    StatusBanner(
                        text: trade.isOpen ? "This is an open position" : "This is a closed position",
                        color: trade.isOpen ? .blue : .gray,
                        icon: trade.isOpen ? "clock.fill" : "checkmark.circle.fill"
                    )
                    
                    VStack(spacing: 20) {
                        EditableField(
                            title: "Ticker Symbol",
                            text: $ticker,
                            placeholder: "AAPL",
                            isEditable: trade.isOpen
                        )
                        
                        EditableField(
                            title: "Entry Price",
                            text: $entryPrice,
                            placeholder: "0.00",
                            keyboardType: .decimalPad,
                            prefix: "$",
                            isEditable: trade.isOpen
                        )
                        
                        EditableField(
                            title: "Quantity",
                            text: $quantity,
                            placeholder: "100",
                            keyboardType: .numberPad,
                            isEditable: trade.isOpen
                        )
                        
                        EditableField(
                            title: "Strategy",
                            text: $strategy,
                            placeholder: "Enter trading strategy...",
                            isEditable: true
                        )
                        
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
        !ticker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !entryPrice.isEmpty &&
        !quantity.isEmpty &&
        Double(entryPrice) != nil &&
        Int(quantity) != nil &&
        Double(entryPrice)! > 0 &&
        Int(quantity)! > 0
    }
    
    @MainActor
    private func saveChanges() async {
        guard isFormValid else { return }
        isLoading = true
        
        do {
            var updatedTrade = trade
            updatedTrade.ticker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            updatedTrade.tradeType = tradeType
            updatedTrade.entryPrice = Double(entryPrice) ?? trade.entryPrice
            updatedTrade.quantity = Int(quantity) ?? trade.quantity
            updatedTrade.strategy = strategy.isEmpty ? nil : strategy
            updatedTrade.notes = notes.isEmpty ? nil : notes
            updatedTrade.entryDate = entryDate
            
            try await portfolioViewModel.updateTrade(updatedTrade)
            
            alertMessage = "Trade updated successfully!"
            showAlert = true
        } catch {
            alertMessage = "Failed to update trade: \(error.localizedDescription)"
            showAlert = true
        }
        
        isLoading = false
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Enhanced Close Trade Sheet
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
                    VStack(spacing: 16) {
                        Text("Close Position")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 8) {
                            Text(trade.ticker)
                                .font(.title)
                                .fontWeight(.semibold)
                            
                            Text("\(trade.quantity) shares")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text("Entry: \(trade.entryPrice.asCurrency)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exit Price")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            TextField("Enter exit price", text: $exitPrice)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.title2)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exit Date")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            DatePicker("Exit Date", selection: $exitDate, displayedComponents: [.date])
                                .datePickerStyle(CompactDatePickerStyle())
                        }
                    }
                    
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
        
        portfolioViewModel.closeTrade(trade, exitPrice: price)
        
        alertMessage = profit >= 0 ?
            "Position closed with a profit of \(profit.asCurrency)" :
            "Position closed with a loss of \(abs(profit).asCurrency)"
        
        showAlert = true
        isLoading = false
    }
}

struct ProjectedPLCard: View {
    let trade: Trade
    let exitPrice: Double
    
    private var projectedPL: Double {
        (exitPrice - trade.entryPrice) * Double(trade.quantity)
    }
    
    private var returnPercentage: Double {
        (projectedPL / (trade.entryPrice * Double(trade.quantity))) * 100
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Projected Results")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Profit/Loss:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(projectedPL.asCurrencyWithSign)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(projectedPL >= 0 ? .green : .red)
                }
                
                HStack {
                    Text("Return:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.2f", returnPercentage))%")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(projectedPL >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background((projectedPL >= 0 ? Color.green : Color.red).opacity(0.1))
        .cornerRadius(12)
    }
}
