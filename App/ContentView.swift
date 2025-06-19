//
//  ContentView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

// File: App/ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                TabBarView()
            } else {
                LoginView()
            }
        }
        .environmentObject(authViewModel)
    }
}

#Preview {
    ContentView()
}
