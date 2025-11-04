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
import SwiftUI

@Observable
@MainActor
class MusicKitService {
    static let shared = MusicKitService()

    private let logger = Logger(subsystem: "com.droply.app", category: "MusicKit")

    var authorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    var currentTrack: PlayableTrack?
    var isPlaying: Bool = false
    var playbackTime: TimeInterval = 0
    var playbackDuration: TimeInterval = 0
    var isDragging: Bool = false
    var isCheckingPlayback: Bool = true
    var isLoadingSong: Bool = false
    var loadingSongTitle: String?

    // Pending track state - used to show the upcoming track immediately when tapped
    // while waiting for actual playback to start
    var pendingTrack: PlayableTrack?

    // Pending marked song - used for instant metadata display when tapping a song
    // This shows immediately while the actual track is being fetched/loaded
    var pendingMarkedSong: MarkedSong?

    // Legacy: Keep currentSong and pendingSong for backwards compatibility
    var currentSong: Song? { currentTrack?.song }
    var pendingSong: Song? { pendingTrack?.song }

    // Pre-extracted artwork colors
    var backgroundColor1: Color = .purple.opacity(0.3)
    var backgroundColor2: Color = .blue.opacity(0.3)
    var meshColors: [Color]?
    var backgroundMeshColors: [Color]?

    private let player = ApplicationMusicPlayer.shared
    private let systemPlayer = MPMusicPlayerController.systemMusicPlayer
    private var cancellables = Set<AnyCancellable>()
    private var playbackTimer: Timer?
    private var isSeeking = false
    private var seekDebounceTask: Task<Void, Never>?
    private var pendingSongGraceTask: Task<Void, Never>?
    private let pendingSongGracePeriod: TimeInterval = 3.0 // 3 seconds grace period

    // Track current play operation to allow cancellation
    private var currentPlayTask: Task<Void, Error>?

    // Track the ID of the song we're expecting to play
    // While set, system player updates for different tracks are ignored
    private var expectedTrackID: String?

    private init() {
        logger.info("MusicKitService initializing")
        setupObservers()
        Task {
            await updateAuthorizationStatus()
        }
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
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
            currentTrack = nil
            isCheckingPlayback = false
            return
        }

        logger.info("System player now playing on startup: \(mediaItem.title ?? "Unknown") by \(mediaItem.artist ?? "Unknown")")

        // Try to convert MPMediaItem to PlayableTrack
        await convertMediaItemToTrack(mediaItem)

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
            currentTrack = nil
            return
        }

        logger.info("System player now playing: \(mediaItem.title ?? "Unknown") by \(mediaItem.artist ?? "Unknown")")

        // Clear loading state when playback starts
        if isLoadingSong && playbackState == .playing {
            isLoadingSong = false
            loadingSongTitle = nil
            logger.debug("Cleared loading state - system player is now playing")
        }

        // Try to convert MPMediaItem to PlayableTrack
        Task {
            await convertMediaItemToTrack(mediaItem)
        }
    }

    private func convertMediaItemToTrack(_ mediaItem: MPMediaItem) async {
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
                        let track = PlayableTrack(song: song)

                        // Check if we're expecting a specific track
                        if let expectedID = self.expectedTrackID {
                            if track.id == expectedID {
                                // This is the track we're expecting! Clear the flag and update
                                self.logger.info("✅ Expected track started playing: \(song.title) (id: \(track.id))")
                                self.expectedTrackID = nil
                                self.currentTrack = track
                                self.playbackDuration = song.duration ?? 0
                                self.playbackTime = systemPlayer.currentPlaybackTime
                                self.logger.info("Successfully set currentTrack to expected track")
                            } else {
                                // This is a different track (old track still playing), ignore it
                                self.logger.debug("⏭️ Ignoring system player update for track \(track.id) - expecting \(expectedID)")
                                return
                            }
                        } else {
                            // No specific track expected, update normally
                            self.currentTrack = track
                            self.playbackDuration = song.duration ?? 0
                            self.playbackTime = systemPlayer.currentPlaybackTime
                            self.logger.info("Successfully converted to Apple Music track: \(song.title)")
                        }
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
        // Create a PlayableTrack from the local media item
        await MainActor.run {
            let track = PlayableTrack(mediaItem: mediaItem)

            // Check if we're expecting a specific track
            if let expectedID = self.expectedTrackID {
                if track.id == expectedID {
                    // This is the track we're expecting! Clear the flag and update
                    self.logger.info("✅ Expected local track started playing: \(track.title) (id: \(track.id))")
                    self.expectedTrackID = nil
                    self.currentTrack = track
                    self.playbackDuration = mediaItem.playbackDuration
                    self.playbackTime = systemPlayer.currentPlaybackTime
                    self.logger.info("Successfully set currentTrack to expected local track")
                } else {
                    // This is a different track (old track still playing), ignore it
                    self.logger.debug("⏭️ Ignoring system player update for local track \(track.id) - expecting \(expectedID)")
                    return
                }
            } else {
                // No specific track expected, update normally
                self.currentTrack = track
                self.playbackDuration = mediaItem.playbackDuration
                self.playbackTime = systemPlayer.currentPlaybackTime
                self.logger.info("Using local track: \(track.title) by \(track.artistName) (persistent ID: \(mediaItem.persistentID))")
            }
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
                let track = PlayableTrack(song: song)

                // Check if we're expecting a specific track
                if let expectedID = expectedTrackID {
                    if track.id == expectedID {
                        // This is the track we're expecting! Clear the flag and update
                        logger.info("✅ Expected track started playing (app player): \(song.title) (id: \(track.id))")
                        expectedTrackID = nil
                        currentTrack = track
                        playbackDuration = song.duration ?? 0
                        logger.info("Successfully set currentTrack to expected track from app player")
                    } else {
                        // This is a different track (old track still playing), ignore it
                        logger.debug("⏭️ Ignoring app player update for track \(track.id) - expecting \(expectedID)")
                        return
                    }
                } else {
                    // No specific track expected, update normally
                    currentTrack = track
                    playbackDuration = song.duration ?? 0
                    logger.info("Current track updated from app player: \(song.title) by \(song.artistName) (ID: \(song.id.rawValue))")
                }

                // Clear loading state when song is confirmed to be playing
                if isLoadingSong && playbackStatus == .playing {
                    isLoadingSong = false
                    loadingSongTitle = nil
                    logger.debug("Cleared loading state - song is now playing")
                }
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

        // Determine which player is active
        if systemPlayer.playbackState != .stopped && (systemPlayer.playbackState == .playing || systemPlayer.nowPlayingItem != nil) {
            // Use system player for play
            logger.debug("Playing on system player")
            systemPlayer.play()
            isPlaying = true
            logger.info("Play command successful on system player")
        } else {
            // Use app player for play
            logger.debug("Playing on app player")
            do {
                try await player.play()
                isPlaying = true
                logger.info("Play command successful on app player")
            } catch {
                logger.error("Failed to play on app player: \(error.localizedDescription)")
                throw error
            }
        }
    }

    func pause() async throws {
        logger.info("Pausing playback")

        // Determine which player is active and pause the correct one
        if systemPlayer.playbackState == .playing || systemPlayer.nowPlayingItem != nil {
            logger.debug("Pausing system player")
            systemPlayer.pause()
        } else {
            logger.debug("Pausing app player")
            player.pause()
        }

        isPlaying = false
    }

    func togglePlayPause() async throws {
        logger.info("Toggling play/pause - current state: \(self.isPlaying ? "playing" : "paused")")

        // Determine which player is active
        if systemPlayer.playbackState == .playing || systemPlayer.nowPlayingItem != nil {
            // Use system player for play/pause
            logger.debug("Toggling play/pause on system player")
            if isPlaying {
                systemPlayer.pause()
                isPlaying = false
            } else {
                systemPlayer.play()
                isPlaying = true
            }
        } else {
            // Use app player for play/pause
            logger.debug("Toggling play/pause on app player")
            if isPlaying {
                try await pause()
            } else {
                try await play()
            }
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

        // Smart previous behavior: if we're past 3 seconds, restart the song
        // Otherwise, go to the previous song (like Apple Music)
        let threshold: TimeInterval = 3.0

        if playbackTime > threshold {
            logger.debug("Playback time (\(self.playbackTime)s) > threshold (\(threshold)s), restarting song")
            await seek(to: 0)
        } else {
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

    // MARK: - Pending Track Management

    /// Set pending marked song for instant metadata display
    /// Call this immediately when user taps a song to show metadata before playback starts
    public func setPendingMarkedSong(_ markedSong: MarkedSong) {
        let time = timestamp()
        logger.info("[\(time)] 📝 Setting pending marked song: \(markedSong.title) by \(markedSong.artist)")
        pendingMarkedSong = markedSong
        let doneTime = timestamp()
        logger.debug("[\(doneTime)] 📝 pendingMarkedSong is now set to: \(markedSong.title)")
    }

    /// Clear pending marked song
    public func clearPendingMarkedSong() {
        logger.debug("Clearing pending marked song")
        pendingMarkedSong = nil
    }

    /// SYNCHRONOUSLY set track metadata from cached data (INSTANT!)
    /// This runs on the main thread immediately when tapped - no async delays
    /// Uses a DTO to avoid SwiftData threading issues
    public func setTrackMetadataFromCache(_ metadata: TrackMetadataDTO) {
        let startTime = timestamp()
        logger.info("[\(startTime)] 📥 Setting track metadata from cache for: \(metadata.title) by \(metadata.artist)")

        // Create PlayableTrack from DTO (pure data, no SwiftData access)
        let preCreateTime = timestamp()
        logger.debug("[\(preCreateTime)] 📦 Creating cached PlayableTrack from DTO...")
        let cachedTrack = PlayableTrack(cachedFrom: metadata)
        let postCreateTime = timestamp()
        logger.debug("[\(postCreateTime)] 📦 Created cached track - id: \(cachedTrack.id), title: \(cachedTrack.title)")

        let preSetTrackTime = timestamp()
        logger.debug("[\(preSetTrackTime)] 🎵 Setting pending track...")
        setPendingTrack(cachedTrack)
        logger.debug("📊 After setPendingTrack: pendingTrack.title = \(self.pendingTrack?.title ?? "nil")")
        logger.debug("📊 After setPendingTrack: pendingTrack.artistName = \(self.pendingTrack?.artistName ?? "nil")")

        let postSetTrackTime = timestamp()
        playbackDuration = metadata.duration
        logger.info("[\(postSetTrackTime)] ✅ Cached track metadata set instantly: \(metadata.title)")
        logger.info("📊 Final state check: pendingTrack is \(self.pendingTrack == nil ? "NIL" : "SET with title: \(self.pendingTrack!.title)")")
    }

    /// Fetch fresh track metadata from API in background
    /// Call this AFTER setTrackMetadataFromCache to update with live data
    public func fetchFreshTrackMetadata(_ metadata: TrackMetadataDTO) async {
        let startTime = timestamp()
        logger.info("[\(startTime)] 🔄 Fetching fresh track metadata for: \(metadata.title)")

        do {
            if metadata.isAppleMusic {
                // Fetch from Apple Music catalog
                let request = MusicCatalogResourceRequest<Song>(
                    matching: \.id,
                    equalTo: MusicItemID(metadata.appleMusicID)
                )
                let response = try await request.response()

                if let song = response.items.first {
                    // Only update if this track is still the pending/current track (avoid race conditions)
                    let currentPendingID = self.pendingTrack?.id
                    let currentTrackID = self.currentTrack?.id
                    let metadataID = metadata.isAppleMusic ? metadata.appleMusicID : metadata.persistentID

                    if currentPendingID == metadataID || currentTrackID == metadataID {
                        let freshTrack = PlayableTrack(song: song)
                        if currentPendingID == metadataID {
                            self.setPendingTrack(freshTrack)
                        }
                        if currentTrackID == metadataID {
                            self.currentTrack = freshTrack
                        }
                        self.playbackDuration = song.duration ?? 0
                        self.logger.info("✅ Updated with fresh Apple Music track metadata: \(song.title)")
                    } else {
                        self.logger.debug("Skipped updating track metadata - user switched to different track")
                    }
                } else {
                    self.logger.warning("Could not find Apple Music track for: \(metadata.title)")
                }
            } else if metadata.isLocal {
                // Look up local track by persistent ID
                if let persistentIDString = metadata.persistentID.isEmpty ? nil : metadata.persistentID,
                   let persistentID = UInt64(persistentIDString) {
                    let query = MPMediaQuery.songs()
                    let predicate = MPMediaPropertyPredicate(
                        value: persistentID,
                        forProperty: MPMediaItemPropertyPersistentID
                    )
                    query.addFilterPredicate(predicate)

                    if let mediaItem = query.items?.first {
                        // Only update if this track is still the pending/current track
                        let currentPendingID = self.pendingTrack?.id
                        let currentTrackID = self.currentTrack?.id

                        if currentPendingID == persistentIDString || currentTrackID == persistentIDString {
                            let freshTrack = PlayableTrack(mediaItem: mediaItem)
                            if currentPendingID == persistentIDString {
                                self.setPendingTrack(freshTrack)
                            }
                            if currentTrackID == persistentIDString {
                                self.currentTrack = freshTrack
                            }
                            self.playbackDuration = mediaItem.playbackDuration
                            self.logger.info("✅ Updated with fresh local track metadata: \(freshTrack.title)")
                        } else {
                            self.logger.debug("Skipped updating track metadata - user switched to different track")
                        }
                    } else {
                        self.logger.warning("Could not find local track for: \(metadata.title)")
                    }
                }
            }
        } catch {
            self.logger.error("Failed to fetch fresh track metadata: \(error.localizedDescription)")
        }
    }

    private func setPendingTrack(_ track: PlayableTrack) {
        let startTime = timestamp()
        logger.info("[\(startTime)] 🎵 Setting pending track: \(track.title) by \(track.artistName)")
        logger.debug("[\(startTime)] 🎵 Track details - id: \(track.id), isAppleMusic: \(track.isAppleMusic), isLocal: \(track.isLocal)")
        logger.debug("[\(startTime)] 🎵 BEFORE: currentTrack = \(self.currentTrack?.title ?? "nil"), pendingTrack = \(self.pendingTrack?.title ?? "nil")")

        // Cancel any existing grace period
        pendingSongGraceTask?.cancel()

        // Set expected track ID to prevent system player from overriding with old track
        expectedTrackID = track.id
        logger.debug("[\(startTime)] 🎯 Set expectedTrackID = \(track.id) - will ignore system player updates for different tracks")

        // Clear current track so pending track is displayed immediately
        let clearTime = timestamp()
        currentTrack = nil
        logger.debug("[\(clearTime)] 🗑️ Cleared currentTrack to show pending track in UI")

        // Set the pending track (@Observable will automatically notify observers)
        let preSetTime = timestamp()
        pendingTrack = track
        let postSetTime = timestamp()
        logger.info("[\(postSetTime)] ✅ pendingTrack variable set (took \(postSetTime) - \(preSetTime))")
        logger.debug("[\(postSetTime)] 🎵 AFTER: currentTrack = \(self.currentTrack?.title ?? "nil"), pendingTrack = \(self.pendingTrack?.title ?? "nil")")
        logger.info("[\(postSetTime)] 🎵 @Observable will automatically notify UI - should update to show: \(track.title)")

        // Start grace period timer
        pendingSongGraceTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(pendingSongGracePeriod * 1_000_000_000))

                // If we reach here and the track still hasn't started playing, clear the pending state
                if !Task.isCancelled && self.currentTrack == nil {
                    logger.warning("Grace period expired and track hasn't started playing - clearing pending track")
                    self.clearPendingTrack()
                }
            } catch {
                // Task was cancelled, which is fine
                logger.debug("Pending track grace period task cancelled")
            }
        }
    }

    private func clearPendingTrack() {
        logger.debug("Clearing pending track")
        pendingSongGraceTask?.cancel()
        pendingSongGraceTask = nil
        pendingTrack = nil
        pendingMarkedSong = nil
    }

    /// Helper to set currentTrack with side effects (color extraction, clearing pending)
    private func setCurrentTrack(_ track: PlayableTrack?) {
        currentTrack = track

        // Extract colors in background
        if let track = track {
            Task {
                await extractColorsFromArtwork(for: track)
            }

            // Clear pending track when actual track starts playing
            clearPendingTrack()
        }
    }

    // Legacy methods for backwards compatibility
    private func setPendingSong(_ song: Song) {
        setPendingTrack(PlayableTrack(song: song))
    }

    private func clearPendingSong() {
        clearPendingTrack()
    }

    // MARK: - Queue Management

    func playSong(_ song: Song) async throws {
        // Cancel any existing play operation
        if let existingTask = currentPlayTask {
            logger.info("Cancelling existing play operation before starting new one")
            existingTask.cancel()
            currentPlayTask = nil
        }

        logger.info("Setting up queue to play song: \(song.title) by \(song.artistName)")

        // Set pending song immediately for UI responsiveness
        setPendingSong(song)

        // Set loading state
        isLoadingSong = true
        loadingSongTitle = song.title

        // Create a new task for this play operation
        let playTask = Task<Void, Error> { @MainActor in
            // Check for cancellation before proceeding
            try Task.checkCancellation()

            player.queue = ApplicationMusicPlayer.Queue(for: [song], startingAt: song)

            // Explicitly update currentTrack immediately for UI responsiveness
            let track = PlayableTrack(song: song)
            currentTrack = track
            playbackDuration = song.duration ?? 0

            // Check for cancellation again before playing
            try Task.checkCancellation()

            logger.debug("Queue set, attempting to play")
            try await play()
        }

        // Store the task so it can be cancelled if needed
        currentPlayTask = playTask

        // Await the task and handle cancellation
        do {
            try await playTask.value
            // Clear the task reference on successful completion
            if currentPlayTask == playTask {
                currentPlayTask = nil
            }
        } catch is CancellationError {
            logger.info("Play operation was cancelled")
            // Clear loading state
            isLoadingSong = false
            loadingSongTitle = nil
            throw CancellationError()
        } catch {
            // Clear the task reference on error
            if currentPlayTask == playTask {
                currentPlayTask = nil
            }
            // Clear loading state
            isLoadingSong = false
            loadingSongTitle = nil
            throw error
        }
    }

    func prepareToPlaySong(_ song: Song) async throws {
        logger.info("Preparing queue for song: \(song.title) by \(song.artistName) (without playing)")
        player.queue = ApplicationMusicPlayer.Queue(for: [song], startingAt: song)

        // Explicitly update currentTrack immediately for UI responsiveness
        let track = PlayableTrack(song: song)
        currentTrack = track
        playbackDuration = song.duration ?? 0

        logger.debug("Queue set, ready to play")
    }

    func playSongAtPosition(_ song: Song, startTime: TimeInterval) async throws {
        // Cancel any existing play operation
        if let existingTask = currentPlayTask {
            logger.info("Cancelling existing play operation before starting new one")
            existingTask.cancel()
            currentPlayTask = nil
        }

        logger.info("Setting up queue to play song: \(song.title) by \(song.artistName) at \(startTime)s")

        // Set pending song immediately for UI responsiveness
        setPendingSong(song)

        // Set loading state
        isLoadingSong = true
        loadingSongTitle = song.title

        // Create a new task for this play operation
        let playTask = Task<Void, Error> { @MainActor in
            // Check for cancellation before proceeding
            try Task.checkCancellation()

            player.queue = ApplicationMusicPlayer.Queue(for: [song], startingAt: song)
            logger.debug("Queue set, attempting to play")

            // Check for cancellation again before playing
            try Task.checkCancellation()

            try await play()
            await seek(to: startTime)
        }

        // Store the task so it can be cancelled if needed
        currentPlayTask = playTask

        // Await the task and handle cancellation
        do {
            try await playTask.value
            // Clear the task reference on successful completion
            if currentPlayTask == playTask {
                currentPlayTask = nil
            }
        } catch is CancellationError {
            logger.info("Play operation was cancelled")
            // Clear loading state
            isLoadingSong = false
            loadingSongTitle = nil
            throw CancellationError()
        } catch {
            // Clear the task reference on error
            if currentPlayTask == playTask {
                currentPlayTask = nil
            }
            // Clear loading state
            isLoadingSong = false
            loadingSongTitle = nil
            throw error
        }
    }

    func playSongWithQueueManager(_ song: Song) async throws {
        // Cancel any existing play operation
        if let existingTask = currentPlayTask {
            logger.info("Cancelling existing play operation before starting new one")
            existingTask.cancel()
            currentPlayTask = nil
        }

        logger.info("Playing song with queue manager: \(song.title) by \(song.artistName)")

        // Set pending song immediately for UI responsiveness
        setPendingSong(song)

        // Set loading state
        isLoadingSong = true
        loadingSongTitle = song.title

        // Create a new task for this play operation
        let playTask = Task<Void, Error> { @MainActor in
            // Check for cancellation before proceeding
            try Task.checkCancellation()

            // Convert to ItemToPlay and use queue manager
            let item = ItemToPlay(song: song)

            // Check for cancellation again before making the call
            try Task.checkCancellation()

            try await AppleMusicQueueManager.shared.play(item)

            // Check for cancellation before updating state
            try Task.checkCancellation()

            // Update current track immediately for UI responsiveness
            let track = PlayableTrack(song: song)
            currentTrack = track
            playbackDuration = song.duration ?? 0
            isPlaying = true

            logger.info("Queue manager started playing song")
        }

        // Store the task so it can be cancelled if needed
        currentPlayTask = playTask

        // Await the task and handle cancellation
        do {
            try await playTask.value
            // Clear the task reference on successful completion
            if currentPlayTask == playTask {
                currentPlayTask = nil
            }
        } catch is CancellationError {
            logger.info("Play operation was cancelled")
            // Clear loading state
            isLoadingSong = false
            loadingSongTitle = nil
            throw CancellationError()
        } catch {
            // Clear the task reference on error
            if currentPlayTask == playTask {
                currentPlayTask = nil
            }
            // Clear loading state
            isLoadingSong = false
            loadingSongTitle = nil
            throw error
        }
    }

    func playSongsWithQueueManager(_ songs: [Song]) async throws {
        guard !songs.isEmpty else {
            logger.warning("Attempted to play empty song list")
            throw MusicKitError.notFound
        }

        // Cancel any existing play operation
        if let existingTask = currentPlayTask {
            logger.info("Cancelling existing play operation before starting new one")
            existingTask.cancel()
            currentPlayTask = nil
        }

        logger.info("Playing \(songs.count) songs with queue manager")

        // Set pending song immediately for UI responsiveness
        let firstSong = songs[0]
        setPendingSong(firstSong)

        // Set loading state
        isLoadingSong = true
        loadingSongTitle = firstSong.title

        // Create a new task for this play operation
        let playTask = Task<Void, Error> { @MainActor in
            // Check for cancellation before proceeding
            try Task.checkCancellation()

            // Convert to ItemToPlay array and use queue manager
            let items = songs.map { ItemToPlay(song: $0) }

            // Check for cancellation again before making the call
            try Task.checkCancellation()

            try await AppleMusicQueueManager.shared.playWithDebounce(items)

            // Check for cancellation before updating state
            try Task.checkCancellation()

            // Update current track immediately for UI responsiveness (first song in list)
            let track = PlayableTrack(song: firstSong)
            currentTrack = track
            playbackDuration = firstSong.duration ?? 0
            isPlaying = true

            logger.info("Queue manager started playing songs")
        }

        // Store the task so it can be cancelled if needed
        currentPlayTask = playTask

        // Await the task and handle cancellation
        do {
            try await playTask.value
            // Clear the task reference on successful completion
            if currentPlayTask == playTask {
                currentPlayTask = nil
            }
        } catch is CancellationError {
            logger.info("Play operation was cancelled")
            // Clear loading state
            isLoadingSong = false
            loadingSongTitle = nil
            throw CancellationError()
        } catch {
            // Clear the task reference on error
            if currentPlayTask == playTask {
                currentPlayTask = nil
            }
            // Clear loading state
            isLoadingSong = false
            loadingSongTitle = nil
            throw error
        }
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
        guard let song = currentTrack?.song else { return nil }
        return (song, playbackTime)
    }

    func getCurrentTrackInfo() -> (track: PlayableTrack, time: TimeInterval)? {
        guard let track = currentTrack else { return nil }
        return (track, playbackTime)
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
        logger.info("Current track: \(self.currentTrack?.title ?? "nil")")
        logger.info("Current track type: \(self.currentTrack?.isAppleMusic == true ? "Apple Music" : (self.currentTrack?.isLocal == true ? "Local" : "Unknown"))")
        logger.info("Playback time: \(self.playbackTime)")
        logger.info("Playback duration: \(self.playbackDuration)")
        logger.info("=========================")
    }

    // MARK: - Color Extraction

    private func extractColorsFromArtwork(for track: PlayableTrack?) async {
        guard let track = track else {
            // Reset to default colors if no track
            backgroundColor1 = .purple.opacity(0.3)
            backgroundColor2 = .blue.opacity(0.3)
            meshColors = nil
            backgroundMeshColors = nil
            return
        }

        // Get UIImage from artwork based on track type
        var artworkImage: UIImage?

        switch track.artwork {
        case .musicKit(let artwork):
            // For Apple Music tracks, download the artwork
            guard let url = artwork?.url(width: 300, height: 300) else {
                resetToDefaultColors()
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                artworkImage = UIImage(data: data)
            } catch {
                logger.error("Failed to download artwork: \(error.localizedDescription)")
                resetToDefaultColors()
                return
            }

        case .mediaPlayer(let artwork):
            // For local tracks, get the image directly from MPMediaItemArtwork
            artworkImage = artwork?.image(at: CGSize(width: 300, height: 300))

        case .cachedURL(let urlString):
            // For cached tracks, download the artwork from the cached URL
            guard let urlString = urlString, let url = URL(string: urlString) else {
                resetToDefaultColors()
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                artworkImage = UIImage(data: data)
            } catch {
                logger.error("Failed to download cached artwork: \(error.localizedDescription)")
                resetToDefaultColors()
                return
            }
        }

        guard let image = artworkImage else {
            resetToDefaultColors()
            return
        }

        // Extract comprehensive color palette
        if let palette = await ColorExtractor.extractColorPalette(from: image) {
            // Update colors on main actor with animation
            backgroundColor1 = Color(uiColor: palette.backgroundColors.color1)
            backgroundColor2 = Color(uiColor: palette.backgroundColors.color2)

            // Update mesh colors for visualizations (using vibrant colors)
            meshColors = palette.vibrantMeshColors.map { Color(uiColor: $0) }

            // Update background mesh colors (using base mesh colors, darkened)
            backgroundMeshColors = palette.meshColors.map {
                Color(uiColor: $0)
                    .opacity(0.3)
            }
        } else {
            // Fallback to old method if palette extraction fails
            if let colors = await ColorExtractor.extractColors(from: image) {
                backgroundColor1 = Color(uiColor: colors.color1)
                backgroundColor2 = Color(uiColor: colors.color2)
            }
        }
    }

    private func resetToDefaultColors() {
        backgroundColor1 = .purple.opacity(0.3)
        backgroundColor2 = .blue.opacity(0.3)
        meshColors = nil
        backgroundMeshColors = nil
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
