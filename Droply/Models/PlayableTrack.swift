//
//  PlayableTrack.swift
//  Droply
//
//  Unified model for both Apple Music and local tracks
//

import Foundation
import MediaPlayer
import MusicKit
import SwiftData

/// Lightweight DTO for track metadata - extracted synchronously from SwiftData
/// This avoids SwiftData threading issues when passing data to async contexts
struct TrackMetadataDTO {
    let appleMusicID: String
    let persistentID: String
    let title: String
    let artist: String
    let albumTitle: String?
    let duration: TimeInterval
    let artworkURL: String?
    let isAppleMusic: Bool
    let isLocal: Bool

    init(from markedSong: MarkedSong) {
        // Extract all data synchronously in one go
        self.appleMusicID = markedSong.appleMusicID
        self.persistentID = markedSong.persistentID
        self.title = markedSong.title
        self.artist = markedSong.artist
        self.albumTitle = markedSong.albumTitle
        self.duration = markedSong.duration
        self.artworkURL = markedSong.artworkURL
        self.isAppleMusic = markedSong.isAppleMusic
        self.isLocal = markedSong.isLocal
    }
}

/// Represents a track that can be played, supporting both Apple Music catalog tracks and local synced tracks
public struct PlayableTrack: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let artistName: String
    public let albumTitle: String?
    public let duration: TimeInterval
    public let artwork: TrackArtwork
    public let source: TrackSource

    /// Whether this track is from Apple Music catalog
    public var isAppleMusic: Bool {
        if case .appleMusic = source { return true }
        return false
    }

    /// Whether this track is a local/synced track
    public var isLocal: Bool {
        if case .local = source { return true }
        return false
    }

    /// Get the Apple Music store ID if available
    public var appleStoreID: String? {
        switch source {
        case .appleMusic(_, let storeID):
            return storeID
        case .cached(.appleMusic, let id):
            return id
        default:
            return nil
        }
    }

    /// Get the persistent ID if this is a local track
    public var persistentID: String? {
        switch source {
        case .local(_, let persistentID):
            return String(persistentID)
        case .cached(.local, let id):
            return id
        default:
            return nil
        }
    }

    /// Get the underlying MusicKit Song if available
    public var song: Song? {
        if case .appleMusic(let song, _) = source {
            return song
        }
        return nil
    }

    /// Get the underlying MPMediaItem if available
    public var mediaItem: MPMediaItem? {
        if case .local(let mediaItem, _) = source {
            return mediaItem
        }
        return nil
    }

    public enum TrackSource: Hashable {
        case appleMusic(Song, storeID: String)
        case local(MPMediaItem, persistentID: UInt64)
        case cached(type: CachedTrackType, id: String)

        public enum CachedTrackType: Hashable {
            case appleMusic
            case local
        }

        public static func == (lhs: TrackSource, rhs: TrackSource) -> Bool {
            switch (lhs, rhs) {
            case (.appleMusic(_, let lhsID), .appleMusic(_, let rhsID)):
                return lhsID == rhsID
            case (.local(_, let lhsID), .local(_, let rhsID)):
                return lhsID == rhsID
            case (.cached(let lhsType, let lhsID), .cached(let rhsType, let rhsID)):
                return lhsType == rhsType && lhsID == rhsID
            default:
                return false
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .appleMusic(_, let storeID):
                hasher.combine("appleMusic")
                hasher.combine(storeID)
            case .local(_, let persistentID):
                hasher.combine("local")
                hasher.combine(persistentID)
            case .cached(let type, let id):
                hasher.combine("cached")
                hasher.combine(type)
                hasher.combine(id)
            }
        }
    }

    public static func == (lhs: PlayableTrack, rhs: PlayableTrack) -> Bool {
        lhs.id == rhs.id && lhs.source == rhs.source
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(source)
    }
}

// MARK: - Initializers

extension PlayableTrack {
    /// Create a PlayableTrack from a MusicKit Song
    public init(song: Song) {
        self.id = song.id.rawValue
        self.title = song.title
        self.artistName = song.artistName
        self.albumTitle = song.albumTitle
        self.duration = song.duration ?? 0
        self.artwork = .musicKit(song.artwork)
        self.source = .appleMusic(song, storeID: song.id.rawValue)
    }

    /// Create a PlayableTrack from a local MPMediaItem
    public init(mediaItem: MPMediaItem) {
        self.id = String(mediaItem.persistentID)
        self.title = mediaItem.title ?? "Unknown"
        self.artistName = mediaItem.artist ?? "Unknown"
        self.albumTitle = mediaItem.albumTitle
        self.duration = mediaItem.playbackDuration
        self.artwork = .mediaPlayer(mediaItem.artwork)
        self.source = .local(mediaItem, persistentID: mediaItem.persistentID)
    }

    /// Create a PlayableTrack from cached MarkedSong data (instant, no API calls)
    /// This enables immediate UI updates while full track data is fetched in background
    init(cachedFrom markedSong: MarkedSong) {
        if markedSong.isAppleMusic {
            self.id = markedSong.appleMusicID
            self.source = .cached(type: .appleMusic, id: markedSong.appleMusicID)
        } else {
            self.id = markedSong.persistentID
            self.source = .cached(type: .local, id: markedSong.persistentID)
        }

        self.title = markedSong.title
        self.artistName = markedSong.artist
        self.albumTitle = markedSong.albumTitle
        self.duration = markedSong.duration
        self.artwork = .cachedURL(markedSong.artworkURL)
    }

    /// Create a PlayableTrack from cached metadata DTO (instant, no SwiftData access)
    /// This enables immediate UI updates without SwiftData threading issues
    init(cachedFrom metadata: TrackMetadataDTO) {
        if metadata.isAppleMusic {
            self.id = metadata.appleMusicID
            self.source = .cached(type: .appleMusic, id: metadata.appleMusicID)
        } else {
            self.id = metadata.persistentID
            self.source = .cached(type: .local, id: metadata.persistentID)
        }

        self.title = metadata.title
        self.artistName = metadata.artist
        self.albumTitle = metadata.albumTitle
        self.duration = metadata.duration
        self.artwork = .cachedURL(metadata.artworkURL)
    }
}

// MARK: - Artwork Wrapper

/// Wrapper for handling both MusicKit and MediaPlayer artwork
public enum TrackArtwork: Hashable {
    case musicKit(MusicKit.Artwork?)
    case mediaPlayer(MPMediaItemArtwork?)
    case cachedURL(String?) // For cached tracks with only artwork URL

    /// Get artwork URL for MusicKit artwork or cached URL
    public func url(width: Int, height: Int) -> URL? {
        switch self {
        case .musicKit(let artwork):
            return artwork?.url(width: width, height: height)
        case .cachedURL(let urlString):
            return urlString.flatMap { URL(string: $0) }
        default:
            return nil
        }
    }

    /// Get UIImage for MediaPlayer artwork
    public func image(size: CGSize) -> UIImage? {
        if case .mediaPlayer(let artwork) = self {
            return artwork?.image(at: size)
        }
        return nil
    }

    /// Whether artwork is available
    public var isAvailable: Bool {
        switch self {
        case .musicKit(let artwork):
            return artwork != nil
        case .mediaPlayer(let artwork):
            return artwork != nil
        case .cachedURL(let url):
            return url != nil
        }
    }

    public static func == (lhs: TrackArtwork, rhs: TrackArtwork) -> Bool {
        switch (lhs, rhs) {
        case (.musicKit(let lhsArt), .musicKit(let rhsArt)):
            return lhsArt == rhsArt
        case (.mediaPlayer, .mediaPlayer):
            // MPMediaItemArtwork doesn't conform to Equatable, so we just check both are mediaPlayer
            return true
        case (.cachedURL(let lhsURL), .cachedURL(let rhsURL)):
            return lhsURL == rhsURL
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .musicKit(let artwork):
            hasher.combine("musicKit")
            hasher.combine(artwork)
        case .mediaPlayer:
            hasher.combine("mediaPlayer")
        case .cachedURL(let url):
            hasher.combine("cachedURL")
            hasher.combine(url)
        }
    }
}
