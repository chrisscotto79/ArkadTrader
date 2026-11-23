// File: Core/Home/Views/Feeds/MarketNewsFeedView.swift
// Market news feed: a top stories carousel and the latest articles (Finnhub).

import SwiftUI

/// The Home tab's News feed. HomeView owns the view model and the surrounding
/// ScrollView, and reloads the news on pull-to-refresh.
struct MarketNewsFeedView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @State private var selectedArticle: MarketNewsArticle?

    var body: some View {
        Group {
            if homeViewModel.isLoadingNews && homeViewModel.marketNews.isEmpty {
                HomeFeedLoadingView(message: "Loading market news…")
            } else if homeViewModel.marketNews.isEmpty {
                EmptyStateView(
                    systemImage: "newspaper.fill",
                    title: "No market news",
                    message: "We couldn't load the latest headlines. Check your connection and try again.",
                    actionTitle: "Try again"
                ) {
                    Task { await homeViewModel.loadMarketNews() }
                }
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    let topStories = homeViewModel.getTopStories()
                    if !topStories.isEmpty {
                        topStoriesSection(topStories)
                    }
                    latestSection
                }
            }
        }
        .task {
            if homeViewModel.marketNews.isEmpty {
                await homeViewModel.loadMarketNews()
            }
        }
        .sheet(item: $selectedArticle) { article in
            ArticleDetailView(article: article)
        }
    }

    // MARK: - Top stories

    private func topStoriesSection(_ stories: [MarketNewsArticle]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Top stories")
                .padding(.horizontal, DS.pageMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.m) {
                    ForEach(stories, id: \.id) { article in
                        Button {
                            selectedArticle = article
                        } label: {
                            TopStoryCard(article: article)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, DS.pageMargin, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    // MARK: - Latest

    private var latestSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Latest")

            LazyVStack(spacing: DS.Spacing.s) {
                ForEach(homeViewModel.getRegularNews(), id: \.id) { article in
                    Button {
                        selectedArticle = article
                    } label: {
                        NewsArticleRow(article: article)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .padding(.horizontal, DS.pageMargin)
    }
}

// MARK: - Shared bits

/// Remote news image with a quiet placeholder while it loads or when it fails.
private struct NewsImage: View {
    let urlString: String?
    var iconSize: Font = .title2

    var body: some View {
        ZStack {
            Rectangle().fill(Color.surfaceRaised)
            if let urlString, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholderIcon
                    default:
                        ProgressView().controlSize(.small)
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private var placeholderIcon: some View {
        Image(systemName: "newspaper")
            .font(iconSize)
            .foregroundStyle(.tertiary)
    }
}

/// "Reuters · 2h ago"
private func newsByline(_ article: MarketNewsArticle) -> String {
    let source = (article.source?.isEmpty == false) ? article.source! : "Market news"
    let time = article.relativePublishedText
    return time.isEmpty ? source : "\(source) · \(time)"
}

// MARK: - Top Story Card

private struct TopStoryCard: View {
    let article: MarketNewsArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NewsImage(urlString: article.imageUrl, iconSize: .largeTitle)
                .frame(width: 280, height: 158)

            VStack(alignment: .leading, spacing: 6) {
                Text(newsByline(article))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(article.title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.m)
            .frame(width: 280, height: 112, alignment: .topLeading)
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - News Article Row

private struct NewsArticleRow: View {
    let article: MarketNewsArticle

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: 6) {
                Text(newsByline(article))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(article.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let imageUrl = article.imageUrl, !imageUrl.isEmpty {
                NewsImage(urlString: imageUrl, iconSize: .body)
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
            }
        }
        .cardStyle(padding: 14, radius: DS.Radius.m)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Article Detail View

private struct ArticleDetailView: View {
    let article: MarketNewsArticle
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    private var keywords: [String] {
        article.keywords
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    if let imageUrl = article.imageUrl, !imageUrl.isEmpty {
                        NewsImage(urlString: imageUrl, iconSize: .system(size: 40))
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        Text(article.source?.isEmpty == false ? article.source! : "Market news")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.goldText)
                        Text(article.title)
                            .font(.title2.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                        if let date = formattedDate {
                            Text(date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !keywords.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(keywords, id: \.self) { keyword in
                                    Tag(text: keyword, tint: .secondary)
                                }
                            }
                        }
                        .scrollClipDisabled()
                    }

                    if let description = article.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let url = URL(string: article.articleUrl) {
                        Button {
                            openURL(url)
                        } label: {
                            Label("Read full article", systemImage: "arrow.up.right")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, DS.Spacing.s)
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let articleURL = URL(string: article.articleUrl) {
                        ShareLink(item: articleURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share article")
                    }
                }
            }
        }
    }

    private var formattedDate: String? {
        guard let date = article.publishedDate else { return nil }
        return "\(date.formatted(date: .abbreviated, time: .shortened)) · \(article.relativePublishedText)"
    }
}

#Preview {
    ScrollView {
        MarketNewsFeedView(homeViewModel: HomeViewModel())
    }
    .screenBackground()
}
