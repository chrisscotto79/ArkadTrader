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

// MARK: - Community Creation Errors
enum CommunityCreationError: Error, LocalizedError {
    case reachedMaximumCommunities
    case inappropriateContent
    case duplicateName
    case networkError
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .reachedMaximumCommunities:
            return "You've reached the maximum of 2 communities. Delete or transfer ownership of an existing community to create a new one."
        case .inappropriateContent:
            return "Community name or description contains inappropriate content. Please revise and try again."
        case .duplicateName:
            return "A community with this name already exists. Please choose a different name."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .unauthorized:
            return "You don't have permission to create communities. Please log in and try again."
        }
    }
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

// MARK: - Community Creation Constants
struct CommunityCreationConstants {
    static let nameMinLength = 3
    static let nameMaxLength = 30
    static let descriptionMinLength = 10
    static let descriptionMaxLength = 280
    static let maxCommunitiesPerUser = 2
    
    static let allowedNameCharacters = CharacterSet.alphanumerics
        .union(.whitespaces)
        .union(CharacterSet(charactersIn: "-_"))
    
    static let forbiddenWords = [
        // Add any forbidden words for community names
        "admin", "moderator", "official", "arkad", "scam", "fake"
    ]
}

// MARK: - Community Creation Validation Helper
struct CommunityCreationValidator {
    
    static func validateCommunityName(_ name: String) -> (isValid: Bool, message: String?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return (false, "Community name is required")
        }
        
        if trimmed.count < CommunityCreationConstants.nameMinLength {
            return (false, "Name must be at least \(CommunityCreationConstants.nameMinLength) characters")
        }
        
        if trimmed.count > CommunityCreationConstants.nameMaxLength {
            return (false, "Name must be less than \(CommunityCreationConstants.nameMaxLength) characters")
        }
        
        // Check for inappropriate characters
        if trimmed.rangeOfCharacter(from: CommunityCreationConstants.allowedNameCharacters.inverted) != nil {
            return (false, "Only letters, numbers, spaces, hyphens, and underscores allowed")
        }
        
        // Check for forbidden words
        let lowercaseName = trimmed.lowercased()
        for forbiddenWord in CommunityCreationConstants.forbiddenWords {
            if lowercaseName.contains(forbiddenWord) {
                return (false, "Name contains restricted words")
            }
        }
        
        return (true, nil)
    }
    
    static func validateCommunityDescription(_ description: String) -> (isValid: Bool, message: String?) {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return (false, "Community description is required")
        }
        
        if trimmed.count < CommunityCreationConstants.descriptionMinLength {
            return (false, "Description must be at least \(CommunityCreationConstants.descriptionMinLength) characters")
        }
        
        if trimmed.count > CommunityCreationConstants.descriptionMaxLength {
            return (false, "Description must be less than \(CommunityCreationConstants.descriptionMaxLength) characters")
        }
        
        return (true, nil)
    }
}

// MARK: - Community Creation Tips
struct CommunityCreationTips {
    
    static let basicInfoTips = [
        "Choose a clear, descriptive name that explains your focus",
        "Mention your experience level (beginner/intermediate/advanced)",
        "Explain what type of content members can expect",
        "Keep the tone professional and welcoming"
    ]
    
    static let categoryTips = [
        "This helps traders find communities that match their interests",
        "You can discuss other topics, but this is your main focus",
        "Category affects which traders will discover your community"
    ]
    
    static let settingsTips = [
        "Public communities grow faster but have less control",
        "Private communities allow better quality control",
        "You can change privacy settings later if needed"
    ]
    
    static let generalTips = [
        "Be active in your own community to encourage participation",
        "Set clear rules and guidelines for members",
        "Regularly share valuable content and insights",
        "Engage with members and respond to their questions"
    ]
}

// MARK: - Preview Data for Community Creation
extension CommunityCreationValidator {
    
    static let sampleValidCommunity = (
        name: "Day Traders Elite",
        description: "A community for experienced day traders to share strategies, live market analysis, and discuss short-term trading opportunities. Focus on technical analysis and risk management.",
        type: CommunityType.dayTrading,
        isPrivate: false
    )
    
    static let sampleInvalidCommunity = (
        name: "DT", // Too short
        description: "Trading", // Too short
        type: CommunityType.general,
        isPrivate: false
    )
}
