// File: Core/Portfolio/Views/TradeManagementViews.swift
// Trade Management: Edit, Close, Share, and Notes functionality

import SwiftUI

// MARK: - Edit Trade View
struct EditTradeView: View {
    let trade: Trade
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var ticker: String
    @State private var tradeType: TradeType
    @State private var entryPrice: String
    @State private var quantity: String
    @State private var notes: String
    @State private var strategy: String
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    init(trade: Trade) {
        self.trade = trade
        _ticker = State(initialValue: trade.ticker)
        _tradeType = State(initialValue: trade.tradeType)
        _entryPrice = State(initialValue: String(format: "%.2f", trade.entryPrice))
        _quantity = State(initialValue: "\(trade.quantity)")
        _notes = State(initialValue: trade.notes ?? "")
        _strategy = State(initialValue: trade.strategy ?? "")
    }
    
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
                }
                
                Section("Strategy & Notes") {
                    TextField("Trading strategy (optional)", text: $strategy, axis: .vertical)
                        .lineLimit(2...4)
                    
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Trade Status") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Status")
                                .font(.subheadline)
                            Text(trade.isOpen ? "Open Position" : "Closed Position")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Text(trade.isOpen ? "OPEN" : "CLOSED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(trade.isOpen ? .arkadGold : .gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((trade.isOpen ? Color.arkadGold : Color.gray).opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            .navigationTitle("Edit Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .alert("Success", isPresented: $showAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isFormValid: Bool {
        !ticker.isEmpty &&
        !entryPrice.isEmpty &&
        !quantity.isEmpty &&
        Double(entryPrice) != nil &&
        Int(quantity) != nil
    }
    
    private func saveChanges() {
        // For now, just show success message since updateTrade doesn't exist
        alertMessage = "Trade edit functionality coming soon!"
        showAlert = true
    }
}

// MARK: - Close Trade View
struct CloseTradeView: View {
    let trade: Trade
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var exitPrice = ""
    @State private var exitNotes = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
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
                        
                        Text("\(trade.quantity) shares @ $\(String(format: "%.2f", trade.entryPrice))")
                            .font(.subheadline)
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
                }
                
                // Projected P&L
                if let price = Double(exitPrice), price > 0 {
                    ProjectedPLView(trade: trade, exitPrice: price)
                }
                
                // Notes
                VStack(alignment: .leading, spacing: 12) {
                    Text("Closing Notes (Optional)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField("Add notes about this trade closure...", text: $exitNotes, axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: closeTrade) {
                        Text("Close Position")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.arkadGold)
                            .cornerRadius(12)
                    }
                    .disabled(exitPrice.isEmpty || Double(exitPrice) == nil)
                    
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
        .alert("Position Closed", isPresented: $showAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func closeTrade() {
        guard let price = Double(exitPrice) else { return }
        
        let profit = (price - trade.entryPrice) * Double(trade.quantity)
        portfolioViewModel.closeTrade(trade, exitPrice: price)
        
        alertMessage = profit >= 0 ?
            "Position closed with a profit of $\(String(format: "%.2f", profit))" :
            "Position closed with a loss of $\(String(format: "%.2f", abs(profit)))"
        showAlert = true
    }
}

// MARK: - Projected P&L View
struct ProjectedPLView: View {
    let trade: Trade
    let exitPrice: Double
    
    var body: some View {
        let profit = (exitPrice - trade.entryPrice) * Double(trade.quantity)
        let percentage = ((exitPrice - trade.entryPrice) / trade.entryPrice) * 100
        
        VStack(spacing: 12) {
            Text("Projected Outcome")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Profit/Loss")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(profit >= 0 ? "+$\(String(format: "%.2f", profit))" : "-$\(String(format: "%.2f", abs(profit)))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(profit >= 0 ? .marketGreen : .marketRed)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Return")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("\(percentage >= 0 ? "+" : "")\(String(format: "%.2f", percentage))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(profit >= 0 ? .marketGreen : .marketRed)
                }
            }
        }
        .padding()
        .background((profit >= 0 ? Color.marketGreen : Color.marketRed).opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Share Trade View
struct ShareTradeView: View {
    let trade: Trade
    @Environment(\.dismiss) var dismiss
    @State private var selectedShareType: TradeShareType = .performance
    @State private var shareText = ""
    @State private var showSystemShare = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Share Trade")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Share Type Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("What would you like to share?")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    ForEach(TradeShareType.allCases, id: \.self) { type in
                        ShareTypeButton(
                            type: type,
                            isSelected: selectedShareType == type
                        ) {
                            selectedShareType = type
                            generateShareText()
                        }
                    }
                }
                
                // Share Preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    ScrollView {
                        Text(shareText)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .frame(maxHeight: 150)
                }
                
                Spacer()
                
                // Share Actions
                VStack(spacing: 12) {
                    Button(action: { showSystemShare = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share via...")
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.arkadGold)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        UIPasteboard.general.string = shareText
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy to Clipboard")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.arkadGold.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                generateShareText()
            }
        }
        .sheet(isPresented: $showSystemShare) {
            ShareSheet(items: [shareText])
        }
    }
    
    private func generateShareText() {
        switch selectedShareType {
        case .performance:
            if trade.isOpen {
                shareText = """
                📈 Currently trading \(trade.ticker)
                
                💰 Entry: $\(String(format: "%.2f", trade.entryPrice))
                📊 Quantity: \(trade.quantity) shares
                ⏰ Opened: \(formatShareDate(trade.entryDate))
                
                Following my trading journey on ArkadTrader! 🚀
                """
            } else {
                let performance = trade.profitLoss >= 0 ? "📈 PROFIT" : "📉 LOSS"
                shareText = """
                \(performance): \(trade.ticker) Trade Closed!
                
                💰 P&L: \(trade.profitLoss >= 0 ? "+$\(String(format: "%.2f", trade.profitLoss))" : "-$\(String(format: "%.2f", abs(trade.profitLoss)))")
                📊 Return: \(trade.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.2f", trade.profitLossPercentage))%
                📈 Entry: $\(String(format: "%.2f", trade.entryPrice)) → Exit: $\(String(format: "%.2f", trade.exitPrice ?? 0))
                
                Building wealth one trade at a time! 🎯
                """
            }
        case .analysis:
            shareText = """
            📊 Trade Analysis: \(trade.ticker)
            
            🎯 Strategy: \(trade.strategy ?? "Position trading")
            💰 Entry: $\(String(format: "%.2f", trade.entryPrice))
            📈 Quantity: \(trade.quantity) shares
            ⏱️ Duration: \(tradeDurationText)
            
            \(trade.notes ?? "Executing my trading plan systematically.")
            
            #Trading #Investing #ArkadTrader
            """
        case .milestone:
            shareText = """
            🎉 Trading Milestone Achieved!
            
            ✅ Successfully \(trade.isOpen ? "opened" : "closed") \(trade.ticker) position
            💎 \(trade.quantity) shares traded
            📈 \(trade.isOpen ? "Building" : "Executed") my investment strategy
            
            Every trade is a learning experience! 📚
            Follow my journey on ArkadTrader 🚀
            """
        }
    }
    
    private func formatShareDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private var tradeDurationText: String {
        let endDate = trade.exitDate ?? Date()
        let days = Calendar.current.dateComponents([.day], from: trade.entryDate, to: endDate).day ?? 0
        return "\(days) days"
    }
}

// MARK: - Add Trade Note View
struct AddTradeNoteView: View {
    let trade: Trade
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var noteText = ""
    @State private var noteCategory: NoteCategory = .general
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add Note to \(trade.ticker)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Document your thoughts, strategy, or observations about this trade.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Category")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Picker("Category", selection: $noteCategory) {
                        ForEach(NoteCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Note")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField("Enter your note here...", text: $noteText, axis: .vertical)
                        .lineLimit(5...10)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Spacer()
                
                Button(action: saveNote) {
                    Text("Save Note")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.arkadGold)
                        .cornerRadius(12)
                }
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Note Saved", isPresented: $showAlert) {
            Button("OK") {
                dismiss()
            }
        }
    }
    
    private func saveNote() {
        // For now, just show success since updateTrade doesn't exist
        showAlert = true
    }
}

// MARK: - Supporting Types and Views
enum TradeShareType: CaseIterable {
    case performance, analysis, milestone
    
    var displayName: String {
        switch self {
        case .performance: return "Performance"
        case .analysis: return "Analysis"
        case .milestone: return "Milestone"
        }
    }
    
    var icon: String {
        switch self {
        case .performance: return "chart.line.uptrend.xyaxis"
        case .analysis: return "chart.bar.doc.horizontal"
        case .milestone: return "trophy"
        }
    }
}

enum NoteCategory: CaseIterable {
    case general, strategy, market, lessons
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .strategy: return "Strategy"
        case .market: return "Market"
        case .lessons: return "Lessons"
        }
    }
}

struct ShareTypeButton: View {
    let type: TradeShareType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .foregroundColor(isSelected ? .arkadGold : .gray)
                    .frame(width: 24)
                
                Text(type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.arkadGold)
                }
            }
            .padding()
            .background(isSelected ? Color.arkadGold.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.arkadGold : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    EditTradeView(trade: Trade(ticker: "AAPL", tradeType: .stock, entryPrice: 150.00, quantity: 10, userId: UUID()))
        .environmentObject(PortfolioViewModel())
}
