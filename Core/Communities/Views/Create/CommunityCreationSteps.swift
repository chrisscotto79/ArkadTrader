// File: Core/Communities/Views/Create/CommunityCreationSteps.swift
// Supporting Types and Extensions for Community Creation - NO VIEWMODEL

import Foundation
import SwiftUI

// MARK: - Community Guidelines
struct CommunityGuideline {
    let title: String
    let description: String
    let icon: String
}

// MARK: - Form Validation Extensions
extension String {
    var isValidCommunityName: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 3 && trimmed.count <= 30 && !trimmed.isEmpty
    }
    
    var isValidCommunityDescription: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 10 && trimmed.count <= 280 && !trimmed.isEmpty
    }
    
    var communityNameValidationMessage: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "Community name is required"
        }
        
        if trimmed.count < 3 {
            return "Name must be at least 3 characters"
        }
        
        if trimmed.count > 30 {
            return "Name must be less than 30 characters"
        }
        
        // Check for inappropriate characters
        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
        if trimmed.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return "Only letters, numbers, spaces, hyphens, and underscores allowed"
        }
        
        return nil
    }
    
    var communityDescriptionValidationMessage: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "Description is required"
        }
        
        if trimmed.count < 10 {
            return "Description must be at least 10 characters"
        }
        
        if trimmed.count > 280 {
            return "Description must be less than 280 characters"
        }
        
        return nil
    }
}

// MARK: - Community Creation Guidelines Extension
extension CommunityFirebaseService {
    
    /// Get community creation guidelines
    func getCommunityGuidelines() -> [CommunityGuideline] {
        return [
            CommunityGuideline(
                title: "Be Respectful",
                description: "Treat all members with respect and maintain a professional trading environment.",
                icon: "hand.raised.fill"
            ),
            CommunityGuideline(
                title: "No Financial Advice",
                description: "Share analysis and ideas, but avoid giving direct financial advice.",
                icon: "exclamationmark.triangle.fill"
            ),
            CommunityGuideline(
                title: "Stay On Topic",
                description: "Keep discussions relevant to your community's trading focus.",
                icon: "target"
            ),
            CommunityGuideline(
                title: "No Spam or Promotion",
                description: "Avoid excessive self-promotion or spam content.",
                icon: "hand.point.left.fill"
            ),
            CommunityGuideline(
                title: "Choose a Clear Name",
                description: "Pick a name that clearly describes your community's focus",
                icon: "text.cursor"
            ),
            CommunityGuideline(
                title: "Write a Good Description",
                description: "Explain what your community is about and what members can expect",
                icon: "doc.text"
            ),
            CommunityGuideline(
                title: "Select the Right Category",
                description: "Choose a category that best fits your trading focus",
                icon: "tag"
            ),
            CommunityGuideline(
                title: "Set Privacy Level",
                description: "Decide if your community should be public or private",
                icon: "lock"
            )
        ]
    }
}

// MARK: - Community Type Helpers
extension CommunityType {
    var categoryDescription: String {
        switch self {
        case .dayTrading:
            return "Short-term trades, quick profits, intraday strategies"
        case .swingTrading:
            return "Medium-term position trading, swing strategies"
        case .options:
            return "Options strategies, spreads, and analysis"
        case .crypto:
            return "Digital asset trading, blockchain analysis"
        case .stocks:
            return "Equity market investing, fundamental analysis"
        case .general:
            return "All trading topics welcome, mixed strategies"
        }
    }
    
    var categoryIcon: String {
        switch self {
        case .dayTrading: return "chart.line.uptrend.xyaxis"
        case .swingTrading: return "waveform.path"
        case .options: return "arrow.up.arrow.down.circle"
        case .crypto: return "bitcoinsign.circle"
        case .stocks: return "building.columns"
        case .general: return "person.3.fill"
        }
    }
    
    var categoryColor: Color {
        switch self {
        case .dayTrading: return .red
        case .swingTrading: return .orange
        case .options: return .purple
        case .crypto: return .yellow
        case .stocks: return .green
        case .general: return .blue
        }
    }
}
