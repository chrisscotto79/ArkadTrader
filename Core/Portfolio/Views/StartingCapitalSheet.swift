//
//  StartingCapitalSheet.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/12/25.
//


// File: Core/Portfolio/Views/StartingCapitalSheet.swift
// Starting Capital Setup Sheet

import SwiftUI

struct StartingCapitalSheet: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    @State private var startingCapitalInput = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.arkadGold)
                    
                    Text("Set Starting Capital")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("To accurately track your portfolio performance, please enter your starting capital amount.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Amount Input Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Starting Capital Amount")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    TextField("Enter amount", text: $startingCapitalInput)
                        .keyboardType(.numberPad)
                        .font(.title2)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            HStack {
                                Text("$")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 16)
                                Spacer()
                            }
                        )
                }
                .padding(.horizontal)
                
                // Quick Amount Buttons
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Select")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        quickAmountButton("$1,000", amount: 1000)
                        quickAmountButton("$5,000", amount: 5000)
                        quickAmountButton("$10,000", amount: 10000)
                        quickAmountButton("$25,000", amount: 25000)
                        quickAmountButton("$50,000", amount: 50000)
                        quickAmountButton("$100,000", amount: 100000)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Set Capital Button
                Button(action: setStartingCapital) {
                    Text("Set Starting Capital")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidAmount ? Color.arkadGold : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!isValidAmount)
                .padding(.horizontal)
                
                // Skip Button (for existing users who don't want to set it now)
                Button(action: { dismiss() }) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.bottom)
            }
            .padding(.vertical)
            .navigationTitle("Starting Capital")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("×") { dismiss() }
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
        }
        .alert("Starting Capital Set", isPresented: $showAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func quickAmountButton(_ title: String, amount: Double) -> some View {
        Button(action: {
            startingCapitalInput = String(format: "%.0f", amount)
        }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.arkadGold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.arkadGold.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    private var isValidAmount: Bool {
        guard let amount = Double(startingCapitalInput.replacingOccurrences(of: ",", with: "")) else { return false }
        return amount > 0
    }
    
    private func setStartingCapital() {
        guard let amount = Double(startingCapitalInput.replacingOccurrences(of: ",", with: "")) else { return }
        
        portfolioViewModel.setUserStartingCapital(amount)
        portfolioViewModel.showStartingCapitalPrompt = false
        
        alertMessage = "Starting capital set to \(amount.asCurrency). Your portfolio calculations will now be accurate!"
        showAlert = true
    }
}