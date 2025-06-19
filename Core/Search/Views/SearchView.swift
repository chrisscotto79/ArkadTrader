// File: Core/Search/Views/SearchView.swift
// Minimal version to get compilation working

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Search", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Text("Search functionality coming soon...")
                    .foregroundColor(.gray)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Search")
        }
    }
}

#Preview {
    SearchView()
}
