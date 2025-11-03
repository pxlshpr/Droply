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
    var appleMusicID: String = "" // MusicKit song ID (for Apple Music tracks)
    var persistentID: String = "" // MPMediaItem persistent ID (for local tracks)
    var title: String = ""
    var artist: String = ""
    var albumTitle: String?
    var artworkURL: String?
    var duration: TimeInterval = 0
    var createdAt: Date = Date()
    var lastPlayedAt: Date?
    var lastMarkedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \SongMarker.song)
    var markers: [SongMarker]?

    /// Whether this is a local synced track
    var isLocal: Bool {
        !persistentID.isEmpty && appleMusicID.isEmpty
    }

    /// Whether this is an Apple Music catalog track
    var isAppleMusic: Bool {
        !appleMusicID.isEmpty
    }

    init(
        id: UUID = UUID(),
        appleMusicID: String = "",
        persistentID: String = "",
        title: String,
        artist: String,
        albumTitle: String? = nil,
        artworkURL: String? = nil,
        duration: TimeInterval,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.appleMusicID = appleMusicID
        self.persistentID = persistentID
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

// Extension to create from PlayableTrack
extension MarkedSong {
    convenience init(from track: PlayableTrack) {
        let appleMusicID = track.appleStoreID ?? ""
        let persistentID = track.persistentID ?? ""

        // Get artwork URL based on track type
        var artworkURL: String?
        if case .musicKit(let artwork) = track.artwork {
            artworkURL = artwork?.url(width: 300, height: 300)?.absoluteString
        }
        // Note: For local tracks with .mediaPlayer artwork, we can't store a URL
        // The artwork will need to be retrieved from the MPMediaItem at runtime

        self.init(
            appleMusicID: appleMusicID,
            persistentID: persistentID,
            title: track.title,
            artist: track.artistName,
            albumTitle: track.albumTitle,
            artworkURL: artworkURL,
            duration: track.duration
        )
    }

    // Legacy: Keep for backwards compatibility
    convenience init(from song: Song) {
        self.init(
            appleMusicID: song.id.rawValue,
            persistentID: "",
            title: song.title,
            artist: song.artistName,
            albumTitle: song.albumTitle,
            artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
            duration: song.duration ?? 0
        )
    }
}
