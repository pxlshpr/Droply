//
//  MarkedSong.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/29/25.
//

import Foundation
import SwiftData
import MusicKit

@Model
final class MarkedSong {
    var id: UUID = UUID()
    var appleMusicID: String = "" // MusicKit song ID
    var title: String = ""
    var artist: String = ""
    var albumTitle: String?
    var artworkURL: String?
    var duration: TimeInterval = 0
    var createdAt: Date = Date()
    var lastPlayedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \SongMarker.song)
    var markers: [SongMarker]?

    init(
        id: UUID = UUID(),
        appleMusicID: String,
        title: String,
        artist: String,
        albumTitle: String? = nil,
        artworkURL: String? = nil,
        duration: TimeInterval,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.appleMusicID = appleMusicID
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.artworkURL = artworkURL
        self.duration = duration
        self.createdAt = createdAt
        self.markers = []
    }

    /// Get markers sorted by timestamp
    var sortedMarkers: [SongMarker] {
        (markers ?? []).sorted { $0.timestamp < $1.timestamp }
    }
}

// Extension to create from MusicKit Song
extension MarkedSong {
    convenience init(from song: Song) {
        self.init(
            appleMusicID: song.id.rawValue,
            title: song.title,
            artist: song.artistName,
            albumTitle: song.albumTitle,
            artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
            duration: song.duration ?? 0
        )
    }
}
