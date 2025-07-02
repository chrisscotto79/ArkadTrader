//
//  CommunitiesView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/2/25.
//


// MARK: - Communities View (Replaces MessagingView)
// File: Core/Communities/Views/CommunitiesView.swift

import SwiftUI

struct CommunitiesView: View {
    @StateObject private var viewModel = CommunitiesViewModel()
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var showCreateCommunity = false
    @State private var searchText = ""
    @State private var selectedTab = 0 // 0 = My Communities, 1 = Discover
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                HStack(spacing: 0) {
                    TabButton(title: "My Communities", isSelected: selectedTab == 0) {
                        selectedTab = 0
                        Task { await viewModel.loadMyCommunities() }
                    }
                    TabButton(title: "Discover", isSelected: selectedTab == 1) {
                        selectedTab = 1
                        Task { await viewModel.loadAllCommunities() }
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding()
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search communities...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Communities List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredCommunities) { community in
                            NavigationLink(destination: CommunityDetailView(community: community)) {
                                CommunityCardView(community: community)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .refreshable {
                    if selectedTab == 0 {
                        await viewModel.loadMyCommunities()
                    } else {
                        await viewModel.loadAllCommunities()
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView("Loading communities...")
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Communities")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateCommunity = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.arkadGold)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateCommunity) {
            CreateCommunityView()
                .environmentObject(viewModel)
        }
        .onAppear {
            if selectedTab == 0 {
                Task { await viewModel.loadMyCommunities() }
            } else {
                Task { await viewModel.loadAllCommunities() }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private var filteredCommunities: [Community] {
        if searchText.isEmpty {
            return selectedTab == 0 ? viewModel.myCommunities : viewModel.allCommunities
        } else {
            let communities = selectedTab == 0 ? viewModel.myCommunities : viewModel.allCommunities
            return communities.filter { community in
                community.name.localizedCaseInsensitiveContains(searchText) ||
                community.description.localizedCaseInsensitiveContains(searchText) ||
                community.tags.joined().localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Community Card View
struct CommunityCardView: View {
    let community: Community
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var viewModel = CommunitiesViewModel()
    @State private var isJoined = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Community Image/Icon
            AsyncImage(url: URL(string: community.imageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.arkadGold.opacity(0.2))
                    .overlay(
                        Image(systemName: communityIcon)
                            .font(.title2)
                            .foregroundColor(.arkadGold)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(community.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    if community.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                
                Text(community.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                
                HStack {
                    Text("\(community.memberCount) members")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(community.type.displayName)
                        .font(.caption)
                        .foregroundColor(.arkadGold)
                }
                
                // Tags
                if !community.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(community.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.arkadGold.opacity(0.1))
                                    .foregroundColor(.arkadGold)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Join/Leave Button
            Button(action: {
                Task {
                    if isJoined {
                        await leaveCommunity()
                    } else {
                        await joinCommunity()
                    }
                }
            }) {
                Text(isJoined ? "Leave" : "Join")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isJoined ? Color.gray.opacity(0.2) : Color.arkadGold)
                    .foregroundColor(isJoined ? .primary : .arkadBlack)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            checkMembership()
        }
    }
    
    private var communityIcon: String {
        switch community.type {
        case .general: return "person.3"
        case .dayTrading: return "chart.line.uptrend.xyaxis"
        case .swingTrading: return "chart.bar"
        case .options: return "chart.pie"
        case .crypto: return "bitcoinsign.circle"
        case .stocks: return "building.columns"
        case .education: return "graduationcap"
        }
    }
    
    private func checkMembership() {
        guard let userId = authService.currentUser?.id else { return }
        isJoined = authService.currentUser?.communityIds.contains(community.id) ?? false
    }
    
    private func joinCommunity() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            try await FirestoreService.shared.joinCommunity(communityId: community.id, userId: userId)
            await MainActor.run {
                isJoined = true
            }
        } catch {
            print("Failed to join community: \(error)")
        }
    }
    
    private func leaveCommunity() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            try await FirestoreService.shared.leaveCommunity(communityId: community.id, userId: userId)
            await MainActor.run {
                isJoined = false
            }
        } catch {
            print("Failed to leave community: \(error)")
        }
    }
}

// MARK: - Create Community View
struct CreateCommunityView: View {
    @EnvironmentObject var viewModel: CommunitiesViewModel
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedType: CommunityType = .general
    @State private var isPrivate = false
    @State private var rules = ""
    @State private var tags: [String] = []
    @State private var tagInput = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Community Name", text: $name)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(CommunityType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Toggle("Private Community", isOn: $isPrivate)
                }
                
                Section("Tags") {
                    HStack {
                        TextField("Add tag", text: $tagInput)
                            .onSubmit {
                                addTag()
                            }
                        
                        Button("Add", action: addTag)
                            .disabled(tagInput.isEmpty)
                    }
                    
                    if !tags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                TagView(tag: tag) {
                                    removeTag(tag)
                                }
                            }
                        }
                    }
                }
                
                Section("Rules (Optional)") {
                    TextField("Community rules and guidelines", text: $rules, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle("Create Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createCommunity()
                    }
                    .disabled(!isFormValid || isCreating)
                }
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Community created successfully!")
            }
        }
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty && !tags.contains(tag) && tags.count < 5 {
            tags.append(tag)
            tagInput = ""
        }
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    private func createCommunity() {
        guard let userId = authService.currentUser?.id else { return }
        
        isCreating = true
        
        Task {
            do {
                var community = Community(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: selectedType,
                    createdBy: userId
                )
                
                community.isPrivate = isPrivate
                community.rules = rules.trimmingCharacters(in: .whitespacesAndNewlines)
                community.tags = tags
                
                try await FirestoreService.shared.createCommunity(community)
                
                // Join the community as creator
                try await FirestoreService.shared.joinCommunity(communityId: community.id, userId: userId)
                
                await MainActor.run {
                    viewModel.showSuccess = true
                    isCreating = false
                }
                
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = "Failed to create community: \(error.localizedDescription)"
                    viewModel.showError = true
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Communities ViewModel
// File: Core/Communities/ViewModels/CommunitiesViewModel.swift

import Foundation

@MainActor
class CommunitiesViewModel: ObservableObject {
    @Published var myCommunities: [Community] = []
    @Published var allCommunities: [Community] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var showSuccess = false
    
    private let firestoreService = FirestoreService.shared
    
    func loadMyCommunities() async {
        guard let userId = FirebaseAuthService.shared.currentUser?.id else { return }
        
        isLoading = true
        
        do {
            let allCommunities = try await firestoreService.getCommunities()
            let userCommunityIds = FirebaseAuthService.shared.currentUser?.communityIds ?? []
            
            self.myCommunities = allCommunities.filter { userCommunityIds.contains($0.id) }
        } catch {
            errorMessage = "Failed to load communities: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    func loadAllCommunities() async {
        isLoading = true
        
        do {
            let communities = try await firestoreService.getCommunities()
            self.allCommunities = communities
        } catch {
            errorMessage = "Failed to load communities: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
}

// MARK: - Community Detail View
struct CommunityDetailView: View {
    let community: Community
    @StateObject private var postsViewModel = CommunityPostsViewModel()
    @State private var selectedTab = 0 // 0 = Posts, 1 = Leaderboard, 2 = Members
    
    var body: some View {
        VStack(spacing: 0) {
            // Community Header
            VStack(spacing: 16) {
                AsyncImage(url: URL(string: community.imageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.arkadGold.opacity(0.2))
                        .overlay(
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.arkadGold)
                        )
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                
                VStack(spacing: 8) {
                    Text(community.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(community.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Text("\(community.memberCount) members • \(community.type.displayName)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.white)
            
            // Tab Selector
            HStack(spacing: 0) {
                TabButton(title: "Posts", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "Leaderboard", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                TabButton(title: "Members", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding()
            
            // Content based on selected tab
            switch selectedTab {
            case 0:
                CommunityPostsView(communityId: community.id)
            case 1:
                CommunityLeaderboardView(communityId: community.id)
            case 2:
                CommunityMembersView(communityId: community.id)
            default:
                CommunityPostsView(communityId: community.id)
            }
            
            Spacer()
        }
        .navigationTitle(community.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Helper Views
struct TagView: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.arkadGold.opacity(0.2))
        .foregroundColor(.arkadGold)
        .cornerRadius(8)
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        return CGSize(width: proposal.width ?? 0, height: rows.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        
        for (rowIndex, row) in rows.rows.enumerated() {
            let rowY = bounds.minY + CGFloat(rowIndex) * (rows.rowHeight + spacing)
            
            for (itemIndex, item) in row.enumerated() {
                let itemX = bounds.minX + row.prefix(itemIndex).reduce(0) { $0 + $1.size.width + spacing }
                
                item.subview.place(
                    at: CGPoint(x: itemX, y: rowY),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (rows: [[Item]], height: CGFloat, rowHeight: CGFloat) {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[Item]] = []
        var currentRow: [Item] = []
        var currentRowWidth: CGFloat = 0
        let rowHeight: CGFloat = 30
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let item = Item(subview: subview, size: size)
            
            if currentRowWidth + size.width + spacing <= maxWidth || currentRow.isEmpty {
                currentRow.append(item)
                currentRowWidth += size.width + (currentRow.count > 1 ? spacing : 0)
            } else {
                rows.append(currentRow)
                currentRow = [item]
                currentRowWidth = size.width
            }
        }
        
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        let totalHeight = CGFloat(rows.count) * rowHeight + CGFloat(max(0, rows.count - 1)) * spacing
        
        return (rows, totalHeight, rowHeight)
    }
    
    private struct Item {
        let subview: LayoutSubview
        let size: CGSize
    }
}

// MARK: - Placeholder Views for Community Detail Tabs
struct CommunityPostsView: View {
    let communityId: String
    
    var body: some View {
        ScrollView {
            Text("Community posts will appear here")
                .foregroundColor(.gray)
                .padding()
        }
    }
}

struct CommunityLeaderboardView: View {
    let communityId: String
    
    var body: some View {
        ScrollView {
            Text("Community leaderboard will appear here")
                .foregroundColor(.gray)
                .padding()
        }
    }
}

struct CommunityMembersView: View {
    let communityId: String
    
    var body: some View {
        ScrollView {
            Text("Community members will appear here")
                .foregroundColor(.gray)
                .padding()
        }
    }
}

@MainActor
class CommunityPostsViewModel: ObservableObject {
    @Published var posts: [FirebasePost] = []
    @Published var isLoading = false
}

#Preview {
    CommunitiesView()
        .environmentObject(FirebaseAuthService.shared)
}