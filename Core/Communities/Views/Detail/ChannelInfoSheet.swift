// File: Core/Communities/Views/Detail/ChannelInfoSheet.swift
// Sheet showing a channel's details.

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import FirebaseStorage
import Photos
import MobileCoreServices

// MARK: - Channel Info Sheet (Simplified)
struct ChannelInfoSheet: View {
    let community: Community
    let channel: Channel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(channelColor.opacity(0.15))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: channelIcon)
                                .font(.title2)
                                .foregroundColor(channelColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("#\(channel.name)")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text(channel.type.displayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section("About") {
                    Text(channelDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Channel Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var channelColor: Color {
        switch channel.type {
        case .text, .voice: return .blue
        case .callouts: return .orange
        }
    }
    
    private var channelIcon: String {
        switch channel.type {
        case .text, .voice: return "number"
        case .callouts: return "megaphone.fill"
        }
    }
    
    private var channelDescription: String {
        let posting = channel.adminOnly
            ? "Only admins can post here; everyone can read and react."
            : "Every member can post here."
        switch channel.type {
        case .text, .voice:
            return "A text channel for conversation in \(community.name). \(posting)"
        case .callouts:
            return "A channel for structured trade callouts in \(community.name). \(posting)"
        }
    }
}
