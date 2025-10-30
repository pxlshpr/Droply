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
    var cueTime: TimeInterval = 0 // Seconds to start before the marker
    var createdAt: Date = Date()
    var song: MarkedSong?

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        emoji: String = "🎵",
        name: String? = nil,
        cueTime: TimeInterval = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.emoji = emoji
        self.name = name
        self.cueTime = cueTime
        self.createdAt = createdAt
    }

    /// Get the playback start time accounting for cue time
    var playbackStartTime: TimeInterval {
        max(0, timestamp - cueTime)
    }

    /// Display name for the marker
    var displayName: String {
        if let name = name, !name.isEmpty {
            return "\(emoji) \(name)"
        }
        return emoji
    }
}
