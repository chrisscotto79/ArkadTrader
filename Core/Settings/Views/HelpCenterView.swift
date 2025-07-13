//
//  HelpCenterView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/12/25.
//


// File: Core/Settings/Views/HelpCenterView.swift

import SwiftUI

struct HelpCenterView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var selectedCategory: HelpCategory = .all
    @State private var showingArticle = false
    @State private var selectedArticle: HelpArticle?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchSection
                
                // Category filter
                categoryFilterSection
                
                // Help content
                helpContentSection
            }
            .navigationTitle("Help Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingArticle) {
            if let article = selectedArticle {
                HelpArticleDetailView(article: article)
            }
        }
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search help articles...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .background(Color.backgroundSecondary)
    }
    
    // MARK: - Category Filter Section
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(HelpCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        Text(category.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
                            )
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Help Content Section
    private var helpContentSection: some View {
        List {
            // Quick Actions
            if selectedCategory == .all {
                quickActionsSection
            }
            
            // Help Articles
            helpArticlesSection
            
            // Contact Support
            if selectedCategory == .all {
                contactSupportSection
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        Section("Quick Actions") {
            QuickActionCard(
                icon: "book.pages",
                title: "Getting Started Guide",
                description: "Learn the basics of ArkadTrader",
                color: .blue
            ) {
                // TODO: Open getting started guide
            }
            
            QuickActionCard(
                icon: "play.circle",
                title: "Video Tutorials",
                description: "Watch step-by-step tutorials",
                color: .green
            ) {
                // TODO: Open video tutorials
            }
            
            QuickActionCard(
                icon: "questionmark.circle",
                title: "FAQ",
                description: "Frequently asked questions",
                color: .purple
            ) {
                // TODO: Open FAQ
            }
        }
    }
    
    // MARK: - Help Articles Section
    private var helpArticlesSection: some View {
        Section("Help Articles") {
            ForEach(filteredArticles, id: \.id) { article in
                HelpArticleRow(article: article) {
                    selectedArticle = article
                    showingArticle = true
                }
            }
            
            if filteredArticles.isEmpty {
                Text("No articles found")
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
            }
        }
    }
    
    // MARK: - Contact Support Section
    private var contactSupportSection: some View {
        Section("Need More Help?") {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Contact Support")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Get personalized help from our support team")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button("Contact") {
                        // TODO: Open contact support
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
                
                Divider()
                
                HStack {
                    Image(systemName: "message")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Live Chat")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Chat with our support team in real-time")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button("Chat") {
                        // TODO: Open live chat
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .clipShape(Capsule())
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredArticles: [HelpArticle] {
        let categoryFiltered = selectedCategory == .all ? helpArticles : helpArticles.filter { $0.category == selectedCategory }
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var helpArticles: [HelpArticle] {
        [
            // Trading Articles
            HelpArticle(
                id: "1",
                title: "How to place your first trade",
                content: "Learn the step-by-step process of placing trades in ArkadTrader...",
                category: .trading,
                tags: ["trading", "orders", "beginner"]
            ),
            HelpArticle(
                id: "2",
                title: "Understanding order types",
                content: "Market orders, limit orders, stop-loss orders explained...",
                category: .trading,
                tags: ["orders", "market", "limit", "stop-loss"]
            ),
            HelpArticle(
                id: "3",
                title: "Setting up stop-loss and take-profit",
                content: "Protect your investments with automatic order management...",
                category: .trading,
                tags: ["risk management", "stop-loss", "take-profit"]
            ),
            
            // Account Articles
            HelpArticle(
                id: "4",
                title: "Connecting your broker account",
                content: "Step-by-step guide to securely connect your trading account...",
                category: .account,
                tags: ["broker", "connection", "security"]
            ),
            HelpArticle(
                id: "5",
                title: "Managing your profile settings",
                content: "Customize your profile and privacy settings...",
                category: .account,
                tags: ["profile", "settings", "privacy"]
            ),
            HelpArticle(
                id: "6",
                title: "Account security best practices",
                content: "Keep your trading account secure with these tips...",
                category: .account,
                tags: ["security", "password", "2fa"]
            ),
            
            // Portfolio Articles
            HelpArticle(
                id: "7",
                title: "Reading your portfolio dashboard",
                content: "Understand your portfolio performance metrics...",
                category: .portfolio,
                tags: ["portfolio", "dashboard", "performance"]
            ),
            HelpArticle(
                id: "8",
                title: "Tracking portfolio performance",
                content: "Monitor your investments and track gains/losses...",
                category: .portfolio,
                tags: ["tracking", "performance", "analytics"]
            ),
            
            // Social Articles
            HelpArticle(
                id: "9",
                title: "Sharing trades with the community",
                content: "Connect with other traders and share your strategies...",
                category: .social,
                tags: ["social", "community", "sharing"]
            ),
            HelpArticle(
                id: "10",
                title: "Following other traders",
                content: "Discover and follow successful traders...",
                category: .social,
                tags: ["following", "traders", "feed"]
            ),
            
            // Technical Articles
            HelpArticle(
                id: "11",
                title: "Troubleshooting connection issues",
                content: "Resolve common connectivity problems...",
                category: .technical,
                tags: ["troubleshooting", "connection", "errors"]
            ),
            HelpArticle(
                id: "12",
                title: "Syncing data across devices",
                content: "Keep your data synchronized across all your devices...",
                category: .technical,
                tags: ["sync", "devices", "cloud"]
            )
        ]
    }
}

// MARK: - Help Category Enum
enum HelpCategory: String, CaseIterable {
    case all = "all"
    case trading = "trading"
    case account = "account"
    case portfolio = "portfolio"
    case social = "social"
    case technical = "technical"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .trading: return "Trading"
        case .account: return "Account"
        case .portfolio: return "Portfolio"
        case .social: return "Social"
        case .technical: return "Technical"
        }
    }
}

// MARK: - Help Article Model
struct HelpArticle {
    let id: String
    let title: String
    let content: String
    let category: HelpCategory
    let tags: [String]
    let createdAt: Date = Date()
    let updatedAt: Date = Date()
}

// MARK: - Supporting Views

struct QuickActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(color.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.backgroundSecondary)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HelpArticleRow: View {
    let article: HelpArticle
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(article.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Text(article.content.prefix(100) + "...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                
                HStack {
                    Text(article.category.displayName.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.backgroundSecondary)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Help Article Detail View
struct HelpArticleDetailView: View {
    let article: HelpArticle
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Article Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(article.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text(article.category.displayName.uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                            
                            Spacer()
                            
                            Text(article.createdAt, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider()
                    
                    // Article Content
                    Text(article.content)
                        .font(.body)
                        .lineSpacing(4)
                    
                    // Tags
                    if !article.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Related Topics")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                ForEach(article.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    HelpCenterView()
        .environmentObject(FirebaseAuthService.shared)
}