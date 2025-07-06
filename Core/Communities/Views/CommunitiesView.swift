// File: Core/Communities/Views/CommunitiesView.swift
// Simplified Communities View

import SwiftUI

struct CommunitiesView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var communities: [Community] = []
    @State private var showCreateCommunity = false
    
    var body: some View {
        NavigationView {
            VStack {
                if communities.isEmpty {
                    VStack {
                        Text("No communities yet")
                            .foregroundColor(.gray)
                        Button("Create First Community") {
                            showCreateCommunity = true
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.top, 50)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(communities) { community in
                                CommunityRow(community: community)
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Communities")
            .navigationBarItems(trailing: Button("Create") { showCreateCommunity = true })
            .sheet(isPresented: $showCreateCommunity) {
                CreateCommunityView()
            }
            .onAppear {
                loadCommunities()
            }
        }
    }
    
    private func loadCommunities() {
        Task {
            do {
                communities = try await authService.getCommunities()
            } catch {
                print("Error loading communities: \(error)")
            }
        }
    }
}

struct CommunityRow: View {
    let community: Community
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var isJoined = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(community.name)
                    .font(.headline)
                Text(community.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                Text("\(community.memberCount) members")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(isJoined ? "Joined" : "Join") {
                joinCommunity()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isJoined ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(20)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .onAppear {
            checkIfJoined()
        }
    }
    
    private func checkIfJoined() {
        if let userCommunities = authService.currentUser?.communityIds {
            isJoined = userCommunities.contains(community.id)
        }
    }
    
    private func joinCommunity() {
        guard let userId = authService.currentUser?.id else { return }
        
        Task {
            do {
                try await authService.joinCommunity(communityId: community.id, userId: userId)
                isJoined = true
            } catch {
                print("Error joining community: \(error)")
            }
        }
    }
}

struct CreateCommunityView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var type: CommunityType = .general
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Community Name", text: $name)
                
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                
                Picker("Type", selection: $type) {
                    ForEach(CommunityType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }
            .navigationTitle("Create Community")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Create") { createCommunity() }
                    .disabled(name.isEmpty || description.isEmpty)
            )
        }
    }
    
    private func createCommunity() {
        guard let userId = authService.currentUser?.id else { return }
        
        let community = Community(
            name: name,
            description: description,
            type: type,
            createdBy: userId
        )
        
        Task {
            do {
                try await authService.createCommunity(community)
                dismiss()
            } catch {
                print("Error creating community: \(error)")
            }
        }
    }
}

#Preview {
    CommunitiesView()
        .environmentObject(FirebaseAuthService.shared)
}
