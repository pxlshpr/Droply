//
//  SongMarker.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/29/25.
//

import Foundation
import SwiftData

@Model
final class SongMarker {
    var id: UUID = UUID()
    var timestamp: TimeInterval = 0 // Position in the song (seconds)
    var emoji: String = "🎵"
    var name: String?
    var bufferTime: TimeInterval = 0 // Seconds to start before the marker
    var createdAt: Date = Date()
    var song: MarkedSong?

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        emoji: String = "🎵",
        name: String? = nil,
        bufferTime: TimeInterval = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.emoji = emoji
        self.name = name
        self.bufferTime = bufferTime
        self.createdAt = createdAt
    }

    /// Get the playback start time accounting for buffer
    var playbackStartTime: TimeInterval {
        max(0, timestamp - bufferTime)
    }

    /// Display name for the marker
    var displayName: String {
        if let name = name, !name.isEmpty {
            return "\(emoji) \(name)"
        }
        return emoji
    }
}
