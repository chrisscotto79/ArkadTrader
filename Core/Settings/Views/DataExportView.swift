// File: Core/Settings/Views/DataExportView.swift

import SwiftUI

struct DataExportView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedExportTypes: Set<ExportType> = []
    @State private var selectedDateRange: ExportDateRange = .all
    @State private var selectedFormat: ExportFormat = .csv
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var isExporting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // Export Overview
                exportOverviewSection
                
                // Data Types Selection
                dataTypesSection
                
                // Date Range Selection
                dateRangeSection
                
                // Export Format
                exportFormatSection
                
                // Export Actions
                exportActionsSection
                
                // Recent Exports
                recentExportsSection
            }
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
        .alert("Export Successful", isPresented: $showingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Your data has been exported successfully. Check your email for the download link.")
        }
        .alert("Export Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Export Overview Section
    private var exportOverviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Export Your Trading Data")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Download your trades, portfolio history, and other data in various formats")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                
                // Data Summary
                HStack(spacing: 20) {
                    DataSummaryCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Trades",
                        count: "-",
                        color: .green
                    )
                    
                    DataSummaryCard(
                        icon: "dollarsign.circle",
                        title: "Portfolio",
                        count: "-",
                        color: .blue
                    )
                    
                    DataSummaryCard(
                        icon: "person.2",
                        title: "Social",
                        count: "-",
                        color: .purple
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Data Types Section
    private var dataTypesSection: some View {
        Section("Select Data to Export") {
            ForEach(ExportType.allCases, id: \.self) { exportType in
                ExportTypeRow(
                    exportType: exportType,
                    isSelected: selectedExportTypes.contains(exportType)
                ) {
                    if selectedExportTypes.contains(exportType) {
                        selectedExportTypes.remove(exportType)
                    } else {
                        selectedExportTypes.insert(exportType)
                    }
                }
            }
        }
    }
    
    // MARK: - Date Range Section
    private var dateRangeSection: some View {
        Section("Date Range") {
            ForEach(ExportDateRange.allCases, id: \.self) { range in
                HStack {
                    Button(action: {
                        selectedDateRange = range
                    }) {
                        HStack {
                            Image(systemName: selectedDateRange == range ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedDateRange == range ? .blue : .gray)
                            
                            Text(range.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            if selectedDateRange == .custom {
                VStack(spacing: 12) {
                    DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $customEndDate, displayedComponents: .date)
                }
                .padding(.leading, 28)
            }
        }
    }
    
    // MARK: - Export Format Section
    private var exportFormatSection: some View {
        Section("Export Format") {
            ForEach(ExportFormat.allCases, id: \.self) { format in
                HStack {
                    Button(action: {
                        selectedFormat = format
                    }) {
                        HStack {
                            Image(systemName: selectedFormat == format ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedFormat == format ? .blue : .gray)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(format.displayName)
                                    .foregroundColor(.primary)
                                    .fontWeight(.medium)
                                
                                Text(format.description)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Export Actions Section
    private var exportActionsSection: some View {
        Section {
            VStack(spacing: 16) {
                // Export Button
                Button(action: exportData) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isExporting ? "Exporting..." : "Export Data")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedExportTypes.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedExportTypes.isEmpty || isExporting)
                
                // Export Info
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    
                    Text("Exports are delivered via email and may take a few minutes to process")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Recent Exports Section
    private var recentExportsSection: some View {
        Section("Recent Exports") {
            Text("No recent exports")
                .foregroundColor(.gray)
                .font(.body)
                .padding(.vertical, 20)
        }
    }
    
    // MARK: - Helper Methods
    
    private func exportData() {
        isExporting = true
        
        // Simulate export process
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isExporting = false
            
            // Simulate random success/failure
            if Bool.random() {
                showingSuccessAlert = true
            } else {
                errorMessage = "Export failed. Please try again later."
                showingErrorAlert = true
            }
        }
    }
}

// MARK: - Export Type Enum
enum ExportType: String, CaseIterable {
    case trades = "trades"
    case portfolio = "portfolio"
    case performance = "performance"
    case socialPosts = "social_posts"
    case communities = "communities"
    case messages = "messages"
    case settings = "settings"
    
    var displayName: String {
        switch self {
        case .trades: return "Trading History"
        case .portfolio: return "Portfolio Data"
        case .performance: return "Performance Metrics"
        case .socialPosts: return "Social Posts"
        case .communities: return "Communities"
        case .messages: return "Messages"
        case .settings: return "Account Settings"
        }
    }
    
    var description: String {
        switch self {
        case .trades: return "All your trades, orders, and positions"
        case .portfolio: return "Portfolio values, allocations, and history"
        case .performance: return "Returns, profits/losses, and analytics"
        case .socialPosts: return "Your posts, comments, and interactions"
        case .communities: return "Community memberships and activity"
        case .messages: return "Direct messages and conversations"
        case .settings: return "Account preferences and configurations"
        }
    }
    
    var icon: String {
        switch self {
        case .trades: return "chart.line.uptrend.xyaxis"
        case .portfolio: return "briefcase"
        case .performance: return "chart.bar"
        case .socialPosts: return "bubble.left.and.bubble.right"
        case .communities: return "person.3"
        case .messages: return "message"
        case .settings: return "gear"
        }
    }
    
    var color: Color {
        switch self {
        case .trades: return .green
        case .portfolio: return .blue
        case .performance: return .orange
        case .socialPosts: return .purple
        case .communities: return .pink
        case .messages: return .indigo
        case .settings: return .gray
        }
    }
}

// MARK: - Export Date Range Enum
enum ExportDateRange: String, CaseIterable {
    case lastWeek = "last_week"
    case lastMonth = "last_month"
    case lastQuarter = "last_quarter"
    case lastYear = "last_year"
    case all = "all"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .lastWeek: return "Last 7 days"
        case .lastMonth: return "Last 30 days"
        case .lastQuarter: return "Last 3 months"
        case .lastYear: return "Last year"
        case .all: return "All time"
        case .custom: return "Custom range"
        }
    }
}

// MARK: - Export Format Enum
enum ExportFormat: String, CaseIterable {
    case csv = "csv"
    case json = "json"
    case excel = "excel"
    case pdf = "pdf"
    
    var displayName: String {
        switch self {
        case .csv: return "CSV"
        case .json: return "JSON"
        case .excel: return "Excel (XLSX)"
        case .pdf: return "PDF Report"
        }
    }
    
    var description: String {
        switch self {
        case .csv: return "Comma-separated values, great for spreadsheets"
        case .json: return "Structured data format, perfect for developers"
        case .excel: return "Microsoft Excel format with formatting"
        case .pdf: return "Formatted report suitable for printing"
        }
    }
}

// MARK: - Supporting Views

struct ExportTypeRow: View {
    let exportType: ExportType
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: exportType.icon)
                    .foregroundColor(exportType.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(exportType.displayName)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(exportType.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

struct RecentExportRow: View {
    let export: RecentExport
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(export.typesDisplayName)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(export.format.displayName.uppercased())
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                    
                    Text("•")
                        .foregroundColor(.gray)
                        .font(.caption)
                    
                    Text(export.dateRange)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(export.status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(export.status.color)
                
                Text(export.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Recent Export Model
struct RecentExport {
    let id: String
    let types: [ExportType]
    let format: ExportFormat
    let dateRange: String
    let createdAt: Date
    let status: ExportStatus
    
    var typesDisplayName: String {
        if types.count == 1 {
            return types.first?.displayName ?? ""
        } else {
            return "\(types.count) data types"
        }
    }
}

enum ExportStatus {
    case pending
    case processing
    case completed
    case failed
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    DataExportView()
        .environmentObject(FirebaseAuthService.shared)
}
