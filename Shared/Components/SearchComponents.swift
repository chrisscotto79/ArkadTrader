// File: Shared/Components/SearchComponents.swift
// Enhanced search components with improved animations and design

import SwiftUI

// MARK: - Enhanced Search Bar
struct EnhancedSearchBar: View {
    @Binding var searchText: String
    var placeholder: String = "Search..."
    var onSearchChanged: ((String) -> Void)? = nil
    var onClear: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Animated Search Icon
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? .blue : .gray)
                .font(.title3)
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isAnimating = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isAnimating = false
                    }
                }
            
            // Enhanced Text Field
            TextField(placeholder, text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
                .onChange(of: searchText) { _, newValue in
                    onSearchChanged?(newValue)
                }
                .submitLabel(.search)
            
            // Animated Clear Button
            if !searchText.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                        .scaleEffect(1.0)
                }
                .transition(.scale.combined(with: .opacity))
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        clearSearch()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(isFocused ? 0.05 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? .blue : .clear, lineWidth: 2)
                        .shadow(color: isFocused ? .blue.opacity(0.3) : .clear, radius: 4)
                )
        )
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
    
    private func clearSearch() {
        searchText = ""
        onClear?()
        isFocused = false
    }
}

// MARK: - Enhanced Filter Picker Component
struct FilterPicker<T: CaseIterable & Hashable & RawRepresentable>: View where T.RawValue == String {
    @Binding var selection: T
    let title: String
    @State private var selectedIndex: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title with Icon
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
            }
            
            // Enhanced Segmented Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(T.allCases.enumerated()), id: \.element) { index, option in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selection = option
                                selectedIndex = index
                            }
                        }) {
                            Text(option.rawValue.capitalized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(selection == option ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selection == option ?
                                              LinearGradient(colors: [.blue, .blue.opacity(0.8)],
                                                           startPoint: .leading, endPoint: .trailing) :
                                              LinearGradient(colors: [Color.gray.opacity(0.2)],
                                                           startPoint: .leading, endPoint: .trailing))
                                        .shadow(color: selection == option ? .blue.opacity(0.3) : .clear, radius: 4)
                                )
                        }
                        .scaleEffect(selection == option ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selection == option)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Enhanced Empty Search State
struct EmptySearchState: View {
    let searchText: String
    let message: String
    let action: (() -> Void)?
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Animated Search Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue.opacity(0.1), .blue.opacity(0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                
                Image(systemName: searchText.isEmpty ? "magnifyingglass" : "exclamationmark.magnifyingglass")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.blue.opacity(0.7))
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            }
            .onAppear {
                isAnimating = true
            }
            
            // Enhanced Text Content
            VStack(spacing: 12) {
                Text(searchText.isEmpty ? "Start Searching" : "No Results Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(searchText.isEmpty ? message : "Try adjusting your search terms")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineLimit(3)
            }
            
            // Enhanced Action Button
            if let action = action, searchText.isEmpty {
                Button(action: action) {
                    HStack(spacing: 8) {
                        Image(systemName: "safari")
                            .font(.subheadline)
                        Text("Browse All")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [.blue, .blue.opacity(0.8)],
                                     startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(25)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .scaleEffect(1.0)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        action()
                    }
                }
            }
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Enhanced Search Result Item
struct SearchResultItem: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onTap()
            }
        }) {
            HStack(spacing: 16) {
                // Enhanced Icon Container
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [color.opacity(0.2), color.opacity(0.1)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                }
                
                // Enhanced Text Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Animated Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray.opacity(0.6))
                    .scaleEffect(isPressed ? 1.2 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .gray.opacity(isPressed ? 0.2 : 0.1), radius: isPressed ? 8 : 4, x: 0, y: 2)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.2)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Enhanced Recent Searches
struct RecentSearches: View {
    @Binding var recentSearches: [String]
    let onSearchTap: (String) -> Void
    let onClearAll: () -> Void
    @State private var showClearAnimation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enhanced Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Text("Recent Searches")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if !recentSearches.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showClearAnimation = true
                            onClearAll()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showClearAnimation = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.caption)
                            Text("Clear All")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .scaleEffect(showClearAnimation ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showClearAnimation)
                }
            }
            
            // Enhanced Search Items
            if recentSearches.isEmpty {
                HStack {
                    Image(systemName: "clock")
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("No recent searches")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(Array(recentSearches.prefix(6).enumerated()), id: \.element) { index, search in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                onSearchTap(search)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                Text(search)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.1), value: recentSearches.count)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 30) {
            EnhancedSearchBar(
                searchText: .constant("AAPL"),
                placeholder: "Search stocks..."
            )
            
            FilterPicker(
                selection: .constant(SearchType.all),
                title: "Filter Results"
            )
            
            SearchResultItem(
                title: "Apple Inc.",
                subtitle: "AAPL • Technology Stock",
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            ) {
                print("Tapped Apple")
            }
            
            EmptySearchState(
                searchText: "",
                message: "Search for stocks, traders, or communities to get started",
                action: {
                    print("Browse all tapped")
                }
            )
            
            RecentSearches(
                recentSearches: .constant(["AAPL", "Tesla", "Bitcoin", "SPY"]),
                onSearchTap: { search in
                    print("Recent search tapped: \(search)")
                },
                onClearAll: {
                    print("Clear all tapped")
                }
            )
        }
        .padding()
    }
}
