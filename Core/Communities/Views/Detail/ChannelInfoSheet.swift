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
        case .text: return .blue
        case .callouts: return .orange
        case .voice: return .green
        }
    }
    
    private var channelIcon: String {
        switch channel.type {
        case .text: return "number"
        case .callouts: return "megaphone.fill"
        case .voice: return "speaker.wave.2.fill"
        }
    }
    
    private var channelDescription: String {
        switch channel.type {
        case .text:
            return "A text channel for general discussions and conversations between community members."
        case .callouts:
            return "An admin-only channel for posting trading callouts, market signals, and important announcements."
        case .voice:
            return "A voice channel for real-time audio conversations and live discussions."
        }
    }
}
