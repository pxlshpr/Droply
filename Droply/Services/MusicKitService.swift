//
//  MusicKitService.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/29/25.
//

import Foundation
import MusicKit
import Combine
import OSLog
import MediaPlayer

@MainActor
class MusicKitService: ObservableObject {
    static let shared = MusicKitService()

    private let logger = Logger(subsystem: "com.droply.app", category: "MusicKit")

    @Published var authorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    @Published var playbackTime: TimeInterval = 0
    @Published var playbackDuration: TimeInterval = 0
    @Published var isDragging: Bool = false
    @Published var isCheckingPlayback: Bool = true

    private let player = ApplicationMusicPlayer.shared
    private let systemPlayer = MPMusicPlayerController.systemMusicPlayer
    private var cancellables = Set<AnyCancellable>()
    private var playbackTimer: Timer?
    private var isSeeking = false
    private var seekDebounceTask: Task<Void, Never>?

    private init() {
        logger.info("MusicKitService initializing")
        setupObservers()
        Task {
            await updateAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    func updateAuthorizationStatus() async {
        let status = MusicAuthorization.currentStatus
        logger.info("Authorization status updated: \(String(describing: status))")
        authorizationStatus = status
    }

    func requestAuthorization() async -> Bool {
        logger.info("Requesting MusicKit authorization")
        let status = await MusicAuthorization.request()
        authorizationStatus = status
        logger.info("Authorization request completed with status: \(String(describing: status))")

        switch status {
        case .authorized:
            logger.info("Authorization granted")
            return true
        case .denied, .restricted:
            logger.warning("Authorization denied or restricted")
            return false
        case .notDetermined:
            logger.warning("Authorization still not determined")
            return false
        @unknown default:
            logger.error("Unknown authorization status")
            return false
        }
    }

    // MARK: - Playback Observers

    private func setupObservers() {
        logger.info("Setting up playback observers")

        // Enable notifications for system music player
        systemPlayer.beginGeneratingPlaybackNotifications()
        logger.info("Enabled system music player notifications")

        // Observe system music player now playing item changes
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: systemPlayer,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logger.info("System music player: now playing item changed")
                self?.updateSystemPlayerState()
            }
        }

        // Observe system music player playback state changes
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: systemPlayer,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logger.info("System music player: playback state changed")
                self?.updateSystemPlayerState()
            }
        }

        // Observe app music player state changes (for when playing from within the app)
        player.state.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.logger.debug("App player state changed, updating playback state")
                    self?.updatePlaybackState()
                }
            }
            .store(in: &cancellables)

        // Initial update from system player
        Task {
            await performInitialPlaybackCheck()
        }

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

    private func performInitialPlaybackCheck() async {
        logger.debug("Performing initial playback check")

        // Update playback state
        let playbackState = systemPlayer.playbackState
        isPlaying = playbackState == .playing
        logger.debug("System player playback state: \(String(describing: playbackState))")

        // Get current media item
        guard let mediaItem = systemPlayer.nowPlayingItem else {
            logger.warning("System player has no now playing item on startup")
            currentSong = nil
            isCheckingPlayback = false
            return
        }

        logger.info("System player now playing on startup: \(mediaItem.title ?? "Unknown") by \(mediaItem.artist ?? "Unknown")")

        // Try to convert MPMediaItem to MusicKit Song
        await convertMediaItemToSong(mediaItem)

        // Mark check as complete
        isCheckingPlayback = false
        logger.debug("Initial playback check completed")
    }

    private func updateSystemPlayerState() {
        logger.debug("Updating from system music player")

        // Update playback state
        let playbackState = systemPlayer.playbackState
        isPlaying = playbackState == .playing
        logger.debug("System player playback state: \(String(describing: playbackState))")

        // Get current media item
        guard let mediaItem = systemPlayer.nowPlayingItem else {
            logger.warning("System player has no now playing item")
            currentSong = nil
            return
        }

        logger.info("System player now playing: \(mediaItem.title ?? "Unknown") by \(mediaItem.artist ?? "Unknown")")

        // Try to convert MPMediaItem to MusicKit Song
        Task {
            await convertMediaItemToSong(mediaItem)
        }
    }

    private func convertMediaItemToSong(_ mediaItem: MPMediaItem) async {
        // Get playback store ID if available (for Apple Music tracks)
        let playbackStoreID = mediaItem.playbackStoreID

        if !playbackStoreID.isEmpty {
            logger.debug("Media item has playback store ID: \(playbackStoreID)")

            do {
                // Try to fetch the song from MusicKit using the store ID
                let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(playbackStoreID))
                let response = try await request.response()

                if let song = response.items.first {
                    await MainActor.run {
                        self.currentSong = song
                        self.playbackDuration = song.duration ?? 0
                        self.playbackTime = systemPlayer.currentPlaybackTime
                        logger.info("Successfully converted to MusicKit Song: \(song.title)")
                    }
                } else {
                    logger.warning("Could not find MusicKit song for store ID: \(playbackStoreID)")
                    await handleLocalMediaItem(mediaItem)
                }
            } catch {
                logger.error("Failed to fetch MusicKit song: \(error.localizedDescription)")
                await handleLocalMediaItem(mediaItem)
            }
        } else {
            logger.warning("Media item has no playback store ID - likely a local/synced track")
            await handleLocalMediaItem(mediaItem)
        }
    }

    private func handleLocalMediaItem(_ mediaItem: MPMediaItem) async {
        // For local tracks, we can't get a MusicKit Song, so currentSong remains nil
        // But we can still update duration and playback time
        await MainActor.run {
            self.currentSong = nil
            self.playbackDuration = mediaItem.playbackDuration
            self.playbackTime = systemPlayer.currentPlaybackTime
            logger.info("Using local media item (no MusicKit Song available)")
        }
    }

    private func updatePlaybackState() {
        let playbackStatus = player.state.playbackStatus
        isPlaying = playbackStatus == .playing

        // Log detailed queue information
        let queueEntries = player.queue.entries
        logger.debug("App player playback status: \(String(describing: playbackStatus)), isPlaying: \(self.isPlaying)")
        logger.debug("App player queue has \(queueEntries.count) entries")

        if let nowPlayingEntry = player.queue.currentEntry {
            logger.debug("Current queue entry exists at index: \(queueEntries.firstIndex(where: { $0.id == nowPlayingEntry.id }) ?? -1)")
            if case .song(let song) = nowPlayingEntry.item {
                currentSong = song
                playbackDuration = song.duration ?? 0
                logger.info("Current song updated from app player: \(song.title) by \(song.artistName) (ID: \(song.id.rawValue))")
            } else {
                logger.warning("Current queue entry is not a song, type: \(String(describing: nowPlayingEntry.item))")
            }
        } else {
            logger.debug("No current queue entry in app player")
        }
    }

    private func updatePlaybackTime() {
        // Don't update playback time while seeking or dragging to prevent race condition
        guard !isSeeking && !isDragging else {
            return
        }

        // Prefer system player if it's playing
        if systemPlayer.playbackState == .playing || systemPlayer.nowPlayingItem != nil {
            playbackTime = systemPlayer.currentPlaybackTime
        } else {
            playbackTime = player.playbackTime
        }
    }

    // MARK: - Playback Control

    func play() async throws {
        logger.info("Attempting to play")
        do {
            try await player.play()
            isPlaying = true
            logger.info("Play command successful")
        } catch {
            logger.error("Failed to play: \(error.localizedDescription)")
            throw error
        }
    }

    func pause() {
        logger.info("Pausing playback")
        player.pause()
        isPlaying = false
    }

    func togglePlayPause() async throws {
        logger.info("Toggling play/pause - current state: \(self.isPlaying ? "playing" : "paused")")
        if isPlaying {
            pause()
        } else {
            try await play()
        }
    }

    func skipToNextItem() async throws {
        logger.info("Skipping to next item")

        // Determine which player is active
        if systemPlayer.playbackState == .playing || systemPlayer.nowPlayingItem != nil {
            // Use system player for next
            logger.debug("Skipping next on system player")
            systemPlayer.skipToNextItem()
        } else {
            // Use app player for next
            logger.debug("Skipping next on app player")
            try await player.skipToNextEntry()
        }
        logger.info("Skip to next completed")
    }

    func skipToPreviousItem() async throws {
        logger.info("Skipping to previous item")

        // Determine which player is active
        if systemPlayer.playbackState == .playing || systemPlayer.nowPlayingItem != nil {
            // Use system player for previous
            logger.debug("Skipping previous on system player")
            systemPlayer.skipToPreviousItem()
        } else {
            // Use app player for previous
            logger.debug("Skipping previous on app player")
            try await player.skipToPreviousEntry()
        }
        logger.info("Skip to previous completed")
    }

    func seek(to time: TimeInterval) async {
        logger.info("Seeking to time: \(time)")

        // Cancel any pending seek debounce
        seekDebounceTask?.cancel()

        // Set seeking flag to prevent timer from overwriting
        isSeeking = true

        // Determine which player is active and seek on the correct one
        if systemPlayer.playbackState == .playing || systemPlayer.nowPlayingItem != nil {
            // Use system player for seeking
            logger.debug("Seeking on system player")
            systemPlayer.currentPlaybackTime = time
        } else {
            // Use app player for seeking
            logger.debug("Seeking on app player")
            player.playbackTime = time
        }

        // Update our published property
        playbackTime = time

        // Debounce: clear the seeking flag after a delay to allow Apple Music to process
        seekDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            if !Task.isCancelled {
                self.isSeeking = false
                logger.debug("Seek debounce completed, resuming playback time updates")
            }
        }
    }

    func seekToMarker(_ marker: SongMarker) async {
        let startTime = marker.playbackStartTime
        await seek(to: startTime)
    }

    // MARK: - Dragging State Management

    func startDragging() {
        logger.debug("Started dragging")
        isDragging = true
    }

    func endDragging(at time: TimeInterval) async {
        logger.debug("Ended dragging at time: \(time)")
        isDragging = false
        await seek(to: time)
    }

    func updateDragPosition(to time: TimeInterval) {
        // Update the UI position without actually seeking
        playbackTime = time
    }

    // MARK: - Queue Management

    func playSong(_ song: Song) async throws {
        logger.info("Setting up queue to play song: \(song.title) by \(song.artistName)")
        player.queue = ApplicationMusicPlayer.Queue(for: [song], startingAt: song)
        logger.debug("Queue set, attempting to play")
        try await play()
    }

    func playSongAtPosition(_ song: Song, startTime: TimeInterval) async throws {
        logger.info("Setting up queue to play song: \(song.title) by \(song.artistName) at \(startTime)s")
        player.queue = ApplicationMusicPlayer.Queue(for: [song], startingAt: song)
        logger.debug("Queue set, attempting to play")
        try await play()
        await seek(to: startTime)
    }

    // MARK: - Search

    func searchSongs(query: String) async throws -> [Song] {
        logger.info("Searching songs with query: '\(query)'")
        guard authorizationStatus == .authorized else {
            logger.error("Search failed - not authorized")
            throw MusicKitError.notAuthorized
        }

        var searchRequest = MusicCatalogSearchRequest(term: query, types: [Song.self])
        searchRequest.limit = 25

        do {
            let searchResponse = try await searchRequest.response()
            let songs = Array(searchResponse.songs)
            logger.info("Search completed - found \(songs.count) songs")
            return songs
        } catch {
            logger.error("Search failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Current Playback Info

    func getCurrentPlaybackInfo() -> (song: Song, time: TimeInterval)? {
        guard let song = currentSong else { return nil }
        return (song, playbackTime)
    }

    // MARK: - Diagnostics

    func logCurrentState() {
        logger.info("=== MusicKit Diagnostics ===")
        logger.info("Authorization: \(String(describing: self.authorizationStatus))")
        logger.info("Is Playing: \(self.isPlaying)")
        logger.info("--- System Music Player ---")
        logger.info("System playback state: \(String(describing: self.systemPlayer.playbackState))")
        logger.info("System now playing: \(self.systemPlayer.nowPlayingItem?.title ?? "nil")")
        logger.info("System artist: \(self.systemPlayer.nowPlayingItem?.artist ?? "nil")")
        logger.info("System playback time: \(self.systemPlayer.currentPlaybackTime)")
        logger.info("--- App Music Player ---")
        logger.info("App playback status: \(String(describing: self.player.state.playbackStatus))")
        logger.info("App queue entries: \(self.player.queue.entries.count)")
        logger.info("App current entry: \(self.player.queue.currentEntry == nil ? "nil" : "exists")")
        logger.info("--- Combined State ---")
        logger.info("Current song: \(self.currentSong?.title ?? "nil")")
        logger.info("Playback time: \(self.playbackTime)")
        logger.info("Playback duration: \(self.playbackDuration)")
        logger.info("=========================")
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
