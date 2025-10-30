//
//  ItemToPlay.swift
//  Droply
//
//  Simplified from MusicStack framework
//

import Foundation
import MediaPlayer
import MusicKit

/// Represents a music item that can be played
public struct ItemToPlay: Identifiable, Hashable {
    public let id: String
    public let isPlayable: Bool
    public let appleStoreID: String?
    public let applePersistentID: String?
    public let title: String
    public let artist: String
    public let durationInSeconds: Double?
    public let isrc: String?

    public init(
        id: String,
        isPlayable: Bool,
        appleStoreID: String?,
        applePersistentID: String?,
        title: String,
        artist: String,
        durationInSeconds: Double?,
        isrc: String?
    ) {
        self.id = id
        self.isPlayable = isPlayable
        self.appleStoreID = appleStoreID
        self.applePersistentID = applePersistentID
        self.title = title
        self.artist = artist
        self.durationInSeconds = durationInSeconds
        self.isrc = isrc
    }

    /// Creates an ItemToPlay from a MusicKit Song
    public init(song: Song) {
        self.init(
            id: song.id.rawValue,
            isPlayable: true,
            appleStoreID: song.id.rawValue,
            applePersistentID: nil,
            title: song.title,
            artist: song.artistName,
            durationInSeconds: song.duration,
            isrc: song.isrc
        )
    }
}

// MARK: - Helpers

extension ItemToPlay {
    /// Whether this is an Apple Music library item (downloaded/added to library)
    var isAppleLibraryItem: Bool {
        applePersistentID != nil
    }

    /// Whether this is an Apple Music store item (catalog/streaming)
    var isAppleStoreItem: Bool {
        appleStoreID != nil
    }

    /// Returns valid persistent ID or nil
    var validApplePersistentID: String? {
        guard isAppleLibraryItem else { return nil }
        return applePersistentID
    }

    /// Returns valid store ID or nil
    var validAppleStoreID: String? {
        guard isAppleStoreItem else { return nil }
        return appleStoreID
    }
}
