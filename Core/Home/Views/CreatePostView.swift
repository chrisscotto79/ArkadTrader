// File: Core/Home/Views/CreatePostView.swift
// Enhanced Create Post View with Trading Features & Media Support

import SwiftUI
import PhotosUI

struct CreatePostView: View {
    let onPost: (String, [String], [UIImage]) -> Void // Updated to include tickers and images
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: FirebaseAuthService
    
    @State private var content = ""
    @State private var selectedPostType: PostType = .text
    @State private var isPosting = false
    @State private var characterCount = 0
    
    // ✅ Trading-specific features
    @State private var detectedTickers: [String] = []
    @State private var profitLoss: String = ""
    @State private var positionSize: String = ""
    @State private var selectedTicker = ""
    @State private var showTradeTemplate = false
    @State private var entryPrice: String = ""
    @State private var exitPrice: String = ""
    
    // ✅ Media support
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var selectedUIImages: [UIImage] = []
    @State private var showImagePicker = false
    
    // UI State
    @State private var showHashtagSuggestions = false
    @State private var suggestedHashtags: [String] = []
    
    private let maxCharacters = 280
    private let maxImages = 4
    
    // ✅ Common stock tickers for suggestions
    private let popularTickers = [
        "AAPL", "TSLA", "NVDA", "MSFT", "GOOGL", "AMZN", "META", "AMD",
        "NFLX", "SPY", "QQQ", "IWM", "PLTR", "GME", "AMC", "BB"
    ]
    
    // ✅ Trading hashtags
    private let tradingHashtags = [
        "#DayTrading", "#SwingTrading", "#Options", "#StockMarket",
        "#TechnicalAnalysis", "#Bullish", "#Bearish", "#BreakoutTrade",
        "#PaperHands", "#DiamondHands", "#HODL", "#ToTheMoon", "#Profit",
        "#StopLoss", "#RiskManagement", "#Trading", "#Stocks", "#Charts"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // ✅ Enhanced Post Type Selector
                    postTypeSelector
                    
                    // ✅ Content Input Section
                    contentSection
                    
                    // ✅ Trading-specific inputs (shown based on post type)
                    if selectedPostType == .tradeResult {
                        tradeResultSection
                    }
                    
                    // ✅ Ticker Detection & Suggestions
                    if !detectedTickers.isEmpty || selectedPostType != .text {
                        tickerSection
                    }
                    
                    // ✅ Media Upload Section
                    mediaSection
                    
                    // ✅ Hashtag Suggestions
                    hashtagSection
                    
                    // ✅ Preview Section
                    if !content.isEmpty {
                        postPreview
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        createPost()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(canPost ? .arkadGold : .gray)
                    .disabled(!canPost || isPosting)
                }
            }
        }
        .onChange(of: content) { _ in
            updateCharacterCount()
            detectTickers()
            generateHashtagSuggestions()
        }
        .onChange(of: selectedImages) { _ in
            loadSelectedImages()
        }
    }
    
    // MARK: - UI Components
    
    private var postTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Post Type")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                ForEach(PostType.allCases, id: \.self) { type in
                    Button(action: {
                        withAnimation(.spring()) {
                            selectedPostType = type
                            if type == .tradeResult && content.isEmpty {
                                insertTradeTemplate()
                            }
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: postTypeIcon(for: type))
                                .font(.title2)
                                .foregroundColor(selectedPostType == type ? .white : .arkadGold)
                            
                            Text(type.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(selectedPostType == type ? .white : .arkadGold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedPostType == type ? Color.arkadGold : Color.arkadGold.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Content")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(characterCount)/\(maxCharacters)")
                    .font(.caption)
                    .foregroundColor(characterCount > maxCharacters ? .red : .gray)
            }
            
            TextField(placeholderText, text: $content, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(8, reservesSpace: true)
                .padding(12)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
    
    // ✅ Trading-specific section
    private var tradeResultSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.arkadGold)
                Text("Trade Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Template") {
                    insertTradeTemplate()
                }
                .font(.caption)
                .foregroundColor(.arkadGold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.arkadGold.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Trade input fields
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Profit/Loss")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    TextField("$0.00", text: $profitLoss)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Position Size")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    TextField("100 shares", text: $positionSize)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Entry Price")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    TextField("$0.00", text: $entryPrice)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Exit Price")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    TextField("$0.00", text: $exitPrice)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
    
    // ✅ Ticker detection section
    private var tickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dollarsign.circle")
                    .foregroundColor(.arkadGold)
                Text("Stock Tickers")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !detectedTickers.isEmpty {
                    Text("\(detectedTickers.count) detected")
                        .font(.caption)
                        .foregroundColor(.arkadGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.arkadGold.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Detected tickers
            if !detectedTickers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(detectedTickers, id: \.self) { ticker in
                            HStack(spacing: 4) {
                                Text("$\(ticker)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Button(action: {
                                    removeTicker(ticker)
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.arkadGold)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            
            // Popular ticker suggestions
            Text("Quick Add:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(popularTickers.prefix(8), id: \.self) { ticker in
                    Button(action: {
                        addTicker(ticker)
                    }) {
                        Text("$\(ticker)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(detectedTickers.contains(ticker) ? .gray : .arkadGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.arkadGold.opacity(detectedTickers.contains(ticker) ? 0.05 : 0.1))
                            .cornerRadius(8)
                    }
                    .disabled(detectedTickers.contains(ticker))
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
    
    // ✅ Media upload section
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo")
                    .foregroundColor(.arkadGold)
                Text("Charts & Screenshots")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !selectedUIImages.isEmpty {
                    Text("\(selectedUIImages.count)/\(maxImages)")
                        .font(.caption)
                        .foregroundColor(.arkadGold)
                }
            }
            
            // Image preview grid
            if !selectedUIImages.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(Array(selectedUIImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .clipped()
                                .cornerRadius(8)
                            
                            Button(action: {
                                removeImage(at: index)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .padding(8)
                        }
                    }
                }
            }
            
            // Photo picker button
            PhotosPicker(
                selection: $selectedImages,
                maxSelectionCount: maxImages,
                matching: .images
            ) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.arkadGold)
                    Text("Add Charts/Screenshots")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.arkadGold.opacity(0.1))
                .cornerRadius(8)
            }
            .disabled(selectedUIImages.count >= maxImages)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
    
    // ✅ Hashtag suggestions
    private var hashtagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "number")
                    .foregroundColor(.arkadGold)
                Text("Suggested Hashtags")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestedHashtags, id: \.self) { hashtag in
                        Button(action: {
                            addHashtag(hashtag)
                        }) {
                            Text(hashtag)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.arkadGold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.arkadGold.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
    
    // ✅ Post preview
    private var postPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Mini post preview
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.arkadGold.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(authService.currentUser?.username.prefix(1) ?? "U").uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.arkadGold)
                        )
                    
                    Text("@\(authService.currentUser?.username ?? "username")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("now")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text(content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !selectedUIImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(selectedUIImages.enumerated()), id: \.offset) { index, image in
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
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
    
    // MARK: - Helper Methods
    
    private var canPost: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        characterCount <= maxCharacters &&
        !isPosting
    }
    
    private var placeholderText: String {
        switch selectedPostType {
        case .text:
            return "What's on your mind about the market?"
        case .tradeResult:
            return "Share your trade results and what you learned..."
        case .marketAnalysis:
            return "Share your market analysis and predictions..."
        }
    }
    
    private func postTypeIcon(for type: PostType) -> String {
        switch type {
        case .text: return "text.bubble"
        case .tradeResult: return "chart.line.uptrend.xyaxis"
        case .marketAnalysis: return "magnifyingglass"
        }
    }
    
    private func updateCharacterCount() {
        characterCount = content.count
    }
    
    // ✅ Ticker detection logic
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
                content += " $\(ticker)"
            }
        }
    }
    
    private func removeTicker(_ ticker: String) {
        detectedTickers.removeAll { $0 == ticker }
        content = content.replacingOccurrences(of: " $\(ticker)", with: "")
    }
    
    // ✅ Media handling
    private func loadSelectedImages() {
        Task {
            var newImages: [UIImage] = []
            
            for item in selectedImages {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    newImages.append(image)
                }
            }
            
            await MainActor.run {
                selectedUIImages = newImages
            }
        }
    }
    
    private func removeImage(at index: Int) {
        selectedUIImages.remove(at: index)
        selectedImages.remove(at: index)
    }
    
    // ✅ Hashtag suggestions
    private func generateHashtagSuggestions() {
        var suggestions: [String] = []
        
        // Add type-specific hashtags
        switch selectedPostType {
        case .text:
            suggestions = ["#Trading", "#StockMarket", "#Investing"]
        case .tradeResult:
            suggestions = ["#TradeResult", "#Profit", "#DayTrading", "#Position"]
        case .marketAnalysis:
            suggestions = ["#Analysis", "#TechnicalAnalysis", "#MarketOutlook", "#Charts"]
        }
        
        // Add profit/loss specific hashtags
        if content.lowercased().contains("profit") || content.contains("$") {
            suggestions.append("#Profit")
        }
        if content.lowercased().contains("loss") {
            suggestions.append("#Loss")
        }
        
        // Add ticker-specific hashtags
        for ticker in detectedTickers {
            suggestions.append("#\(ticker)")
        }
        
        // Filter out hashtags already in content
        suggestions = suggestions.filter { !content.contains($0) }
        
        suggestedHashtags = Array(Set(suggestions)).prefix(6).map { String($0) }
    }
    
    private func addHashtag(_ hashtag: String) {
        if !content.contains(hashtag) {
            content += " \(hashtag)"
        }
    }
    
    // ✅ Trading templates
    private func insertTradeTemplate() {
        let template = """
        Just closed my position! 📈
        
        Trade: [Ticker]
        Entry: $[Entry Price]
        Exit: $[Exit Price]
        Size: [Position Size]
        P&L: $[Profit/Loss]
        
        [What did you learn from this trade?]
        """
        
        if content.isEmpty {
            content = template
        }
    }
    
    private func createPost() {
        guard canPost else { return }
        
        isPosting = true
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Call the enhanced onPost with tickers and images
        onPost(content, detectedTickers, selectedUIImages)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}
