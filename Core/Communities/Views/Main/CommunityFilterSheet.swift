// File: Core/Communities/Views/Main/CommunityFilterSheet.swift
// Sort and filter sheet for community discovery.

import SwiftUI

// MARK: - Filter Sheet
struct CommunityFilterSheet: View {
    @ObservedObject var viewModel: CommunitiesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempSelectedCategory: CommunityType?
    @State private var tempSortType: CommunitySortType = .memberCount
    @State private var tempMinMembers: Double = 0
    
    var body: some View {
        NavigationView {
            Form {
                // Category Filter Section
                Section("Community Type") {
                    Picker("Category", selection: $tempSelectedCategory) {
                        Text("All Types").tag(CommunityType?.none)
                        ForEach(CommunityType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: getTypeIcon(for: type))
                                Text(type.displayName)
                            }
                            .tag(type as CommunityType?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Member Count Filter Section
                Section("Minimum Members") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(tempMinMembers > 0 ? "At least \(Int(tempMinMembers)) members" : "Any size")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        Slider(value: $tempMinMembers, in: 0...500, step: 5) {
                            Text("Member Count")
                        }
                        .accentColor(.arkadGold)
                    }
                }
                
                // Sort Options Section
                Section("Sort By") {
                    Picker("Sort", selection: $tempSortType) {
                        ForEach(CommunitySortType.allCases, id: \.self) { sortType in
                            HStack {
                                Image(systemName: getSortIcon(for: sortType))
                                Text(sortType.displayName)
                            }
                            .tag(sortType)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Reset Section
                Section {
                    Button("Reset All Filters") {
                        resetFilters()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Filter Communities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadCurrentFilters()
        }
    }
    
    private func loadCurrentFilters() {
        tempSelectedCategory = viewModel.selectedCategory
        tempSortType = viewModel.sortType
        tempMinMembers = Double(viewModel.minimumMemberCount)
    }
    
    private func applyFilters() {
        viewModel.selectedCategory = tempSelectedCategory
        viewModel.sortType = tempSortType
        viewModel.minimumMemberCount = Int(tempMinMembers)
        
        Task {
            await viewModel.loadDiscoveryCommunities()
        }
    }
    
    private func resetFilters() {
        tempSelectedCategory = nil
        tempSortType = .memberCount
        tempMinMembers = 0
    }
    
    private func getTypeIcon(for type: CommunityType) -> String {
        switch type {
        case .general: return "person.3"
        case .dayTrading: return "chart.line.uptrend.xyaxis"
        case .swingTrading: return "chart.bar"
        case .options: return "option"
        case .crypto: return "bitcoinsign.circle"
        case .stocks: return "building.columns"
        }
    }
    
    private func getSortIcon(for sortType: CommunitySortType) -> String {
        switch sortType {
        case .memberCount: return "person.3"
        case .newest: return "clock"
        case .alphabetical: return "textformat.abc"
        case .mostActive:
                return "arrow.triangle.2.circlepath"
        }
    }
}
