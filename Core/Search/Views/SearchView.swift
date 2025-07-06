// File: Core/Search/Views/SearchView.swift
// Simplified Search View

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search users...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .padding()
                
                // Results
                if searchText.isEmpty {
                    VStack {
                        Text("Search for users")
                            .foregroundColor(.gray)
                        Text("Find traders to follow")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 50)
                } else {
                    Text("Search functionality coming soon")
                        .foregroundColor(.gray)
                        .padding(.top, 50)
                }
                
                Spacer()
            }
            .navigationTitle("Search")
        }
    }
}

#Preview {
    SearchView()
}
