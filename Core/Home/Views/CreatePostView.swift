// File: Core/Home/Views/CreatePostView.swift
// The post composer sheet: post type, text, photos, tickers, hashtags and, for trade results, one of
// your own closed trades. A trade result's numbers and proof label come from that trade (copied into
// the post's tradeSnapshot); there's no typed-in P&L. Photos are hidden while
// AppConfig.mediaUploadsEnabled is off.

import SwiftUI
import PhotosUI

/// What the composer hands back when the user taps Post
struct PostDraft {
    var content: String
    var tickers: [String]
    var images: [UIImage]
    var postType: PostType
    /// For trade result posts: the author's closed trade being shared
    var trade: Trade?
    /// Optional Bullish/Bearish tag (only offered when the post mentions a ticker)
    var sentiment: PostSentiment? = nil
}

struct CreatePostView: View {
    // MARK: - Properties
    /// Saves the post. The sheet stays open until it returns, and shows the error if it throws.
    let onPost: (PostDraft) async throws -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: FirebaseAuthService

    // Content
    @State private var content = ""
    @State private var selectedPostType: PostType = .text
    @State private var characterCount = 0
    @State private var isPosting = false
    @State private var postError: String?

    // Trade result
    @State private var detectedTickers: [String] = []
    /// Bullish/Bearish tag for the post's tickers
    @State private var sentiment: PostSentiment?
    /// The author's closed trades, newest first, to pick from
    @State private var closedTrades: [Trade] = []
    @State private var isLoadingTrades = false
    @State private var tradesLoadFailed = false
    @State private var selectedTrade: Trade?
    @State private var showTradePicker = false
    /// The starter text last inserted, so picking another trade can replace it
    @State private var lastTemplateText: String?

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
        case message
    }

    // MARK: - Constants
    struct Constants {
        static let maxCharacters = Post.maxContentLength
        static let maxImages = 6
        static let warningThreshold = Post.maxContentLength - 100
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
                    if let postError {
                        Label(postError, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.marketRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle(padding: 12)
                            .transition(.opacity)
                    }

                    SegmentedPicker(options: PostType.allCases, selection: postTypeBinding) { shortTitle(for: $0) }

                    composerCard

                    if selectedPostType == .tradeResult {
                        tradeResultSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if shouldShowTickerSection {
                        tickerSection
                    }

                    if showsSentimentPicker {
                        sentimentSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
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
                .animation(.snappy(duration: 0.3), value: showsSentimentPicker)
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
            .sheet(isPresented: $showTradePicker) {
                ClosedTradePickerSheet(trades: closedTrades, selectedId: selectedTrade?.id) { trade in
                    selectTrade(trade)
                }
            }
            .confirmationDialog("Discard this post?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            }
        }
        .interactiveDismissDisabled(hasDraft || isPosting)
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { handleCancel() }
                .foregroundStyle(Color.primary)
                .disabled(isPosting)
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

            if AppConfig.mediaUploadsEnabled && !selectedUIImages.isEmpty {
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
            if AppConfig.mediaUploadsEnabled {
                PhotosPicker(
                    selection: $selectedImages,
                    maxSelectionCount: max(1, Constants.maxImages - selectedUIImages.count),
                    matching: .images
                ) {
                    composerToolIcon("photo.on.rectangle.angled")
                }
                .disabled(selectedUIImages.count >= Constants.maxImages)
                .accessibilityLabel("Add photos")
            }

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

    // MARK: - Trade result

    /// Pick one of your closed trades; the card shows its numbers and proof label.
    private var tradeResultSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack {
                Text("Trade")
                    .font(.headline)
                Spacer()
                if selectedTrade != nil, closedTrades.count > 1 {
                    Button("Change") { showTradePicker = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.goldText)
                }
            }

            if let selectedTrade, let snapshot = TradeSnapshot(trade: selectedTrade) {
                Button { showTradePicker = true } label: {
                    TradeSummaryCard(snapshot: snapshot)
                }
                .buttonStyle(PressableStyle())
                .disabled(closedTrades.count <= 1)
                .accessibilityHint(closedTrades.count > 1 ? "Choose another trade" : "")
            } else if isLoadingTrades {
                HStack(spacing: DS.Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Loading your closed trades…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else if tradesLoadFailed {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    Text("Couldn't load your trades. Check your connection.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Try again") { Task { await loadClosedTrades() } }
                        .buttonStyle(PillButtonStyle(kind: .neutral))
                }
            } else if closedTrades.isEmpty {
                Label("Close a trade in your portfolio to share its result here.", systemImage: "tray")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button("Choose a closed trade") { showTradePicker = true }
                    .buttonStyle(SecondaryButtonStyle())
            }

            Text("Trade results come from your own closed trades: the numbers and the proof label are copied from the trade and can't be edited.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
        .task { if closedTrades.isEmpty && !isLoadingTrades { await loadClosedTrades() } }
    }

    @MainActor
    private func loadClosedTrades() async {
        guard let userId = authService.currentUser?.id else { return }
        isLoadingTrades = true
        tradesLoadFailed = false
        do {
            let trades = try await FirebaseServices.shared.getUserTradesSimple(userId: userId)
            closedTrades = trades
                .filter { !$0.isOpen && $0.exitPrice != nil && $0.userId == userId }
                .sorted { ($0.exitDate ?? $0.entryDate) > ($1.exitDate ?? $1.entryDate) }
            if selectedTrade == nil, let latest = closedTrades.first {
                selectTrade(latest)
            }
        } catch {
            tradesLoadFailed = true
        }
        isLoadingTrades = false
    }

    private func selectTrade(_ trade: Trade) {
        withAnimation(.snappy(duration: 0.25)) {
            selectedTrade = trade
        }
        // Start or refresh the post text, unless the user has written their own
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || content == lastTemplateText {
            let symbol = (trade.tradeType == .stock || trade.tradeType == .option) ? "$\(trade.ticker)" : trade.ticker
            let starter = trade.profitLoss >= 0
                ? "🎉 Closed \(symbol) for a profit.\n\nWhat worked: "
                : "📉 Closed \(symbol) for a loss.\n\nLesson learned: "
            content = starter
            lastTemplateText = starter
        }
    }

    // MARK: - Tickers

    /// Tickers in the post first, then popular ones to add with a tap (none once the post is full).
    private var tickerChoices: [String] {
        guard detectedTickers.count < Post.maxTickers else { return detectedTickers }
        return detectedTickers + popularTickers.prefix(10).filter { !detectedTickers.contains($0) }
    }

    /// True when the text mentions more tickers than a post can be tagged with.
    private var hasTooManyTickers: Bool {
        Cashtag.symbols(in: content).count > Post.maxTickers
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

            if hasTooManyTickers {
                Text("A post can tag up to \(Post.maxTickers) tickers. Only the first \(Post.maxTickers) count.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Sentiment

    /// Offered once the post mentions a ticker (typed, added, or from the shared trade).
    private var showsSentimentPicker: Bool {
        !detectedTickers.isEmpty || (selectedPostType == .tradeResult && selectedTrade != nil)
    }

    private var sentimentSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sentiment")
                    .font(.headline)
                Text("Optional. It counts toward each ticker's Bullish/Bearish meter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SentimentPicker(selection: $sentiment)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                images: AppConfig.mediaUploadsEnabled ? selectedUIImages : [],
                postType: selectedPostType,
                snapshot: selectedPostType == .tradeResult ? selectedTrade.flatMap(TradeSnapshot.init(trade:)) : nil,
                sentiment: showsSentimentPicker ? sentiment : nil
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
        (selectedPostType != .tradeResult || selectedTrade != nil) &&
        !isPosting
    }

    private var hasDraft: Bool {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return (!text.isEmpty && content != lastTemplateText) || !selectedUIImages.isEmpty
    }

    private var shouldShowTickerSection: Bool {
        !detectedTickers.isEmpty || selectedPostType != .text
    }

    private var shouldShowPreview: Bool {
        showPreview && (!content.isEmpty || (AppConfig.mediaUploadsEnabled && !selectedUIImages.isEmpty))
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
            if type == .tradeResult, let selectedTrade {
                selectTrade(selectedTrade)
            }
        }
        generateHashtagSuggestions()
    }

    private func updateCharacterCount() {
        characterCount = content.count
    }

    /// Tickers in the text ($aapl counts as $AAPL), in the order typed, up to Post.maxTickers.
    private func detectTickers() {
        detectedTickers = extractTickers(from: content)
    }

    private func addTicker(_ ticker: String) {
        let symbol = Cashtag.normalize(ticker)
        guard Cashtag.isValid(symbol), !detectedTickers.contains(symbol),
              detectedTickers.count < Post.maxTickers else { return }
        if !Cashtag.symbols(in: content).contains(symbol) {
            content += content.isEmpty ? "$\(symbol)" : " $\(symbol)"
        }
        detectTickers()
    }

    /// Removes every whole "$TICKER" for this symbol ("$AAPL" goes, "$AAPLX" stays).
    private func removeTicker(_ ticker: String) {
        content = Cashtag.removing(ticker, from: content)
        detectTickers()
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

    /// Saves the post and closes the sheet only once it's saved; on failure the text stays put.
    private func createPost() {
        guard canPost else { return }

        isPosting = true
        postError = nil
        focusedField = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let trade = selectedPostType == .tradeResult ? selectedTrade : nil
        var tickers = detectedTickers
        if let ticker = trade.map({ Cashtag.normalize($0.ticker) }),
           Cashtag.isValid(ticker), !tickers.contains(ticker) {
            tickers.insert(ticker, at: 0)
        }
        tickers = Array(tickers.prefix(Post.maxTickers))
        let draft = PostDraft(
            content: content,
            tickers: tickers,
            images: AppConfig.mediaUploadsEnabled ? selectedUIImages : [],
            postType: selectedPostType,
            trade: trade,
            // No tag without a ticker to apply it to
            sentiment: tickers.isEmpty ? nil : sentiment
        )

        Task {
            do {
                try await onPost(draft)
                isPosting = false
                dismiss()
            } catch {
                isPosting = false
                withAnimation(.snappy(duration: 0.25)) {
                    postError = Self.message(for: error)
                }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private static func message(for error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription, !description.isEmpty {
            return description
        }
        return "Couldn't share your post. Check your connection and try again."
    }
}

// MARK: - Supporting Views

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
    var snapshot: TradeSnapshot? = nil
    var sentiment: PostSentiment? = nil

    private var displayName: String {
        if let name = user?.fullName, !name.isEmpty { return name }
        return user?.username ?? "You"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(spacing: DS.Spacing.m) {
                UserAvatar(user: user, size: 42)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if postType != .text {
                            Tag(text: postType.displayName)
                        }
                        if let sentiment {
                            SentimentBadge(sentiment: sentiment)
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

            if let snapshot {
                TradeSummaryCard(snapshot: snapshot)
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

/// Your closed trades, newest first, each with its result and proof label.
private struct ClosedTradePickerSheet: View {
    let trades: [Trade]
    let selectedId: String?
    let onSelect: (Trade) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.s) {
                    ForEach(trades) { trade in
                        if let snapshot = TradeSnapshot(trade: trade) {
                            Button {
                                UISelectionFeedbackGenerator().selectionChanged()
                                onSelect(trade)
                                dismiss()
                            } label: {
                                TradeSummaryCard(snapshot: snapshot)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                                            .strokeBorder(trade.id == selectedId ? Color.arkadGold : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityAddTraits(trade.id == selectedId ? .isSelected : [])
                        }
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.vertical, DS.Spacing.s)
            }
            .screenBackground()
            .navigationTitle("Choose a trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    CreatePostView { _ in }
    .environmentObject(FirebaseAuthService.shared)
}
