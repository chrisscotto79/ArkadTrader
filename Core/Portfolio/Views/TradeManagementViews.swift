// MARK: - Complete TradeActionsSheet with Original Design + Performance Fix
import SwiftUI

struct TradeActionsSheet: View {
    let trade: Trade
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedAction: TradeAction = .view
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    
    // Edit states - Initialize with trade values immediately
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
    
    // Performance optimization - simple init
    init(trade: Trade) {
        self.trade = trade
        // Direct assignment without heavy computation
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
                // Action Selector (original design)
                actionSelector
                
                // Content based on selected action
                ScrollView {
                    contentForSelectedAction
                        .padding()
                }
                .background(Color(.systemGroupedBackground))
                
                // Action Button
                actionButton
                    .padding()
                    .background(Color(.systemBackground))
            }
            .navigationTitle(trade.ticker)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if selectedAction == .view {
                            dismiss()
                        } else {
                            Task { await performAction() }
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadGold)
                }
            }
        }
        .alert("Trade Updated", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog("Delete Trade", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await deleteTrade() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this trade? This action cannot be undone.")
        }
    }
    
    // MARK: - Action Selector (Original Design)
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
    
    // MARK: - Content Switcher
    @ViewBuilder
    private var contentForSelectedAction: some View {
        switch selectedAction {
        case .view:
            tradeViewContent
        case .edit:
            tradeEditContent
        case .close:
            tradeCloseContent
        }
    }
    
    // MARK: - View Content (Original Design)
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
                Text("Trade Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 8) {
                    DetailRow(title: "Trade Type", value: trade.tradeType.displayName)
                    DetailRow(title: "Entry Price", value: trade.entryPrice.asCurrency)
                    DetailRow(title: "Quantity", value: "\(trade.quantity) shares")
                    DetailRow(title: "Total Value", value: trade.currentValue.asCurrency)
                    DetailRow(title: "Entry Date", value: formatDate(trade.entryDate))
                    
                    if !trade.isOpen, let exitDate = trade.exitDate {
                        DetailRow(title: "Exit Date", value: formatDate(exitDate))
                        DetailRow(title: "Days Held", value: formatHoldTime(from: trade.entryDate, to: exitDate))
                    }
                    
                    if let strategy = trade.strategy, !strategy.isEmpty {
                        DetailRow(title: "Strategy", value: strategy)
                    }
                    
                    if let notes = trade.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text(notes)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Performance Card (for closed trades)
            if !trade.isOpen {
                VStack(spacing: 16) {
                    Text("Performance")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 8) {
                        DetailRow(
                            title: "Profit/Loss",
                            value: trade.profitLoss.asCurrencyWithSign,
                            valueColor: trade.profitLoss >= 0 ? .green : .red
                        )
                        DetailRow(
                            title: "Return %",
                            value: "\(String(format: "%.2f", trade.profitLossPercentage))%",
                            valueColor: trade.profitLossPercentage >= 0 ? .green : .red
                        )
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            
            // Quick Actions
            VStack(spacing: 12) {
                if trade.isOpen {
                    quickActionRow(
                        title: "Quick Close at Entry Price",
                        subtitle: "Close position at break-even instantly",
                        icon: "xmark.circle.fill",
                        color: .orange,
                        action: { quickCloseAtEntry() }
                    )
                }
                
                quickActionRow(
                    title: "Delete Trade",
                    subtitle: "Permanently remove this trade",
                    icon: "trash.circle.fill",
                    color: .red,
                    action: { showDeleteConfirmation = true }
                )
            }
        }
    }
    
    // MARK: - Edit Content (Original Design)
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
                    placeholder: "0",
                    keyboardType: .numberPad,
                    isEditable: trade.isOpen
                )
                
                TradeEditField(
                    title: "Strategy",
                    text: $strategy,
                    placeholder: "Optional",
                    isEditable: true
                )
                
                TradeEditField(
                    title: "Notes",
                    text: $notes,
                    placeholder: "Optional",
                    isEditable: true
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
                        text: .constant(formatDate(trade.entryDate)),
                        placeholder: "",
                        isEditable: false
                    )
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Summary Card
            if trade.isOpen {
                VStack(spacing: 8) {
                    Text("Updated Position Summary")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    if let entryPriceDouble = Double(entryPrice),
                       let quantityInt = Int(quantity) {
                        VStack(spacing: 4) {
                            Text("\(quantityInt) shares of \(ticker.uppercased())")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Entry: \(entryPriceDouble.asCurrency)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text("Total: \((entryPriceDouble * Double(quantityInt)).asCurrency)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.arkadGold)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
    }
    
    // MARK: - Close Content (Original Design)
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
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .lineLimit(3...6)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Projected P&L Card
            if let price = Double(exitPrice), price > 0 {
                ProjectedPLCard(trade: trade, exitPrice: price)
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
    
    // MARK: - Action Button (Original Design)
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
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
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
        isLoading = false
    }
    
    private func quickCloseAtEntry() {
        portfolioViewModel.closeTrade(trade, exitPrice: trade.entryPrice)
        dismiss()
    }
    
    @MainActor
    private func deleteTrade() async {
        do {
            try await portfolioViewModel.deleteTrade(trade)
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
    
    private func quickActionRow(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
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
            .background(color.opacity(0.05))
            .cornerRadius(8)
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
