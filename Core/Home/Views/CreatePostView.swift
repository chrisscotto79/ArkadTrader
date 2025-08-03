// File: Core/Home/Views/CreatePostView.swift
// Enhanced Create Post View with Trading Features & Media Support

import SwiftUI
import PhotosUI

struct CreatePostView: View {
    // MARK: - Properties
    let onPost: (String, [String], [UIImage]) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: FirebaseAuthService
    
    // MARK: - State Variables
    
    // Content State
    @State private var content = ""
    @State private var selectedPostType: PostType = .text
    @State private var characterCount = 0
    @State private var isPosting = false
    
    // Trading State
    @State private var detectedTickers: [String] = []
    @State private var profitLoss: String = ""
    @State private var positionSize: String = ""
    @State private var entryPrice: String = ""
    @State private var exitPrice: String = ""
    @State private var showTradeTemplate = false
    
    // Media State
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var selectedUIImages: [UIImage] = []
    @State private var isLoadingImages = false
    @State private var imageLoadingProgress: Double = 0
    
    // UI State
    @State private var suggestedHashtags: [String] = []
    @State private var showPreview = false
    @State private var keyboardHeight: CGFloat = 0
    
    // MARK: - Constants
    struct Constants {
        static let maxCharacters = 500 // Increased for richer content
        static let maxImages = 6 // Increased limit
        static let warningThreshold = 450 // Character warning threshold
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 4
        static let animationDuration: Double = 0.3
    }
    
    // MARK: - Data
    private let popularTickers = [
        "AAPL", "TSLA", "NVDA", "MSFT", "GOOGL", "AMZN", "META", "AMD",
        "NFLX", "SPY", "QQQ", "IWM", "PLTR", "GME", "AMC", "BB", "COIN",
        "SHOP", "SQ", "PYPL", "ROKU", "ZM", "SPOT", "UBER", "LYFT"
    ]
    
    private let tradingHashtags = [
        "#DayTrading", "#SwingTrading", "#Options", "#StockMarket",
        "#TechnicalAnalysis", "#Bullish", "#Bearish", "#BreakoutTrade",
        "#PaperHands", "#DiamondHands", "#HODL", "#ToTheMoon", "#Profit",
        "#StopLoss", "#RiskManagement", "#Trading", "#Stocks", "#Charts",
        "#Momentum", "#Support", "#Resistance", "#Volume", "#Earnings"
    ]
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        postTypeSelector
                        contentSection
                        
                        if selectedPostType == .tradeResult {
                            tradeResultSection
                        }
                        
                        if shouldShowTickerSection {
                            tickerSection
                        }
                        
                        mediaSection
                        
                        if !suggestedHashtags.isEmpty {
                            hashtagSection
                        }
                        
                        if shouldShowPreview {
                            postPreview
                        }
                        
                        // Bottom spacing for keyboard
                        Spacer(minLength: max(100, keyboardHeight))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Loading overlay
                if isLoadingImages {
                    loadingOverlay
                }
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .onAppear { setupView() }
            .onChange(of: content) { _, _ in handleContentChange() }
            .onChange(of: selectedImages) { _, _ in loadSelectedImages() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                handleKeyboardShow(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                handleKeyboardHide()
            }
        }
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                handleCancel()
            }
            .foregroundColor(.arkadGold)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                // Preview toggle
                Button(action: { togglePreview() }) {
                    Image(systemName: showPreview ? "eye.slash" : "eye")
                        .foregroundColor(.arkadGold)
                }
                
                // Post button
                Button("Post") {
                    createPost()
                }
                .fontWeight(.bold)
                .foregroundColor(canPost ? .white : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(canPost ? Color.arkadGold : Color.gray.opacity(0.3))
                .cornerRadius(20)
                .disabled(!canPost || isPosting)
                .scaleEffect(isPosting ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPosting)
            }
        }
    }
    
    // MARK: - UI Components
    
    private var postTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.3x3")
                    .foregroundColor(.arkadGold)
                Text("Post Type")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            HStack(spacing: 12) {
                ForEach(PostType.allCases, id: \.self) { type in
                    postTypeButton(for: type)
                }
            }
        }
        .createPostCardStyle()
    }
    
    private func postTypeButton(for type: PostType) -> some View {
        Button(action: {
            selectPostType(type)
        }) {
            VStack(spacing: 8) {
                Image(systemName: postTypeIcon(for: type))
                    .font(.title2)
                    .foregroundColor(selectedPostType == type ? .white : .arkadGold)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(selectedPostType == type ? .white : .arkadGold)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(selectedPostType == type ? Color.arkadGold : Color.arkadGold.opacity(0.1))
            .cornerRadius(Constants.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .stroke(selectedPostType == type ? Color.arkadGold : Color.clear, lineWidth: 2)
            )
            .scaleEffect(selectedPostType == type ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedPostType)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundColor(.arkadGold)
                Text("Content")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                characterCountView
            }
            
            TextEditor(text: $content)
                .font(.body)
                .frame(minHeight: 120)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(Constants.cornerRadius)
                .overlay(
                    // Placeholder
                    Group {
                        if content.isEmpty {
                            Text(placeholderText)
                                .foregroundColor(.secondary)
                                .font(.body)
                                .allowsHitTesting(false)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                        }
                    },
                    alignment: .topLeading
                )
            
            // Quick action buttons
            HStack(spacing: 12) {
                if selectedPostType == .tradeResult {
                    quickActionButton(title: "Template", icon: "doc.text", action: insertTradeTemplate)
                }
                
                quickActionButton(title: "Add Ticker", icon: "dollarsign.circle", action: showTickerInput)
                quickActionButton(title: "Add Hashtag", icon: "number", action: showHashtagInput)
                
                Spacer()
            }
        }
        .createPostCardStyle()
    }
    
    private var characterCountView: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(characterCount)/\(Constants.maxCharacters)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(characterCountColor)
            
            // Progress bar
            ProgressView(value: Double(characterCount), total: Double(Constants.maxCharacters))
                .progressViewStyle(LinearProgressViewStyle(tint: characterCountColor))
                .frame(width: 60)
                .scaleEffect(y: 0.5)
        }
    }
    
    private var characterCountColor: Color {
        if characterCount > Constants.maxCharacters {
            return .red
        } else if characterCount > Constants.warningThreshold {
            return .orange
        } else {
            return .arkadGold
        }
    }
    
    // MARK: - Trade Result Section (Clean Version)
    private var tradeResultSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.arkadGold)
                Text("Trade Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Menu {
                    Button("Profit Template") { insertTemplate(.profit) }
                    Button("Loss Template") { insertTemplate(.loss) }
                    Button("Options Template") { insertTemplate(.options) }
                } label: {
                    HStack(spacing: 4) {
                        Text("Templates")
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(.arkadGold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.arkadGold.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Input fields with proper layout
            VStack(spacing: 16) {
                // First row: Profit/Loss and Position Size
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Profit/Loss")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            TextField("0.00", text: $profitLoss)
                                .font(.body)
                                .keyboardType(.decimalPad)
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Position Size")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            
                            TextField("100 shares", text: $positionSize)
                                .font(.body)
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
                
                // Second row: Entry and Exit Price
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Entry Price")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            
                            TextField("0.00", text: $entryPrice)
                                .font(.body)
                                .keyboardType(.decimalPad)
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Exit Price")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            
                            TextField("0.00", text: $exitPrice)
                                .font(.body)
                                .keyboardType(.decimalPad)
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .createPostCardStyle()
    }
    
    private var tickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.arkadGold)
                Text("Stock Tickers")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !detectedTickers.isEmpty {
                    Badge(text: "\(detectedTickers.count)", color: .arkadGold)
                }
            }
            
            // Detected tickers
            if !detectedTickers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(detectedTickers, id: \.self) { ticker in
                            TickerChip(ticker: ticker) {
                                removeTicker(ticker)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            
            // Popular ticker suggestions
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Add:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(popularTickers.prefix(8), id: \.self) { ticker in
                        Button(action: { addTicker(ticker) }) {
                            Text("$\(ticker)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(detectedTickers.contains(ticker) ? .secondary : .arkadGold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.arkadGold.opacity(detectedTickers.contains(ticker) ? 0.05 : 0.15))
                                .cornerRadius(8)
                        }
                        .disabled(detectedTickers.contains(ticker))
                    }
                }
            }
        }
        .createPostCardStyle()
    }
    
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.stack")
                    .foregroundColor(.arkadGold)
                Text("Charts & Screenshots")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !selectedUIImages.isEmpty {
                    Badge(text: "\(selectedUIImages.count)/\(Constants.maxImages)", color: .arkadGold)
                }
            }
            
            // Image grid
            if !selectedUIImages.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(Array(selectedUIImages.enumerated()), id: \.offset) { index, image in
                        ImagePreview(image: image) {
                            removeImage(at: index)
                        }
                    }
                }
            }
            
            // Photo picker
            PhotosPicker(
                selection: $selectedImages,
                maxSelectionCount: Constants.maxImages - selectedUIImages.count,
                matching: .images
            ) {
                HStack {
                    Image(systemName: selectedUIImages.isEmpty ? "plus.circle.fill" : "plus")
                        .foregroundColor(.arkadGold)
                    Text(selectedUIImages.isEmpty ? "Add Charts/Screenshots" : "Add More")
                        .fontWeight(.medium)
                        .foregroundColor(.arkadGold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.arkadGold.opacity(0.1))
                .cornerRadius(Constants.cornerRadius)
            }
            .disabled(selectedUIImages.count >= Constants.maxImages)
        }
        .createPostCardStyle()
    }
    
    private var hashtagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(.arkadGold)
                Text("Suggested Hashtags")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestedHashtags, id: \.self) { hashtag in
                        Button(action: { addHashtag(hashtag) }) {
                            Text(hashtag)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.arkadGold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.arkadGold.opacity(0.15))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .createPostCardStyle()
    }
    
    private var postPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye")
                    .foregroundColor(.arkadGold)
                Text("Preview")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            PostPreviewCard(
                content: content,
                username: authService.currentUser?.username ?? "username",
                images: selectedUIImages,
                postType: selectedPostType
            )
        }
        .createPostCardStyle()
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView(value: imageLoadingProgress)
                    .progressViewStyle(CircularProgressViewStyle(tint: .arkadGold))
                    .scaleEffect(1.5)
                
                Text("Loading images...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Helper Views
    
    private func quickActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.arkadGold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.arkadGold.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Computed Properties
    
    private var canPost: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        characterCount <= Constants.maxCharacters &&
        !isPosting
    }
    
    private var shouldShowTickerSection: Bool {
        !detectedTickers.isEmpty || selectedPostType != .text
    }
    
    private var shouldShowPreview: Bool {
        showPreview && (!content.isEmpty || !selectedUIImages.isEmpty)
    }
    
    private var placeholderText: String {
        switch selectedPostType {
        case .text:
            return "What's on your mind about the market?"
        case .tradeResult:
            return "Share your trade results and insights..."
        case .marketAnalysis:
            return "Share your market analysis and predictions..."
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupView() {
        generateHashtagSuggestions()
    }
    
    private func handleContentChange() {
        updateCharacterCount()
        detectTickers()
        generateHashtagSuggestions()
    }
    
    private func handleCancel() {
        // Add confirmation if there's content
        if !content.isEmpty || !selectedUIImages.isEmpty {
            // Could add confirmation dialog here
        }
        dismiss()
    }
    
    private func togglePreview() {
        withAnimation(.spring()) {
            showPreview.toggle()
        }
    }
    
    private func selectPostType(_ type: PostType) {
        withAnimation(.spring()) {
            selectedPostType = type
            if type == .tradeResult && content.isEmpty {
                insertTradeTemplate()
            }
        }
    }
    
    private func updateCharacterCount() {
        characterCount = content.count
    }
    
    private func detectTickers() {
        let pattern = "\\$[A-Z]{1,5}\\b"
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        
        let tickers = matches.compactMap { match in
            String(content[Range(match.range, in: content)!]).replacingOccurrences(of: "$", with: "")
        }
        
        detectedTickers = Array(Set(tickers))
    }
    
    private func addTicker(_ ticker: String) {
        if !detectedTickers.contains(ticker) {
            detectedTickers.append(ticker)
            if !content.contains("$\(ticker)") {
                content += content.isEmpty ? "$\(ticker)" : " $\(ticker)"
            }
        }
    }
    
    private func removeTicker(_ ticker: String) {
        detectedTickers.removeAll { $0 == ticker }
        content = content.replacingOccurrences(of: " $\(ticker)", with: "")
        content = content.replacingOccurrences(of: "$\(ticker)", with: "")
    }
    
    private func loadSelectedImages() {
        guard !selectedImages.isEmpty else { return }
        
        isLoadingImages = true
        imageLoadingProgress = 0
        
        Task {
            var newImages: [UIImage] = []
            let totalImages = selectedImages.count
            
            for (index, item) in selectedImages.enumerated() {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    newImages.append(image)
                }
                
                await MainActor.run {
                    imageLoadingProgress = Double(index + 1) / Double(totalImages)
                }
            }
            
            await MainActor.run {
                selectedUIImages = newImages
                isLoadingImages = false
                imageLoadingProgress = 0
            }
        }
    }
    
    private func removeImage(at index: Int) {
        withAnimation(.spring()) {
            selectedUIImages.remove(at: index)
            if index < selectedImages.count {
                selectedImages.remove(at: index)
            }
        }
    }
    
    private func generateHashtagSuggestions() {
        var suggestions: [String] = []
        
        // Type-specific hashtags
        switch selectedPostType {
        case .text:
            suggestions += ["#Trading", "#StockMarket", "#Investing"]
        case .tradeResult:
            suggestions += ["#TradeResult", "#DayTrading", "#Position"]
        case .marketAnalysis:
            suggestions += ["#Analysis", "#TechnicalAnalysis", "#MarketOutlook"]
        }
        
        // Content-based hashtags
        let lowercasedContent = content.lowercased()
        if lowercasedContent.contains("profit") || lowercasedContent.contains("gain") {
            suggestions.append("#Profit")
        }
        if lowercasedContent.contains("loss") || lowercasedContent.contains("red") {
            suggestions.append("#Loss")
        }
        if lowercasedContent.contains("moon") || lowercasedContent.contains("🚀") {
            suggestions.append("#ToTheMoon")
        }
        
        // Ticker-based hashtags
        for ticker in detectedTickers {
            suggestions.append("#\(ticker)")
        }
        
        // Filter and limit
        suggestions = suggestions.filter { !content.contains($0) }
        suggestedHashtags = Array(Set(suggestions)).prefix(6).map { String($0) }
    }
    
    private func addHashtag(_ hashtag: String) {
        if !content.contains(hashtag) {
            content += content.isEmpty ? hashtag : " \(hashtag)"
        }
    }
    
    private func showTickerInput() {
        // Could implement a ticker search view
    }
    
    private func showHashtagInput() {
        // Could implement a hashtag search view
    }
    
    private enum TemplateType {
        case profit, loss, options
    }
    
    private func insertTemplate(_ type: TemplateType) {
        let template: String
        
        switch type {
        case .profit:
            template = """
            🎉 Just closed a profitable trade!
            
            📈 $[TICKER]
            💰 Entry: $[Entry]
            🎯 Exit: $[Exit]
            📊 Size: [Shares/Contracts]
            💵 P&L: +$[Profit]
            
            Key lesson: [What worked well?]
            """
        case .loss:
            template = """
            📉 Closed position with a loss
            
            📊 $[TICKER]
            💰 Entry: $[Entry]
            🎯 Exit: $[Exit]
            📊 Size: [Shares/Contracts]
            💸 P&L: -$[Loss]
            
            Lesson learned: [What went wrong and how to improve?]
            """
        case .options:
            template = """
            📈 Options trade update
            
            🎯 $[TICKER] [Call/Put] [Strike] [Expiry]
            💰 Entry: $[Entry]
            🎯 Exit: $[Exit]
            📊 Contracts: [Number]
            💵 P&L: $[P&L]
            
            Strategy: [Why this trade?]
            """
        }
        
        content = template
    }
    
    private func insertTradeTemplate() {
        insertTemplate(.profit)
    }
    
    private func postTypeIcon(for type: PostType) -> String {
        switch type {
        case .text: return "text.bubble.fill"
        case .tradeResult: return "chart.line.uptrend.xyaxis"
        case .marketAnalysis: return "magnifyingglass.circle.fill"
        }
    }
    
    private func handleKeyboardShow(_ notification: Notification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            withAnimation(.easeInOut(duration: 0.3)) {
                keyboardHeight = keyboardFrame.height
            }
        }
    }
    
    private func handleKeyboardHide() {
        withAnimation(.easeInOut(duration: 0.3)) {
            keyboardHeight = 0
        }
    }
    
    private func createPost() {
        guard canPost else { return }
        
        isPosting = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Add some processing delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onPost(content, detectedTickers, selectedUIImages)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        }
    }
}

// MARK: - Supporting Views

struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(10)
    }
}

struct TickerChip: View {
    let ticker: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text("$\(ticker)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.arkadGold)
        .cornerRadius(12)
    }
}

struct ImagePreview: View {
    let image: UIImage
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 100)
                .clipped()
                .cornerRadius(8)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(6)
        }
    }
}

struct PostPreviewCard: View {
    let content: String
    let username: String
    let images: [UIImage]
    let postType: PostType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.arkadGold.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(username.prefix(1)).uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.arkadGold)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("@\(username)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if postType != .text {
                            Text(postType.displayName)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.arkadGold)
                                .cornerRadius(6)
                        }
                    }
                    
                    Text("now")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if !content.isEmpty {
                Text(content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 60)
                                .clipped()
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - View Modifier

extension View {
    func createPostCardStyle() -> some View {
        self
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(CreatePostView.Constants.cornerRadius)
            .shadow(color: .black.opacity(0.05), radius: CreatePostView.Constants.shadowRadius)
    }
}

#Preview {
    CreatePostView { content, tickers, images in
        print("Content: \(content)")
        print("Tickers: \(tickers)")
        print("Images: \(images.count)")
    }
    .environmentObject(FirebaseAuthService.shared)
}
