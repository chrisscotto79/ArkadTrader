// File: Shared/Components/SearchComponents.swift
// Fixed search components - removes deprecation warnings

import SwiftUI

// MARK: - Enhanced Search Bar
struct EnhancedSearchBar: View {
    @Binding var searchText: String
    var placeholder: String = "Search..."
    var onSearchChanged: ((String) -> Void)? = nil
    var onClear: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? .blue : .gray)
                .font(.title3)
            
            TextField(placeholder, text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
                .onChange(of: searchText) { _, newValue in
                    onSearchChanged?(newValue)
                }
            
            if !searchText.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? .blue : .clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
    
    private func clearSearch() {
        searchText = ""
        onClear?()
        isFocused = false
    }
}

// MARK: - Filter Picker Component
struct FilterPicker<T: CaseIterable & Hashable & RawRepresentable>: View where T.RawValue == String {
    @Binding var selection: T
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            Picker(title, selection: $selection) {
                ForEach(Array(T.allCases), id: \.self) { option in
                    Text(option.rawValue.capitalized).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
}

// MARK: - Empty Search State
struct EmptySearchState: View {
    let searchText: String
    let message: String
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "Start Searching" : "No Results Found")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                
                Text(searchText.isEmpty ?
                     message :
                     "Try adjusting your search terms")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            if let action = action, searchText.isEmpty {
                Button("Browse All") {
                    action()
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Search Result Card
struct SearchResultCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Searches
struct RecentSearches: View {
    @Binding var recentSearches: [String]
    let onSearchTap: (String) -> Void
    let onClearAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Searches")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if !recentSearches.isEmpty {
                    Button("Clear All") {
                        onClearAll()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if recentSearches.isEmpty {
                Text("No recent searches")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(recentSearches.prefix(6), id: \.self) { search in
                        Button(action: { onSearchTap(search) }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text(search)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(16)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        EnhancedSearchBar(searchText: .constant("AAPL"))
        
        SearchResultCard(
            title: "Apple Inc.",
            subtitle: "AAPL • Technology",
            icon: "chart.line.uptrend.xyaxis",
            color: .blue
        ) {}
        
        EmptySearchState(
            searchText: "",
            message: "Search for stocks, traders, or communities",
            action: {}
        )
        
        RecentSearches(
            recentSearches: .constant(["AAPL", "TSLA", "MSFT"]),
            onSearchTap: { _ in },
            onClearAll: {}
        )
    }
    .padding()
}
