//
//  MusicKitService.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/29/25.
//

import Foundation
import MusicKit
import Combine

@MainActor
class MusicKitService: ObservableObject {
    static let shared = MusicKitService()

    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    @Published var playbackTime: TimeInterval = 0
    @Published var playbackDuration: TimeInterval = 0

    private let player = ApplicationMusicPlayer.shared
    private var cancellables = Set<AnyCancellable>()
    private var playbackTimer: Timer?

    private init() {
        setupObservers()
        Task {
            await updateAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    func updateAuthorizationStatus() async {
        let status = MusicAuthorization.currentStatus
        authorizationStatus = status
    }

    func requestAuthorization() async -> Bool {
        let status = await MusicAuthorization.request()
        authorizationStatus = status

        switch status {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Playback Observers

    private func setupObservers() {
        // Observe playback state changes
        player.state.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updatePlaybackState()
                }
            }
            .store(in: &cancellables)

        // Start timer for continuous playback time updates
        startPlaybackTimer()
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlaybackTime()
            }
        }
    }

    private func updatePlaybackState() {
        isPlaying = player.state.playbackStatus == .playing

        if let nowPlayingEntry = player.queue.currentEntry,
           case .song(let song) = nowPlayingEntry.item {
            currentSong = song
            playbackDuration = song.duration ?? 0
        }
    }

    private func updatePlaybackTime() {
        playbackTime = player.playbackTime
    }

    // MARK: - Playback Control

    func play() async throws {
        try await player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlayPause() async throws {
        if isPlaying {
            pause()
        } else {
            try await play()
        }
    }

    func seek(to time: TimeInterval) async {
        player.playbackTime = time
        playbackTime = time
    }

    func seekToMarker(_ marker: SongMarker) async {
        let startTime = marker.playbackStartTime
        await seek(to: startTime)
    }

    // MARK: - Queue Management

    func playSong(_ song: Song) async throws {
        player.queue = ApplicationMusicPlayer.Queue(for: [song], startingAt: song)
        try await play()
    }

    func playSongAtPosition(_ song: Song, startTime: TimeInterval) async throws {
        player.queue = ApplicationMusicPlayer.Queue(for: [song], startingAt: song)
        try await play()
        await seek(to: startTime)
    }

    // MARK: - Search

    func searchSongs(query: String) async throws -> [Song] {
        guard authorizationStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }

        var searchRequest = MusicCatalogSearchRequest(term: query, types: [Song.self])
        searchRequest.limit = 25

        let searchResponse = try await searchRequest.response()
        return Array(searchResponse.songs)
    }

    // MARK: - Current Playback Info

    func getCurrentPlaybackInfo() -> (song: Song, time: TimeInterval)? {
        guard let song = currentSong else { return nil }
        return (song, playbackTime)
    }
}

enum MusicKitError: LocalizedError {
    case notAuthorized
    case notFound

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Apple Music access not authorized"
        case .notFound:
            return "Song not found"
        }
    }
}
