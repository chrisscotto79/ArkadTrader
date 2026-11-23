// File: Shared/Extensions/Date+Extensions.swift

import Foundation

extension Date {
    /// Returns a user-friendly relative time string (e.g., "2h ago", "3m ago")
    var timeAgoDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
