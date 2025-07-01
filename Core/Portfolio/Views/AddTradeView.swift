// MARK: - Add Trade View
import SwiftUI

struct AddTradeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    
    @State private var ticker = ""
    @State private var tradeType: TradeType = .stock
    @State private var entryPrice = ""
    @State private var quantity = ""
    @State private var notes = ""
    @State private var strategy = ""
    @State private var selectedStrategy: TradingStrategy = .custom
    
    @State private var showingConfirmation = false
    @State private var isValidating = false
    @State private var validationMessage = ""
    @State private var isAddingTrade = false
    
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
                        ForEach(TradingStrategy.allCases, id: \.self) { strategy in
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
                            Text(totalInvestment.asCurrency)
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
        
        Task {
            do {
                let finalStrategy = selectedStrategy == .custom ? strategy : selectedStrategy.displayName
                
                try await portfolioViewModel.addTrade(
                    ticker: ticker,
                    tradeType: tradeType,
                    entryPrice: price,
                    quantity: qty,
                    notes: notes.isEmpty ? nil : notes,
                    strategy: finalStrategy.isEmpty ? nil : finalStrategy
                )
                
                await MainActor.run {
                    isAddingTrade = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isAddingTrade = false
                    portfolioViewModel.errorMessage = error.localizedDescription
                    portfolioViewModel.showError = true
                }
            }
        }
    }
}

// MARK: - Trade Management View
struct TradeManagementView: View {
    let trade: Trade
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @Environment(\.dismiss) var dismiss
    
    @State private var showingCloseDialog = false
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var exitPrice = ""
    @State private var closingNotes = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Trade Header
                    TradeHeaderCard(trade: trade)
                    
                    // Current Performance (if open)
                    if trade.isOpen {
                        CurrentPerformanceCard(trade: trade)
                    }
                    
                    // Action Buttons
                    TradeActionButtons(
                        trade: trade,
                        onClose: { showingCloseDialog = true },
                        onEdit: { showingEditView = true },
                        onDelete: { showingDeleteAlert = true }
                    )
                    
                    // Trade Details
                    TradeDetailsCard(trade: trade)
                }
                .padding()
            }
            .navigationTitle("Manage Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCloseDialog) {
            CloseTradeDialog(
                trade: trade,
                portfolioViewModel: portfolioViewModel
            )
        }
        .sheet(isPresented: $showingEditView) {
            EditTradeView(
                trade: trade,
                portfolioViewModel: portfolioViewModel
            )
        }
        .alert("Delete Trade", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTrade()
            }
        } message: {
            Text("Are you sure you want to delete this \(trade.ticker) trade? This action cannot be undone.")
        }
        .alert("Error", isPresented: $portfolioViewModel.showError) {
            Button("OK") { }
        } message: {
            Text(portfolioViewModel.errorMessage)
        }
    }
    
    private func deleteTrade() {
        Task {
            do {
                try await portfolioViewModel.deleteTrade(trade)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    portfolioViewModel.errorMessage = error.localizedDescription
                    portfolioViewModel.showError = true
                }
            }
        }
    }
}

// MARK: - Close Trade Dialog
struct CloseTradeDialog: View {
    let trade: Trade
    let portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var exitPrice = ""
    @State private var closingNotes = ""
    @State private var isClosing = false
    
    var projectedPL: Double {
        guard let price = Double(exitPrice) else { return 0 }
        return (price - trade.entryPrice) * Double(trade.quantity)
    }
    
    var projectedPercentage: Double {
        guard let price = Double(exitPrice) else { return 0 }
        return ((price - trade.entryPrice) / trade.entryPrice) * 100
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Text("Close Position")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 8) {
                        Text(trade.ticker)
                            .font(.title)
                            .fontWeight(.semibold)
                        
                        Text("\(trade.quantity) shares @ \(trade.entryPrice.asCurrency)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("Opened \(trade.entryDate.timeAgoString)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Exit Price Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exit Price")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField("Enter exit price", text: $exitPrice)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.arkadGold, lineWidth: 2)
                        )
                }
                
                // Projected Outcome
                if !exitPrice.isEmpty, Double(exitPrice) != nil {
                    ProjectedOutcomeCard(
                        projectedPL: projectedPL,
                        projectedPercentage: projectedPercentage
                    )
                }
                
                // Closing Notes
                VStack(alignment: .leading, spacing: 12) {
                    Text("Closing Notes (Optional)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField("Why are you closing this position?", text: $closingNotes, axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: closePosition) {
                        HStack {
                            if isClosing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "xmark.circle")
                                Text("Close Position")
                            }
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.arkadGold)
                        .cornerRadius(12)
                    }
                    .disabled(exitPrice.isEmpty || Double(exitPrice) == nil || isClosing)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
    
    private func closePosition() {
        guard let price = Double(exitPrice) else { return }
        
        isClosing = true
        
        Task {
            do {
                try await portfolioViewModel.closeTrade(
                    trade,
                    exitPrice: price,
                    notes: closingNotes.isEmpty ? nil : closingNotes
                )
                
                await MainActor.run {
                    isClosing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isClosing = false
                    portfolioViewModel.errorMessage = error.localizedDescription
                    portfolioViewModel.showError = true
                }
            }
        }
    }
}

// MARK: - Edit Trade View (Simplified)
struct EditTradeView: View {
    let trade: Trade
    let portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var ticker: String
    @State private var entryPrice: String
    @State private var quantity: String
    @State private var notes: String
    @State private var strategy: String
    
    init(trade: Trade, portfolioViewModel: PortfolioViewModel) {
        self.trade = trade
        self.portfolioViewModel = portfolioViewModel
        _ticker = State(initialValue: trade.ticker)
        _entryPrice = State(initialValue: String(format: "%.2f", trade.entryPrice))
        _quantity = State(initialValue: "\(trade.quantity)")
        _notes = State(initialValue: trade.notes ?? "")
        _strategy = State(initialValue: trade.strategy ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Trade Information") {
                    TextField("Ticker", text: $ticker)
                        .textCase(.uppercase)
                    
                    TextField("Entry Price", text: $entryPrice)
                        .keyboardType(.decimalPad)
                    
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                }
                
                Section("Notes & Strategy") {
                    TextField("Strategy", text: $strategy)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        Task {
            do {
                try await portfolioViewModel.editTrade(
                    trade,
                    ticker: ticker,
                    entryPrice: Double(entryPrice),
                    quantity: Int(quantity),
                    notes: notes,
                    strategy: strategy
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // Handle error
                print("Error editing trade: \(error)")
            }
        }
    }
}

// MARK: - Supporting UI Components
struct TradeHeaderCard: View {
    let trade: Trade
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(trade.ticker)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(trade.tradeType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(
                        text: trade.isOpen ? "OPEN" : "CLOSED",
                        color: trade.isOpen ? .arkadGold : .gray
                    )
                    
                    Text("\(trade.daysHeld) days")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if !trade.isOpen {
                VStack(spacing: 8) {
                    Text(trade.profitLoss.asCurrencyWithSign)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                    
                    Text("\(trade.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.2f", trade.profitLossPercentage))%")
                        .font(.title3)
                        .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct CurrentPerformanceCard: View {
    let trade: Trade
    
    // Mock current price calculation
    private var mockCurrentPrice: Double {
        trade.entryPrice * Double.random(in: 0.95...1.05)
    }
    
    private var unrealizedPL: Double {
        (mockCurrentPrice - trade.entryPrice) * Double(trade.quantity)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Performance")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Price")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(mockCurrentPrice.asCurrency)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Unrealized P&L")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(unrealizedPL.asCurrencyWithSign)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(unrealizedPL >= 0 ? .marketGreen : .marketRed)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct TradeActionButtons: View {
    let trade: Trade
    let onClose: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if trade.isOpen {
                Button(action: onClose) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Close Position")
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.arkadGold)
                    .cornerRadius(12)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadGold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.arkadGold.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
}

struct ProjectedOutcomeCard: View {
    let projectedPL: Double
    let projectedPercentage: Double
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Projected Outcome")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Profit/Loss")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(projectedPL.asCurrencyWithSign)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(projectedPL >= 0 ? .marketGreen : .marketRed)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Return")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("\(projectedPercentage >= 0 ? "+" : "")\(String(format: "%.2f", projectedPercentage))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(projectedPL >= 0 ? .marketGreen : .marketRed)
                }
            }
        }
        .padding()
        .background((projectedPL >= 0 ? Color.marketGreen : Color.marketRed).opacity(0.1))
        .cornerRadius(12)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .cornerRadius(6)
    }
}

// MARK: - Supporting Enums
enum TradingStrategy: CaseIterable {
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
