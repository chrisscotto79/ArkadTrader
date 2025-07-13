//
//  BrokerConnectionView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/12/25.
//


// File: Core/Settings/Views/BrokerConnectionView.swift

import SwiftUI

struct BrokerConnectionView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var connectedBrokers: Set<String> = []
    @State private var showingAPIKeyInput = false
    @State private var selectedBroker: Broker?
    
    private let availableBrokers: [Broker] = [
        Broker(
            id: "robinhood",
            name: "Robinhood",
            description: "Commission-free stock trading",
            icon: "dollarsign.circle.fill",
            color: .green,
            isAPISupported: true,
            features: ["Stocks", "ETFs", "Options", "Crypto"]
        ),
        Broker(
            id: "webull",
            name: "Webull",
            description: "Advanced charting and analysis",
            icon: "chart.line.uptrend.xyaxis",
            color: .blue,
            isAPISupported: true,
            features: ["Stocks", "ETFs", "Options", "Crypto", "Futures"]
        ),
        Broker(
            id: "tdameritrade",
            name: "TD Ameritrade",
            description: "Professional trading platform",
            icon: "building.columns.fill",
            color: .red,
            isAPISupported: true,
            features: ["Stocks", "ETFs", "Options", "Futures", "Forex"]
        ),
        Broker(
            id: "schwab",
            name: "Charles Schwab",
            description: "Full-service investment firm",
            icon: "banknote.fill",
            color: .blue,
            isAPISupported: true,
            features: ["Stocks", "ETFs", "Options", "Mutual Funds"]
        ),
        Broker(
            id: "fidelity",
            name: "Fidelity",
            description: "Investment and retirement planning",
            icon: "shield.fill",
            color: .green,
            isAPISupported: false,
            features: ["Stocks", "ETFs", "Mutual Funds", "Retirement"]
        ),
        Broker(
            id: "etrade",
            name: "E*TRADE",
            description: "Online investing and trading",
            icon: "laptopcomputer",
            color: .purple,
            isAPISupported: true,
            features: ["Stocks", "ETFs", "Options", "Futures"]
        ),
        Broker(
            id: "alpaca",
            name: "Alpaca",
            description: "API-first commission-free trading",
            icon: "antenna.radiowaves.left.and.right",
            color: .orange,
            isAPISupported: true,
            features: ["Stocks", "ETFs", "Crypto", "API Trading"]
        ),
        Broker(
            id: "interactive",
            name: "Interactive Brokers",
            description: "Professional trading platform",
            icon: "globe",
            color: .blue,
            isAPISupported: true,
            features: ["Stocks", "Options", "Futures", "Forex", "Bonds"]
        )
    ]
    
    var body: some View {
        NavigationView {
            List {
                // Connection Status
                connectionStatusSection
                
                // Available Brokers
                availableBrokersSection
                
                // Connected Brokers
                if !connectedBrokers.isEmpty {
                    connectedBrokersSection
                }
                
                // Help & Support
                helpSection
            }
            .navigationTitle("Connect Broker")
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
        .sheet(isPresented: $showingAPIKeyInput) {
            if let broker = selectedBroker {
                APIKeyInputView(broker: broker) { success in
                    if success {
                        connectedBrokers.insert(broker.id)
                    }
                    showingAPIKeyInput = false
                }
            }
        }
        .onAppear {
            loadConnectedBrokers()
        }
    }
    
    // MARK: - Connection Status Section
    private var connectionStatusSection: some View {
        Section {
            HStack(spacing: 16) {
                Circle()
                    .fill(connectedBrokers.isEmpty ? Color.gray : Color.green)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(connectedBrokers.isEmpty ? "No Brokers Connected" : "\(connectedBrokers.count) Broker\(connectedBrokers.count == 1 ? "" : "s") Connected")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(connectedBrokers.isEmpty ? "Connect your broker to start importing trades automatically" : "Your trading data will be synced automatically")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if !connectedBrokers.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Available Brokers Section
    private var availableBrokersSection: some View {
        Section("Available Brokers") {
            ForEach(availableBrokers, id: \.id) { broker in
                BrokerRowView(
                    broker: broker,
                    isConnected: connectedBrokers.contains(broker.id)
                ) {
                    connectToBroker(broker)
                }
            }
        }
    }
    
    // MARK: - Connected Brokers Section
    private var connectedBrokersSection: some View {
        Section("Connected Brokers") {
            ForEach(availableBrokers.filter { connectedBrokers.contains($0.id) }, id: \.id) { broker in
                ConnectedBrokerRowView(broker: broker) {
                    disconnectFromBroker(broker)
                }
            }
        }
    }
    
    // MARK: - Help Section
    private var helpSection: some View {
        Section("Help & Support") {
            Button(action: {
                // TODO: Open broker setup guide
            }) {
                HStack {
                    Image(systemName: "book")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Broker Setup Guide")
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text("Learn how to connect your broker")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            
            Button(action: {
                // TODO: Open broker troubleshooting
            }) {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Troubleshooting")
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text("Fix connection issues")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            
            Button(action: {
                // TODO: Contact support
            }) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Contact Support")
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text("Get help with broker connections")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func connectToBroker(_ broker: Broker) {
        if broker.isAPISupported {
            selectedBroker = broker
            showingAPIKeyInput = true
        } else {
            // Show manual connection instructions
            // TODO: Implement manual connection flow
        }
    }
    
    private func disconnectFromBroker(_ broker: Broker) {
        connectedBrokers.remove(broker.id)
        saveConnectedBrokers()
    }
    
    private func loadConnectedBrokers() {
        // Load from UserDefaults or Core Data
        if let data = UserDefaults.standard.data(forKey: "connected_brokers"),
           let brokers = try? JSONDecoder().decode(Set<String>.self, from: data) {
            connectedBrokers = brokers
        }
    }
    
    private func saveConnectedBrokers() {
        if let data = try? JSONEncoder().encode(connectedBrokers) {
            UserDefaults.standard.set(data, forKey: "connected_brokers")
        }
    }
}

// MARK: - Broker Model
struct Broker {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: Color
    let isAPISupported: Bool
    let features: [String]
}

// MARK: - Broker Row View
struct BrokerRowView: View {
    let broker: Broker
    let isConnected: Bool
    let onConnect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: broker.icon)
                .foregroundColor(broker.color)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(broker.color.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(broker.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(broker.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Features
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(broker.features, id: \.self) { feature in
                            Text(feature)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            Spacer()
            
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            } else {
                Button("Connect") {
                    onConnect()
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(broker.color)
                .clipShape(Capsule())
                .disabled(!broker.isAPISupported)
                .opacity(broker.isAPISupported ? 1.0 : 0.6)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Connected Broker Row View
struct ConnectedBrokerRowView: View {
    let broker: Broker
    let onDisconnect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: broker.icon)
                .foregroundColor(broker.color)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(broker.color.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(broker.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            Menu {
                Button("View Settings") {
                    // TODO: View broker settings
                }
                
                Button("Sync Now") {
                    // TODO: Manually sync data
                }
                
                Divider()
                
                Button("Disconnect", role: .destructive) {
                    onDisconnect()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.gray)
                    .font(.title3)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - API Key Input View
struct APIKeyInputView: View {
    let broker: Broker
    let onComplete: (Bool) -> Void
    
    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var isConnecting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: broker.icon)
                        .foregroundColor(broker.color)
                        .font(.system(size: 48))
                        .frame(width: 80, height: 80)
                        .background(
                            Circle()
                                .fill(broker.color.opacity(0.1))
                        )
                    
                    Text("Connect to \(broker.name)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your API credentials to connect your \(broker.name) account")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                // Input fields
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextField("Enter your API key", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Secret")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        SecureField("Enter your API secret", text: $apiSecret)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                // Security notice
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "shield.fill")
                            .foregroundColor(.green)
                        
                        Text("Your credentials are encrypted and stored securely")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Text("We recommend using read-only API keys when possible")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Connect button
                Button(action: connectToBroker) {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isConnecting ? "Connecting..." : "Connect")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(broker.color)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(apiKey.isEmpty || apiSecret.isEmpty || isConnecting)
            }
            .padding()
            .navigationTitle("Connect Broker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onComplete(false)
                    }
                }
            }
        }
        .alert("Connection Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func connectToBroker() {
        isConnecting = true
        
        // Simulate API connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isConnecting = false
            
            // Simulate random success/failure for demo
            if Bool.random() {
                onComplete(true)
            } else {
                errorMessage = "Invalid API credentials. Please check your API key and secret."
                showingError = true
            }
        }
    }
}

#Preview {
    BrokerConnectionView()
        .environmentObject(FirebaseAuthService.shared)
}