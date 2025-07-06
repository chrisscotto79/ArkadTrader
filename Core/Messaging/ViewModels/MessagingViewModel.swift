// File: Core/Messaging/ViewModels/MessagingViewModel.swift
// Simplified Messaging ViewModel

import Foundation
import SwiftUI

@MainActor
class MessagingViewModel: ObservableObject {
    @Published var messageText = ""
    
    func sendMessage() {
        print("Sending message: \(messageText)")
        messageText = ""
    }
}
