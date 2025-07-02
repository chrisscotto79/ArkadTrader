// MARK: - Updated AuthViewModel for Firebase
// File: Core/Authentication/ViewModels/AuthViewModel.swift

import Foundation

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var username = ""
    @Published var fullName = ""
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let authService = FirebaseAuthService.shared
    
    var isAuthenticated: Bool {
        authService.isAuthenticated
    }
    
    var currentUser: AppUser? {
        authService.currentUser
    }
    
    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            showErrorMessage("Please fill in all fields")
            return
        }
        
        isLoading = true
        
        do {
            try await authService.login(email: email, password: password)
            clearFields()
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func register() async {
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty, !fullName.isEmpty else {
            showErrorMessage("Please fill in all fields")
            return
        }
        
        isLoading = true
        
        do {
            try await authService.register(email: email, password: password, username: username, fullName: fullName)
            clearFields()
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func updateProfile(fullName: String?, bio: String?) async throws {
        try await authService.updateProfile(fullName: fullName, bio: bio)
    }
    
    func logout() {
        Task {
            await authService.logout()
            clearFields()
        }
    }
    
    private func clearFields() {
        email = ""
        password = ""
        username = ""
        fullName = ""
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Updated PortfolioViewModel for Firebase
// File: Core/Portfolio/ViewModels/PortfolioViewModel.swift

import Foundation
import SwiftUI

@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var trades: [FirebaseTrade] = []
    @Published var portfolio: Portfolio?
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let firestoreService = FirestoreService.shared
    private let authService = FirebaseAuthService.shared
    
    init() {
        setupTradesListener()
    }
    
    deinit {
        firestoreService.removeAllListeners()
    }
    
    func loadPortfolioData() {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                let trades = try await firestoreService.getUserTrades(userId: userId)
                await MainActor.run {
                    self.trades = trades
                    self.calculatePortfolioMetrics()
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load portfolio: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func setupTradesListener() {
        guard let userId = authService.currentUser?.id else { return }
        
        firestoreService.listenToUserTrades(userId: userId) { [weak self] trades in
            Task { @MainActor in
                self?.trades = trades
                self?.calculatePortfolioMetrics()
            }
        }
    }
    
    func addTrade(_ trade: FirebaseTrade) {
        Task {
            do {
                try await firestoreService.addTrade(trade)
                // The listener will automatically update the trades array
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to add trade: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func addTradeSimple(ticker: String, tradeType: TradeType, entryPrice: Double, quantity: Int, notes: String? = nil) {
        guard let userId = authService.currentUser?.id else {
            self.errorMessage = "User not authenticated"
            self.showError = true
            return
        }
        
        guard !ticker.isEmpty, entryPrice > 0, quantity > 0 else {
            self.errorMessage = "Please check your input values"
            self.showError = true
            return
        }
        
        var newTrade = FirebaseTrade(ticker: ticker.uppercased(), tradeType: tradeType, entryPrice: entryPrice, quantity: quantity, userId: userId)
        newTrade.notes = notes
        
        addTrade(newTrade)
    }
    
    func closeTrade(_ trade: FirebaseTrade, exitPrice: Double) {
        var updatedTrade = trade
        updatedTrade.exitPrice = exitPrice
        updatedTrade.exitDate = Date()
        updatedTrade.isOpen = false
        
        Task {
            do {
                try await firestoreService.updateTrade(updatedTrade)
                // The listener will automatically update the trades array
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to close trade: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func deleteTrade(_ trade: FirebaseTrade) {
        Task {
            do {
                try await firestoreService.deleteTrade(tradeId: trade.id)
                // The listener will automatically update the trades array
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to delete trade: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    private func calculatePortfolioMetrics() {
        guard let userId = authService.currentUser?.id else { return }
        
        let totalValue = trades.reduce(0) { $0 + $1.currentValue }
        let totalPL = trades.filter { !$0.isOpen }.reduce(0) { $0 + $1.profitLoss }
        let openPositions = trades.filter { $0.isOpen }.count
        let totalTrades = trades.count
        let closedTrades = trades.filter { !$0.isOpen }
        let winningTrades = closedTrades.filter { $0.profitLoss > 0 }.count
        let winRate = closedTrades.count > 0 ? Double(winningTrades) / Double(closedTrades.count) * 100 : 0
        
        var newPortfolio = Portfolio(userId: userId)
        newPortfolio.totalValue = totalValue
        newPortfolio.totalProfitLoss = totalPL
        newPortfolio.openPositions = openPositions
        newPortfolio.totalTrades = totalTrades
        newPortfolio.winRate = winRate
        newPortfolio.dayProfitLoss = calculateDayProfitLoss()
        
        self.portfolio = newPortfolio
    }
    
    private func calculateDayProfitLoss() -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        let todaysTrades = trades.filter { trade in
            if let exitDate = trade.exitDate {
                return Calendar.current.isDate(exitDate, inSameDayAs: today)
            }
            return false
        }
        return todaysTrades.reduce(0) { $0 + $1.profitLoss }
    }
    
    func refreshData() {
        loadPortfolioData()
    }
    
    func getBestPerformingTrade() -> FirebaseTrade? {
        return trades.filter { !$0.isOpen }.max(by: { $0.profitLoss < $1.profitLoss })
    }
    
    func getTotalInvestedAmount() -> Double {
        return trades.reduce(0) { total, trade in
            total + (trade.entryPrice * Double(trade.quantity))
        }
    }
}

// MARK: - Fixed MarketNewsFeedView (Remove API Key)
// File: Core/Home/Views/MarketNewsFeedView.swift

import SwiftUI

struct MarketNewsFeedView: View {
    @StateObject private var viewModel = MarketNewsViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading market news...")
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 50)
                } else if viewModel.newsItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("News Coming Soon")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        
                        Text("Market news will be available once the backend service is configured")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 80)
                } else {
                    ForEach(viewModel.newsItems) { item in
                        NewsCard(news: item)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .refreshable {
            await viewModel.fetchNews()
        }
        .onAppear {
            Task {
                await viewModel.fetchNews()
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

// MARK: - Market News ViewModel (Safe Implementation)
@MainActor
class MarketNewsViewModel: ObservableObject {
    @Published var newsItems: [NewsItem] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    func fetchNews() async {
        // TODO: Implement Firebase Cloud Function for secure API calls
        // For now, show placeholder content to avoid exposing API keys
        
        isLoading = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // TODO: Replace with actual Firebase Cloud Function call
        // Example: let news = try await CloudFunctionService.shared.getMarketNews()
        
        await MainActor.run {
            // Placeholder news items until backend is implemented
            self.newsItems = createPlaceholderNews()
            self.isLoading = false
        }
    }
    
    private func createPlaceholderNews() -> [NewsItem] {
        return [
            NewsItem(
                id: "1",
                headline: "Market Update: Major Indices Show Mixed Results",
                summary: "S&P 500 and Dow Jones post modest gains while tech stocks face pressure",
                source: "Market News",
                createdAt: Date().addingTimeInterval(-3600),
                url: nil,
                symbols: ["SPY", "QQQ", "DIA"]
            ),
            NewsItem(
                id: "2",
                headline: "Tech Earnings Season Kicks Off Next Week",
                summary: "Major technology companies prepare to report quarterly results",
                source: "Tech News",
                createdAt: Date().addingTimeInterval(-7200),
                url: nil,
                symbols: ["AAPL", "MSFT", "GOOGL"]
            ),
            NewsItem(
                id: "3",
                headline: "Federal Reserve Minutes Released",
                summary: "Central bank officials discuss future monetary policy direction",
                source: "Economic News",
                createdAt: Date().addingTimeInterval(-10800),
                url: nil,
                symbols: ["TLT", "USD", "GLD"]
            )
        ]
    }
}

// MARK: - Simplified News Models
struct NewsItem: Identifiable, Codable {
    let id: String
    let headline: String
    let summary: String?
    let source: String
    let createdAt: Date
    let url: String?
    let symbols: [String]
}

struct NewsCard: View {
    let news: NewsItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(news.source)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                    
                    Text(formatDate(news.createdAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("📈")
                    .font(.title2)
            }
            
            Text(news.headline)
                .font(.headline)
                .fontWeight(.semibold)
            
            if let summary = news.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(3)
            }
            
            if !news.symbols.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(news.symbols.prefix(6), id: \.self) { symbol in
                            Text(symbol)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.arkadGold.opacity(0.15))
                                .foregroundColor(.arkadGold)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Updated TabBarView (Replace Messaging with Communities)
// File: Shared/Components/TabBarView.swift

import SwiftUI

struct TabBarView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            // Search Tab
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .tag(1)
            
            // Portfolio Tab
            PortfolioView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Portfolio")
                }
                .tag(2)
            
            // Communities Tab (Replaces Messaging)
            CommunitiesView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Communities")
                }
                .tag(3)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(4)
        }
        .accentColor(.arkadGold)
    }
}

// MARK: - Updated ContentView for Firebase
// File: App/ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = FirebaseAuthService.shared
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                TabBarView()
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
        .environmentObject(authService)
    }
}

// MARK: - Updated LoginView for Firebase
// File: Core/Authentication/Views/LoginView.swift

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showForgotPassword = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                // Logo - Text-Based (Professional)
                VStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Text("ARKAD")
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundColor(.arkadGold)
                        Text("TRADER")
                            .font(.largeTitle)
                            .fontWeight(.thin)
                            .foregroundColor(.arkadBlack)
                    }
                    
                    Rectangle()
                        .fill(Color.arkadGold)
                        .frame(width: 120, height: 2)
                }
                .padding(.bottom, 20)
                
                Text("Social Trading Platform")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Login Form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Login") {
                        Task {
                            await login()
                        }
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadBlack)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.arkadGold)
                    .cornerRadius(12)
                    .disabled(authService.isLoading)
                    
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    Button("Forgot Password?") {
                        showForgotPassword = true
                    }
                    .font(.caption)
                    .foregroundColor(.arkadGold)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Register Link
                Button("Don't have an account? Sign Up") {
                    showRegister = true
                }
                .foregroundColor(.arkadGold)
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showRegister) {
                RegisterView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            showError = true
            return
        }
        
        do {
            try await authService.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Updated RegisterView for Firebase
// File: Core/Authentication/Views/RegisterView.swift

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var fullName = ""
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    TextField("Full Name", text: $fullName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Create Account") {
                        Task {
                            await register()
                        }
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadBlack)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.arkadGold)
                    .cornerRadius(12)
                    .disabled(authService.isLoading)
                    
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func register() async {
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty, !fullName.isEmpty else {
            errorMessage = "Please fill in all fields"
            showError = true
            return
        }
        
        do {
            try await authService.register(email: email, password: password, username: username, fullName: fullName)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    ContentView()
}
