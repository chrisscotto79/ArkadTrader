// File: Core/Home/Views/CreatePostView.swift
// The post composer sheet: post type, text, photos, tickers, hashtags and (for trade results) trade numbers.

import SwiftUI
import PhotosUI

/// What the composer hands back when the user taps Post
struct PostDraft {
    var content: String
    var tickers: [String]
    var images: [UIImage]
    var postType: PostType
    /// The Trade Details fields, for trade result posts that filled any in
    var tradingData: TradingData?
}

struct CreatePostView: View {
    // MARK: - Properties
    let onPost: (PostDraft) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: FirebaseAuthService

    // Content
    @State private var content = ""
    @State private var selectedPostType: PostType = .text
    @State private var characterCount = 0
    @State private var isPosting = false

    // Trade details
    @State private var detectedTickers: [String] = []
    @State private var profitLoss: String = ""
    @State private var positionSize: String = ""
    @State private var entryPrice: String = ""
    @State private var exitPrice: String = ""
    @State private var tradeTicker: String = ""
    @State private var tradeType: TradingData.TradeType?
    @State private var lastTemplate: TemplateType?

    // Media
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var selectedUIImages: [UIImage] = []
    @State private var isLoadingImages = false
    @State private var imageLoadingProgress: Double = 0

    // UI
    @State private var suggestedHashtags: [String] = []
    @State private var showPreview = false
    @State private var showDiscardConfirmation = false
    @FocusState private var focusedField: ComposerField?

    private enum ComposerField: Hashable {
        case message, ticker, profitLoss, size, entry, exit
    }

    // MARK: - Constants
    struct Constants {
        static let maxCharacters = 500
        static let maxImages = 6
        static let warningThreshold = 450
    }

    // MARK: - Data
    // Widely traded, liquid US tickers (stocks and ETFs)
    private let popularTickers = [
        "SPY", "QQQ", "IWM", "AAPL", "NVDA", "MSFT", "AMZN", "GOOGL",
        "META", "TSLA", "AVGO", "AMD", "NFLX", "PLTR", "COIN", "HOOD",
        "MSTR", "UBER", "SHOP", "XYZ", "PYPL", "JPM", "COST", "LLY", "SMCI"
    ]

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.l) {
                    SegmentedPicker(options: PostType.allCases, selection: postTypeBinding) { shortTitle(for: $0) }

                    composerCard

                    if selectedPostType == .tradeResult {
                        tradeResultSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if shouldShowTickerSection {
                        tickerSection
                    }

                    if !suggestedHashtags.isEmpty {
                        hashtagSection
                    }

                    if shouldShowPreview {
                        postPreview
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xxl)
                .animation(.snappy(duration: 0.3), value: selectedPostType)
                .animation(.snappy(duration: 0.3), value: shouldShowPreview)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .overlay { if isLoadingImages { loadingOverlay } }
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .onAppear { setupView() }
            .task {
                // Open the keyboard once the sheet has settled
                try? await Task.sleep(nanoseconds: 450_000_000)
                if content.isEmpty { focusedField = .message }
            }
            .onChange(of: content) { _, _ in handleContentChange() }
            .onChange(of: selectedImages) { _, _ in loadSelectedImages() }
            .confirmationDialog("Discard this post?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            }
        }
        .interactiveDismissDisabled(hasDraft)
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { handleCancel() }
                .foregroundStyle(Color.primary)
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(action: createPost) {
                if isPosting {
                    ProgressView().tint(Color.onGold)
                } else {
                    Text("Post")
                }
            }
            .buttonStyle(PillButtonStyle(kind: .gold))
            .disabled(!canPost || isPosting)
        }

        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { focusedField = nil }
                .fontWeight(.semibold)
        }
    }

    // MARK: - Composer

    private var postTypeBinding: Binding<PostType> {
        Binding(get: { selectedPostType }, set: { selectPostType($0) })
    }

    private func shortTitle(for type: PostType) -> String {
        switch type {
        case .text: return "Post"
        case .tradeResult: return "Trade result"
        case .marketAnalysis: return "Analysis"
        }
    }

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                UserAvatar(
                    username: authService.currentUser?.username ?? "",
                    imageURL: authService.currentUser?.profileImageUrl,
                    size: 40
                )
                editor
            }

            if !selectedUIImages.isEmpty {
                selectedImagesStrip
            }

            Divider().overlay(Color.hairline)

            attachmentBar
        }
        .cardStyle()
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if content.isEmpty {
                Text(placeholderText)
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $content)
                .font(.body)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .message)
                .frame(minHeight: 140)
        }
    }

    private var selectedImagesStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s) {
                ForEach(Array(selectedUIImages.enumerated()), id: \.offset) { index, image in
                    ComposerImageThumbnail(image: image) {
                        removeImage(at: index)
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    /// Photos, $ticker, #hashtag, preview and the character count.
    private var attachmentBar: some View {
        HStack(spacing: DS.Spacing.xs) {
            PhotosPicker(
                selection: $selectedImages,
                maxSelectionCount: max(1, Constants.maxImages - selectedUIImages.count),
                matching: .images
            ) {
                composerToolIcon("photo.on.rectangle.angled")
            }
            .disabled(selectedUIImages.count >= Constants.maxImages)
            .accessibilityLabel("Add photos")

            Button { insertToken("$") } label: { composerToolIcon("dollarsign") }
                .accessibilityLabel("Add a ticker")

            Button { insertToken("#") } label: { composerToolIcon("number") }
                .accessibilityLabel("Add a hashtag")

            Button { togglePreview() } label: {
                composerToolIcon(showPreview ? "eye.slash" : "eye", isActive: showPreview)
            }
            .accessibilityLabel(showPreview ? "Hide preview" : "Show preview")

            Spacer(minLength: 0)

            characterCountView
        }
        .buttonStyle(PressableStyle())
    }

    private func composerToolIcon(_ systemName: String, isActive: Bool = false) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isActive ? Color.goldText : Color.secondary)
            .frame(width: 36, height: 36)
            .background(Circle().fill(isActive ? Color.goldTint : Color.clear))
            .contentShape(Circle())
    }

    private var characterCountView: some View {
        HStack(spacing: 6) {
            if characterCount >= Constants.warningThreshold {
                Text("\(Constants.maxCharacters - characterCount)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(characterCountColor)
            }
            ZStack {
                Circle()
                    .stroke(Color.hairline, lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: min(1, Double(characterCount) / Double(Constants.maxCharacters)))
                    .stroke(characterCountColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 20, height: 20)
            .animation(.snappy(duration: 0.2), value: characterCount)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(characterCount) of \(Constants.maxCharacters) characters")
    }

    private var characterCountColor: Color {
        if characterCount > Constants.maxCharacters {
            return .marketRed
        } else if characterCount > Constants.warningThreshold {
            return .warning
        } else {
            return .goldText
        }
    }

    // MARK: - Trade details

    private var tradeResultSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack {
                Text("Trade details")
                    .font(.headline)
                Spacer()
                Menu {
                    Button("Profit") { insertTemplate(.profit) }
                    Button("Loss") { insertTemplate(.loss) }
                    Button("Options") { insertTemplate(.options) }
                } label: {
                    Label("Templates", systemImage: "doc.text")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.goldText)
                }
            }

            VStack(spacing: DS.Spacing.m) {
                TradeFieldBox(label: "Ticker") {
                    TextField(detectedTickers.first ?? "AAPL", text: $tradeTicker)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .ticker)
                }

                HStack(spacing: DS.Spacing.m) {
                    TradeFieldBox(label: "Profit / loss") {
                        TextField(computedProfitLoss.map { String(format: "%.2f", $0) } ?? "0.00", text: $profitLoss)
                            .keyboardType(.numbersAndPunctuation)
                            .focused($focusedField, equals: .profitLoss)
                    }
                    TradeFieldBox(label: "Position size") {
                        TextField(tradeType == .options ? "2 contracts" : "100 shares", text: $positionSize)
                            .focused($focusedField, equals: .size)
                    }
                }

                HStack(spacing: DS.Spacing.m) {
                    TradeFieldBox(label: "Entry price") {
                        TextField("0.00", text: $entryPrice)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .entry)
                    }
                    TradeFieldBox(label: "Exit price") {
                        TextField("0.00", text: $exitPrice)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .exit)
                    }
                }
            }

            Text("These numbers show as a trade card on your post. Leave P&L blank to work it out from entry, exit and size; use a minus sign for a loss.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    // MARK: - Tickers

    /// Tickers in the post first, then popular ones to add with a tap.
    private var tickerChoices: [String] {
        detectedTickers + popularTickers.prefix(10).filter { !detectedTickers.contains($0) }
    }

    private var tickerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack {
                Text("Tickers")
                    .font(.headline)
                if !detectedTickers.isEmpty {
                    Text("\(detectedTickers.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.s) {
                    ForEach(tickerChoices, id: \.self) { ticker in
                        let isAdded = detectedTickers.contains(ticker)
                        Chip(
                            title: "$\(ticker)",
                            systemImage: isAdded ? "xmark" : "plus",
                            isSelected: isAdded
                        ) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            if isAdded { removeTicker(ticker) } else { addTicker(ticker) }
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
        .cardStyle()
    }

    // MARK: - Hashtags

    private var hashtagSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Text("Suggested hashtags")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.s) {
                    ForEach(suggestedHashtags, id: \.self) { hashtag in
                        Chip(title: hashtag, isSelected: false) {
                            addHashtag(hashtag)
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
        .cardStyle()
    }

    // MARK: - Preview

    private var postPreview: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Preview")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, DS.Spacing.xs)

            ComposerPreviewCard(
                content: content,
                user: authService.currentUser,
                images: selectedUIImages,
                postType: selectedPostType,
                tradingData: buildTradingData()
            )
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()

            VStack(spacing: DS.Spacing.m) {
                ProgressView(value: imageLoadingProgress)
                    .progressViewStyle(.linear)
                    .tint(Color.arkadGold)
                    .frame(width: 140)
                Text("Adding photos…")
                    .font(.subheadline.weight(.medium))
            }
            .padding(DS.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .fill(.regularMaterial)
            )
        }
        .transition(.opacity)
    }

    // MARK: - Computed Properties

    private var canPost: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        characterCount <= Constants.maxCharacters &&
        !isPosting
    }

    private var hasDraft: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedUIImages.isEmpty
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
            return "How did the trade go?"
        case .marketAnalysis:
            return "Share your read on the market…"
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
        if hasDraft {
            showDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func togglePreview() {
        withAnimation(.snappy(duration: 0.3)) {
            showPreview.toggle()
        }
    }

    private func selectPostType(_ type: PostType) {
        withAnimation(.snappy(duration: 0.3)) {
            selectedPostType = type
            if type == .tradeResult && content.isEmpty {
                insertTradeTemplate()
            }
        }
        generateHashtagSuggestions()
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

        // Keep the order they were typed in
        var seen = Set<String>()
        detectedTickers = tickers.filter { seen.insert($0).inserted }
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

    /// Adds "$" or "#" at the end of the text and puts the cursor back in the editor.
    private func insertToken(_ token: String) {
        if content.isEmpty || content.hasSuffix(" ") || content.hasSuffix("\n") {
            content += token
        } else {
            content += " \(token)"
        }
        focusedField = .message
    }

    private func loadSelectedImages() {
        guard !selectedImages.isEmpty else { return }

        withAnimation { isLoadingImages = true }
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
                withAnimation { isLoadingImages = false }
                imageLoadingProgress = 0
            }
        }
    }

    private func removeImage(at index: Int) {
        withAnimation(.snappy(duration: 0.25)) {
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

        // Drop ones already in the text, keep order, limit
        var seen = Set<String>()
        suggestedHashtags = suggestions
            .filter { !content.contains($0) && seen.insert($0).inserted }
            .prefix(6)
            .map { String($0) }
    }

    private func addHashtag(_ hashtag: String) {
        if !content.contains(hashtag) {
            content += content.isEmpty ? hashtag : " \(hashtag)"
        }
    }

    private enum TemplateType {
        case profit, loss, options
    }

    /// Starts the post text. The numbers go in the Trade Details fields, not the text, so nothing
    /// is left as "$[Entry]" if someone types inside a placeholder.
    private func insertTemplate(_ type: TemplateType) {
        switch type {
        case .profit:
            content = "🎉 Just closed a profitable trade!\n\nWhat worked: "
            if tradeType == .options { tradeType = nil }
        case .loss:
            content = "📉 Closed a position for a loss.\n\nLesson learned: "
            if tradeType == .options { tradeType = nil }
        case .options:
            content = "⚡ Options trade update\n\nStrategy: "
            tradeType = .options
        }
        lastTemplate = type
    }

    /// P&L worked out from entry, exit and size, used when the P&L field is blank
    private var computedProfitLoss: Double? {
        guard let entry = TradingData.parseAmount(entryPrice),
              let exit = TradingData.parseAmount(exitPrice),
              let firstWord = positionSize.split(separator: " ").first,
              let quantity = TradingData.parseAmount(String(firstWord)), quantity > 0
        else { return nil }
        let multiplier: Double = tradeType == .options ? 100 : 1
        return (exit - entry) * quantity * multiplier
    }

    /// The Trade Details fields as TradingData, or nil when it isn't a trade post or nothing was filled in
    private func buildTradingData() -> TradingData? {
        guard selectedPostType == .tradeResult else { return nil }

        var pnl = TradingData.parseAmount(profitLoss)
        if let typed = pnl, lastTemplate == .loss, typed > 0, !profitLoss.contains("+") {
            pnl = -typed   // "50" on a loss post means -$50
        }
        if pnl == nil { pnl = computedProfitLoss }

        let ticker = (tradeTicker.isEmpty ? detectedTickers.first ?? "" : tradeTicker)
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespaces)
            .uppercased()
        let size = positionSize.trimmingCharacters(in: .whitespaces)
        let entry = TradingData.parseAmount(entryPrice)
        let exit = TradingData.parseAmount(exitPrice)

        guard pnl != nil || entry != nil || exit != nil || !size.isEmpty || !ticker.isEmpty else { return nil }

        var data = TradingData()
        data.profitLoss = pnl
        data.entryPrice = entry
        data.exitPrice = exit
        data.positionSize = size.isEmpty ? nil : size
        data.ticker = ticker.isEmpty ? nil : ticker
        data.tradeType = tradeType
        return data
    }

    private func insertTradeTemplate() {
        insertTemplate(.profit)
    }

    private func createPost() {
        guard canPost else { return }

        isPosting = true
        focusedField = nil

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Short pause so the button state is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let tradingData = buildTradingData()
            var tickers = detectedTickers
            if let ticker = tradingData?.ticker, !tickers.contains(ticker) {
                tickers.insert(ticker, at: 0)
            }
            onPost(PostDraft(
                content: content,
                tickers: tickers,
                images: selectedUIImages,
                postType: selectedPostType,
                tradingData: tradingData
            ))

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        }
    }
}

// MARK: - Supporting Views

/// Labelled input on a raised fill, for the Trade Details fields.
private struct TradeFieldBox<Field: View>: View {
    let label: String
    @ViewBuilder var field: () -> Field

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            field()
                .font(.body.monospacedDigit())
                .padding(.horizontal, DS.Spacing.m)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .fill(Color.surfaceRaised)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A picked photo in the composer, with a remove button.
private struct ComposerImageThumbnail: View {
    let image: UIImage
    let onRemove: () -> Void

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
                .padding(6)
                .accessibilityLabel("Remove photo")
            }
    }
}

/// How the post will look in the feed.
private struct ComposerPreviewCard: View {
    let content: String
    let user: User?
    let images: [UIImage]
    let postType: PostType
    var tradingData: TradingData? = nil

    private var displayName: String {
        if let name = user?.fullName, !name.isEmpty { return name }
        return user?.username ?? "You"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(spacing: DS.Spacing.m) {
                UserAvatar(username: user?.username ?? "", imageURL: user?.profileImageUrl, size: 42)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if postType != .text {
                            Tag(text: postType.displayName)
                        }
                    }
                    Text("@\(user?.username ?? "you") · now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            if !content.isEmpty {
                Text(content)
                    .font(.body)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let tradingData, tradingData.profitLossValue != nil {
                TradeSummaryCard(trade: tradingData)
            }

            if let first = images.first {
                Image(uiImage: first)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        if images.count > 1 {
                            Text("+\(images.count - 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.black.opacity(0.6)))
                                .padding(DS.Spacing.s)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    CreatePostView { draft in
        print("Draft: \(draft.content), tickers \(draft.tickers), \(draft.images.count) images")
    }
    .environmentObject(FirebaseAuthService.shared)
}
