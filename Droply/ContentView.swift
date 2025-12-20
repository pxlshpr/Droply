//
//  ContentView.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/29/25.
//

import SwiftUI
import SwiftData
import MusicKit
import MediaPlayer
import OSLog

// Button style that highlights on press
struct SongRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Rectangle()
                    .fill(.white.opacity(configuration.isPressed ? 0.2 : 0))
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    private let musicService = MusicKitService.shared
    @State private var showingAuthorization = false
    @State private var showingNowPlaying = false
    @State private var currentPlayTask: Task<Void, Never>?
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showingOnboarding = false
    @State private var showingSettings = false

    private let logger = Logger(subsystem: "com.droply.app", category: "ContentView")
    private let playbackErrorLogger = Logger(subsystem: "com.droply.app", category: "PlaybackErrors")

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }

    @Query(
        filter: #Predicate<MarkedSong> { song in
            song.lastMarkedAt != nil
        },
        sort: \MarkedSong.lastMarkedAt,
        order: .reverse
    ) private var recentlyMarkedSongs: [MarkedSong]

    @AppStorage("recentlyMarkedPlayMode") private var playMode: PlayMode = .cueAtFirstMarker

    enum PlayMode: String {
        case startOfSong = "Start of Song"
        case cueAtFirstMarker = "Cue at First Marker"
    }

    var body: some View {
        Group {
            switch musicService.authorizationStatus {
            case .authorized:
                mainView
            case .denied, .restricted:
                authorizationDeniedView
            case .notDetermined:
                authorizationRequestView
            @unknown default:
                authorizationRequestView
            }
        }
        .task {
            await musicService.updateAuthorizationStatus()
        }
        .onAppear {
            if !hasSeenOnboarding {
                showingOnboarding = true
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
        }
    }

    private var mainView: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Gradient background for dark mode (using Material Design recommended colors)
                LinearGradient(
                    colors: [
                        Color(hex: "#1a1a1a"),
                        Color(hex: "#121212")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Main content - Recently marked songs list
                Group {
                    if recentlyMarkedSongs.isEmpty {
                        ContentUnavailableView(
                            "No Marked Songs",
                            systemImage: "music.note.list",
                            description: Text("Play a song and add markers to get started")
                        )
                    } else {
                        List {
                            ForEach(groupedSongs, id: \.period) { group in
                                Section(header:
                                    Text(group.period)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                        .padding(.top, 8)
                                        .padding(.bottom, 4)
                                ) {
                                    ForEach(group.songs) { song in
                                        Button {
                                            let tapTime = timestamp()
                                            logger.info("[\(tapTime)] 🎯 Song tapped: \(song.title) by \(song.artist)")

                                            // Haptic feedback FIRST for instant tactile response
                                            let hapticTime = timestamp()
                                            logger.debug("[\(hapticTime)] 📳 Triggering haptic feedback...")
                                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                                            generator.impactOccurred()

                                            // Extract metadata from SwiftData synchronously (on main thread)
                                            let extractTime = timestamp()
                                            logger.debug("[\(extractTime)] 📦 Extracting metadata from SwiftData...")
                                            let metadata = TrackMetadataDTO(from: song)
                                            let extractedTime = timestamp()
                                            logger.debug("[\(extractedTime)] 📦 Metadata extracted")

                                            // Set cached metadata instantly (synchronous, no Task delay)
                                            let setCacheTime = timestamp()
                                            logger.debug("[\(setCacheTime)] 💾 Setting cached metadata...")
                                            musicService.setTrackMetadataFromCache(metadata)
                                            let cacheSetTime = timestamp()
                                            logger.info("[\(cacheSetTime)] ✅ Cached metadata set instantly!")

                                            // Present now playing view immediately BEFORE doing background work
                                            showingNowPlaying = true

                                            // Now do all the background work AFTER sheet is presented
                                            Task {
                                                // Small delay to ensure sheet has appeared
                                                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds

                                                // Fetch fresh metadata from API in background (non-blocking)
                                                let preTaskTime = timestamp()
                                                logger.debug("[\(preTaskTime)] 🔄 Fetching fresh metadata after sheet appeared...")
                                                await musicService.fetchFreshTrackMetadata(metadata)
                                                let taskEndTime = timestamp()
                                                logger.info("[\(taskEndTime)] ✅ Fresh metadata fetch completed")

                                                // Cancel any existing play task
                                                currentPlayTask?.cancel()

                                                // Create new play task - DETACHED to run off main thread
                                                let preDetachedTime = timestamp()
                                                logger.debug("[\(preDetachedTime)] 🚀 Creating detached task for playSong")
                                                currentPlayTask = Task.detached(priority: .userInitiated) {
                                                    await playSong(song)
                                                }
                                                let postDetachedTime = timestamp()
                                                logger.info("[\(postDetachedTime)] ✅ Detached task created")
                                            }
                                        } label: {
                                            RecentlyMarkedRow(song: song)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(SongRowButtonStyle())
                                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                        .listRowBackground(Color.clear)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .safeAreaInset(edge: .bottom) {
                            // Add padding for the floating bar (always visible)
                            Color.clear.frame(height: 80)
                        }
                    }
                }

                // Floating now playing bar (always visible)
                VStack {
                    Spacer()
                    FloatingNowPlayingBar {
                        let time = timestamp()
                        logger.info("[\(time)] 🎭 FloatingNowPlayingBar onTap closure called")
                        showingNowPlaying = true
                        let afterTime = timestamp()
                        logger.info("[\(afterTime)] 🎭 showingNowPlaying set to true")
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Droply")
                        .font(.system(size: 32, weight: .black).width(.condensed))
                }

                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            playMode = .startOfSong
                        } label: {
                            Label("Start", systemImage: playMode == .startOfSong ? "checkmark" : "")
                        }

                        Button {
                            playMode = .cueAtFirstMarker
                        } label: {
                            Label("Drop in at Marker", systemImage: playMode == .cueAtFirstMarker ? "checkmark" : "")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            // Use detached task to run off main thread and avoid UI blocking
                            Task.detached(priority: .userInitiated) {
                                await playAllSongs()
                            }
                        } label: {
                            Label("Play All", systemImage: "play.fill")
                        }
                        .disabled(recentlyMarkedSongs.isEmpty)

                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNowPlaying) {
                nowPlayingSheet
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Playback Methods

    private func playAllSongs() async {
        do {
            // Fetch all songs from MusicKit
            var songs: [Song] = []

            for markedSong in recentlyMarkedSongs {
                let request = MusicCatalogResourceRequest<Song>(
                    matching: \.id,
                    equalTo: MusicItemID(markedSong.appleMusicID)
                )
                let response = try await request.response()

                if let song = response.items.first {
                    songs.append(song)
                } else {
                    print("Warning: Could not find song '\(markedSong.title)' in Apple Music")
                }
            }

            guard !songs.isEmpty else {
                return
            }

            // Play all songs using the queue manager
            try await musicService.playSongsWithQueueManager(songs)

            // Brief wait for playback to stabilize before seeking (reduced from 0.5s to 0.1s for better UX)
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Handle play mode for the first song - seek after starting playback
            switch playMode {
            case .startOfSong:
                // Already playing from beginning of first song
                break
            case .cueAtFirstMarker:
                // Seek to first marker of the first song if available
                if let firstMarker = recentlyMarkedSongs.first?.sortedMarkers.first {
                    let startTime = max(0, firstMarker.timestamp - (firstMarker.cueTime))
                    await musicService.seek(to: startTime)
                }
            }

            // Update last played at for all songs (must run on main thread for SwiftData)
            await MainActor.run {
                for markedSong in recentlyMarkedSongs {
                    markedSong.lastPlayedAt = Date()
                }
                try? modelContext.save()
            }
        } catch {
            print("Failed to play songs: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Properties

    private var nowPlayingSheet: some View {
        let sheetTime = timestamp()
        logger.info("[\(sheetTime)] 📄 Sheet presentation triggered, creating NowPlayingView")
        return NowPlayingView()
            .onAppear {
                let appearTime = timestamp()
                logger.info("[\(appearTime)] 👁️ NowPlayingView appeared on screen")
            }
    }

    private var groupedSongs: [(period: String, songs: [MarkedSong])] {
        let now = Date()
        var groups: [String: [MarkedSong]] = [:]

        for song in recentlyMarkedSongs {
            guard let lastMarkedAt = song.lastMarkedAt else { continue }
            let period = timePeriod(for: lastMarkedAt, relativeTo: now)
            groups[period, default: []].append(song)
        }

        let periodOrder = ["Last Hour", "Last Day", "Last Week", "Last Month",
                          "2 Months Ago", "3 Months Ago", "4 Months Ago", "5 Months Ago",
                          "6 Months Ago", "7 Months Ago", "8 Months Ago", "9 Months Ago",
                          "10 Months Ago", "11 Months Ago", "Over a Year Ago"]

        return periodOrder.compactMap { period in
            guard let songs = groups[period], !songs.isEmpty else { return nil }
            return (period: period, songs: songs)
        }
    }

    // MARK: - Helper Methods

    private func playSong(_ markedSong: MarkedSong) async {
        do {
            // Check for cancellation before proceeding
            try Task.checkCancellation()

            print("🎵 Starting to play song: \(markedSong.title)")

            // Find the index of the tapped song
            guard let tappedIndex = recentlyMarkedSongs.firstIndex(where: { $0.id == markedSong.id }) else {
                print("❌ Could not find song in list")
                return
            }

            // Create cyclical queue: from tapped song to end, then start to before tapped song
            let songsFromTappedToEnd = Array(recentlyMarkedSongs[tappedIndex...])
            let songsFromStartToBeforeTapped = Array(recentlyMarkedSongs[..<tappedIndex])
            let cyclicalQueue = songsFromTappedToEnd + songsFromStartToBeforeTapped

            // Check for cancellation before fetching songs
            try Task.checkCancellation()

            print("🔍 Processing \(cyclicalQueue.count) songs (Apple Music + Local)...")

            // Separate Apple Music and local tracks
            var items: [ItemToPlay] = []

            for markedSong in cyclicalQueue {
                // Check for cancellation during fetching
                try Task.checkCancellation()

                if markedSong.isAppleMusic {
                    // Fetch from Apple Music catalog
                    let request = MusicCatalogResourceRequest<Song>(
                        matching: \.id,
                        equalTo: MusicItemID(markedSong.appleMusicID)
                    )
                    let response = try await request.response()

                    if let song = response.items.first {
                        let item = ItemToPlay(song: song)
                        items.append(item)
                        print("✅ Found Apple Music track: \(markedSong.title)")
                    } else {
                        print("⚠️ Warning: Could not find Apple Music track '\(markedSong.title)'")
                    }
                } else if markedSong.isLocal {
                    // Look up local track by persistent ID to verify it exists
                    if await findLocalTrack(persistentID: markedSong.persistentID, title: markedSong.title, artist: markedSong.artist, duration: markedSong.duration) != nil {
                        let item = ItemToPlay(
                            id: markedSong.persistentID,
                            isPlayable: true,
                            appleStoreID: nil,
                            applePersistentID: markedSong.persistentID,
                            title: markedSong.title,
                            artist: markedSong.artist,
                            durationInSeconds: markedSong.duration,
                            isrc: nil
                        )
                        items.append(item)
                        print("✅ Found local track: \(markedSong.title)")
                    } else {
                        print("⚠️ Warning: Could not find local track '\(markedSong.title)'")
                    }
                }
            }

            guard !items.isEmpty else {
                print("❌ No songs found to play")
                playbackErrorLogger.error("Could not find '\(markedSong.title)' by \(markedSong.artist). Please check your library and Apple Music subscription.")
                return
            }

            print("✅ Found \(items.count) items, now playing...")

            // Check for cancellation before playing
            try Task.checkCancellation()

            // Play with debouncing - first song plays immediately, rest queued after delay
            try await AppleMusicQueueManager.shared.playWithDebounce(items)

            print("🎵 Playback started successfully")

            // Brief wait for playback to stabilize before seeking (reduced from 0.5s to 0.1s for better UX)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Handle play mode for the first song (the tapped song) - seek after starting playback
            switch playMode {
            case .startOfSong:
                // Already playing from beginning
                break
            case .cueAtFirstMarker:
                // Seek to first marker of the tapped song if available
                if let firstMarker = markedSong.sortedMarkers.first {
                    let startTime = max(0, firstMarker.timestamp - (firstMarker.cueTime))
                    await musicService.seek(to: startTime)
                }
            }

            // Update last played at for the tapped song (must run on main thread for SwiftData)
            await MainActor.run {
                markedSong.lastPlayedAt = Date()
                try? modelContext.save()
            }
        } catch is CancellationError {
            // Task was cancelled - this is expected when user taps another song quickly
            print("⏸️ Play song task was cancelled")
        } catch {
            print("❌ Failed to play song: \(error.localizedDescription)")
            playbackErrorLogger.error("Failed to play '\(markedSong.title)' by \(markedSong.artist): \(error.localizedDescription)")
        }
    }

    /// Find a local track in the library by persistent ID or metadata
    private func findLocalTrack(persistentID: String, title: String, artist: String, duration: TimeInterval) async -> MPMediaItem? {
        // Try by persistent ID first
        if let id = UInt64(persistentID) {
            let query = MPMediaQuery.songs()
            let predicate = MPMediaPropertyPredicate(
                value: id,
                forProperty: MPMediaItemPropertyPersistentID
            )
            query.addFilterPredicate(predicate)

            if let mediaItem = query.items?.first {
                print("📍 Found track by persistent ID: \(persistentID)")
                return mediaItem
            }
        }

        // Fallback: search by title and artist
        let titlePredicate = MPMediaPropertyPredicate(
            value: title,
            forProperty: MPMediaItemPropertyTitle,
            comparisonType: .equalTo
        )
        let artistPredicate = MPMediaPropertyPredicate(
            value: artist,
            forProperty: MPMediaItemPropertyArtist,
            comparisonType: .equalTo
        )

        let query = MPMediaQuery.songs()
        query.addFilterPredicate(titlePredicate)
        query.addFilterPredicate(artistPredicate)

        if let items = query.items, !items.isEmpty {
            // If multiple matches, try to match by duration
            if items.count > 1 {
                let matches = items.filter { abs($0.playbackDuration - duration) < 1.0 }
                if let match = matches.first {
                    print("📍 Found track by title/artist/duration")
                    return match
                }
            }

            // Return first match
            print("📍 Found track by title/artist")
            return items.first
        }

        print("❌ Track not found in library")
        return nil
    }

    private func timePeriod(for date: Date, relativeTo now: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .day, .month], from: date, to: now)

        if let hours = components.hour, hours < 1 {
            return "Last Hour"
        } else if let days = components.day, days < 1 {
            return "Last Day"
        } else if let days = components.day, days < 7 {
            return "Last Week"
        } else if let months = components.month {
            if months < 1 {
                return "Last Month"
            } else if months < 12 {
                return "\(months + 1) Months Ago"
            } else {
                return "Over a Year Ago"
            }
        }

        return "Over a Year Ago"
    }

    private var authorizationRequestView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Welcome to Droply")
                .font(.title)
                .fontWeight(.bold)

            Text("Mark your favorite moments in songs and cue them up instantly")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task {
                    let authorized = await musicService.requestAuthorization()
                    if !authorized {
                        showingAuthorization = true
                    }
                }
            } label: {
                Text("Connect to Apple Music")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .padding()
    }

    private var authorizationDeniedView: some View {
        ContentUnavailableView(
            "Apple Music Access Required",
            systemImage: "music.note.list",
            description: Text("Please enable Apple Music access in Settings to use this app")
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [MarkedSong.self, SongMarker.self], inMemory: true)
}
