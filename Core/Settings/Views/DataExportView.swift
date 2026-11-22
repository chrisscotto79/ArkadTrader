// File: Core/Settings/Views/DataExportView.swift
// Export Data: loads the signed-in user's trades and posts, writes them to CSV files
// on the device, and hands them to the share sheet so the user can save or send them.

import SwiftUI
import FirebaseFirestore

struct DataExportView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss

    @State private var trades: [Trade] = []
    @State private var posts: [Post] = []
    @State private var tradesFile: URL?
    @State private var postsFile: URL?
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var tradesError: String?
    @State private var postsError: String?

    var body: some View {
        NavigationView {
            List {
                overviewSection
                if !hasLoaded {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Loading your data...")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    filesSection
                }
            }
            .listStyle(InsetGroupedListStyle())
            .refreshable { await loadData() }
            .navigationTitle("Export Data")
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
        .task {
            if !hasLoaded { await loadData() }
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.arkadGold)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Export Your Data")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("Create CSV files of your trades and posts. They open in Numbers, Excel or Google Sheets.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                HStack(spacing: 12) {
                    DataSummaryCard(icon: "chart.line.uptrend.xyaxis", title: "Trades", count: countText(trades.count, error: tradesError), color: .marketGreen)
                    DataSummaryCard(icon: "lock.open", title: "Open", count: countText(trades.filter { $0.isOpen }.count, error: tradesError), color: .arkadGoldDark)
                    DataSummaryCard(icon: "bubble.left.and.bubble.right", title: "Posts", count: countText(posts.count, error: postsError), color: .blue)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Files

    private var filesSection: some View {
        Section {
            exportRow(
                title: "Trades CSV",
                icon: "chart.line.uptrend.xyaxis",
                file: tradesFile,
                error: tradesError,
                summary: trades.isEmpty
                    ? "You haven't logged any trades yet."
                    : "\(trades.count) trade\(trades.count == 1 ? "" : "s"), open and closed"
            )
            exportRow(
                title: "Posts CSV",
                icon: "bubble.left.and.bubble.right",
                file: postsFile,
                error: postsError,
                summary: posts.isEmpty
                    ? "You haven't posted yet."
                    : "\(posts.count) post\(posts.count == 1 ? "" : "s")"
            )
        } header: {
            Text("Files")
        } footer: {
            Text("Files are created on this device and shared with the app you choose, such as Files, Mail or AirDrop. Nothing is sent anywhere until you share it.")
        }
    }

    /// A share row when a file is ready, otherwise a greyed-out row explaining why not.
    @ViewBuilder
    private func exportRow(title: String, icon: String, file: URL?, error: String?, summary: String) -> some View {
        if let file, error == nil {
            ShareLink(item: file) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundColor(.arkadGold)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .fontWeight(.medium)
                            .foregroundColor(.textPrimary)
                        Text(summary)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.arkadGoldDark)
                }
                .padding(.vertical, 4)
            }
        } else {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    Text(error ?? summary)
                        .font(.caption)
                        .foregroundColor(error == nil ? .gray : .marketRed)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private func countText(_ count: Int, error: String?) -> String {
        if !hasLoaded { return "–" }
        return error == nil ? "\(count)" : "!"
    }

    // MARK: - Loading

    private func loadData() async {
        guard let userId = authService.currentUser?.id, !userId.isEmpty else {
            tradesError = "Sign in to export your data."
            postsError = "Sign in to export your data."
            hasLoaded = true
            return
        }

        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // Trades
        do {
            let loaded = try await authService.getUserTrades(userId: userId)
            trades = loaded
            tradesError = nil
            tradesFile = try loaded.isEmpty ? nil : CSVExport.write(CSVExport.tradesCSV(loaded), named: "ArkadTrader-Trades")
        } catch {
            tradesError = "Couldn't load your trades. Pull down to try again."
            tradesFile = nil
        }

        // Posts (queried without ordering so no composite index is needed; sorted here)
        do {
            let snapshot = try await FirebaseServices.shared.db.collection("posts")
                .whereField("authorId", isEqualTo: userId)
                .getDocuments()
            let loaded = snapshot.documents
                .compactMap { try? Post.fromFirestore(data: $0.data(), id: $0.documentID) }
                .sorted { $0.createdAt > $1.createdAt }
            posts = loaded
            postsError = nil
            postsFile = try loaded.isEmpty ? nil : CSVExport.write(CSVExport.postsCSV(loaded), named: "ArkadTrader-Posts")
        } catch {
            postsError = "Couldn't load your posts. Pull down to try again."
            postsFile = nil
        }

        hasLoaded = true
    }
}

// MARK: - CSV Export

enum CSVExport {
    static func tradesCSV(_ trades: [Trade]) -> String {
        let header = [
            "Trade ID", "Ticker", "Asset Type", "Status", "Quantity",
            "Entry Price", "Entry Date", "Exit Price", "Exit Date",
            "Realized P&L", "Realized P&L %", "Stop Loss", "Take Profit",
            "Strategy", "Notes", "Tags"
        ]
        let rows = trades.map { trade -> [String] in
            [
                trade.id,
                text(trade.ticker),
                trade.tradeType.displayName,
                trade.isOpen ? "Open" : "Closed",
                "\(trade.quantity)",
                number(trade.entryPrice),
                date(trade.entryDate),
                trade.exitPrice.map(number) ?? "",
                trade.exitDate.map(date) ?? "",
                trade.isOpen ? "" : number(trade.profitLoss),
                (trade.isOpen || trade.entryPrice == 0) ? "" : number(trade.profitLossPercentage),
                trade.stopLossPrice.map(number) ?? "",
                trade.takeProfitPrice.map(number) ?? "",
                text(trade.strategy ?? ""),
                text(trade.notes ?? ""),
                text(trade.tags.joined(separator: " "))
            ]
        }
        return csv(header: header, rows: rows)
    }

    static func postsCSV(_ posts: [Post]) -> String {
        let header = [
            "Post ID", "Created", "Type", "Content", "Tickers", "Hashtags",
            "Likes", "Comments", "Image Count", "Image URLs"
        ]
        let rows = posts.map { post -> [String] in
            [
                post.id,
                date(post.createdAt),
                post.postType.rawValue,
                text(post.content),
                text(post.tickers.joined(separator: " ")),
                text(post.hashtags.joined(separator: " ")),
                "\(post.likesCount)",
                "\(post.commentsCount)",
                "\(post.imageUrls.count)",
                text(post.imageUrls.joined(separator: " "))
            ]
        }
        return csv(header: header, rows: rows)
    }

    /// Writes the CSV to a dated file in the temporary directory and returns its URL.
    static func write(_ contents: String, named baseName: String) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName)-\(formatter.string(from: Date()))")
            .appendingPathExtension("csv")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: Helpers

    private static func csv(header: [String], rows: [[String]]) -> String {
        ([header] + rows)
            .map { $0.map(escape).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
    }

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    /// Free text: stops spreadsheet apps from treating it as a formula.
    private static func text(_ value: String) -> String {
        guard let first = value.first, "=+-@".contains(first) else { return value }
        return "'" + value
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter
    }()

    private static func number(_ value: Double) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func date(_ value: Date) -> String {
        dateFormatter.string(from: value)
    }
}

// MARK: - Supporting Views

struct DataSummaryCard: View {
    let icon: String
    let title: String
    let count: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)

            Text(count)
                .font(.headline)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

#Preview {
    DataExportView()
        .environmentObject(FirebaseAuthService.shared)
}
