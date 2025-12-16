//
//  RecentlyMarkedView.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/30/25.
//

import SwiftUI
import SwiftData
import MusicKit
import MediaPlayer
import NukeUI
import OSLog

struct RecentlyMarkedView: View {
    let namespace: Namespace.ID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    private let musicService = MusicKitService.shared
    @State private var currentPlayTask: Task<Void, Never>?

    private let playbackErrorLogger = Logger(subsystem: "com.droply.app", category: "PlaybackErrors")

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

    // Group songs by time periods
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

    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic background gradient
                LinearGradient(
                    colors: [musicService.backgroundColor1, musicService.backgroundColor2],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: musicService.backgroundColor1)
                .animation(.easeInOut(duration: 0.8), value: musicService.backgroundColor2)

                Group {
                    if recentlyMarkedSongs.isEmpty {
                        ContentUnavailableView(
                            "No Marked Songs",
                            systemImage: "music.note.list",
                            description: Text("Songs you mark will appear here")
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
                                            // Haptic feedback FIRST for instant tactile response
                                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                                            generator.impactOccurred()

                                            // Extract metadata from SwiftData synchronously (on main thread)
                                            let metadata = TrackMetadataDTO(from: song)

                                            // Set cached metadata instantly (synchronous, no Task delay)
                                            musicService.setTrackMetadataFromCache(metadata)

                                            // Fetch fresh metadata from API in background (non-blocking)
                                            Task {
                                                await musicService.fetchFreshTrackMetadata(metadata)
                                            }

                                            // Cancel any existing play task
                                            currentPlayTask?.cancel()

                                            // Create new play task
                                            currentPlayTask = Task {
                                                await playSong(song)
                                            }
                                        } label: {
                                            RecentlyMarkedRow(song: song)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(SongRowButtonStyle())
                                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .toolbarColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Droply")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundStyle(.white)
                    }
                }

                ToolbarItem(placement: .bottomBar) {
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
                        HStack(spacing: 6) {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                            Text(playMode == .startOfSong ? "Start" : "Drop in")
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                ToolbarSpacer(placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        Task {
                            await playAllSongs()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Play All")
                        }
                        .font(.headline)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(recentlyMarkedSongs.isEmpty)
                }
            }
//            .toolbarBackground(.visible, for: .bottomBar)
        }
    }

    private func playSong(_ markedSong: MarkedSong) async {
        // Dismiss immediately for responsive feel
        dismiss()

        do {
            // Check for cancellation before proceeding
            try Task.checkCancellation()

            // Find the index of the tapped song
            guard let tappedIndex = recentlyMarkedSongs.firstIndex(where: { $0.id == markedSong.id }) else {
                return
            }

            // Create cyclical queue: from tapped song to end, then start to before tapped song
            let songsFromTappedToEnd = Array(recentlyMarkedSongs[tappedIndex...])
            let songsFromStartToBeforeTapped = Array(recentlyMarkedSongs[..<tappedIndex])
            let cyclicalQueue = songsFromTappedToEnd + songsFromStartToBeforeTapped

            // Check for cancellation before fetching songs
            try Task.checkCancellation()

            // Separate Apple Music and local tracks
            var appleMusicSongs: [Song] = []
            var localItems: [ItemToPlay] = []

            for markedSong in cyclicalQueue {
                // Check for cancellation during fetching
                try Task.checkCancellation()

                if markedSong.isAppleMusic {
                    // Fetch from Apple Music
                    let request = MusicCatalogResourceRequest<Song>(
                        matching: \.id,
                        equalTo: MusicItemID(markedSong.appleMusicID)
                    )
                    let response = try await request.response()

                    if let song = response.items.first {
                        appleMusicSongs.append(song)
                    } else {
                        print("Warning: Could not find song '\(markedSong.title)' in Apple Music")
                    }
                } else if markedSong.isLocal {
                    // Create ItemToPlay from local track data
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
                    localItems.append(item)
                }
            }

            // Combine into items for queue manager
            let appleMusicItems = appleMusicSongs.map { ItemToPlay(song: $0) }
            let allItems = appleMusicItems + localItems

            guard !allItems.isEmpty else {
                return
            }

            // Check for cancellation before playing
            try Task.checkCancellation()

            // Play with debouncing - first song plays immediately, rest queued after delay
            try await AppleMusicQueueManager.shared.playWithDebounce(allItems)

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

            // Update last played at for the tapped song
            markedSong.lastPlayedAt = Date()
            try? modelContext.save()
        } catch is CancellationError {
            // Task was cancelled - this is expected when user taps another song quickly
            print("Play song task was cancelled")
        } catch {
            playbackErrorLogger.error("Failed to play song: \(error.localizedDescription)")
        }
    }

    private func playAllSongs() async {
        // Dismiss immediately for responsive feel
        dismiss()

        do {
            // Separate Apple Music and local tracks
            var appleMusicSongs: [Song] = []
            var localItems: [ItemToPlay] = []

            for markedSong in recentlyMarkedSongs {
                if markedSong.isAppleMusic {
                    // Fetch from Apple Music
                    let request = MusicCatalogResourceRequest<Song>(
                        matching: \.id,
                        equalTo: MusicItemID(markedSong.appleMusicID)
                    )
                    let response = try await request.response()

                    if let song = response.items.first {
                        appleMusicSongs.append(song)
                    } else {
                        print("Warning: Could not find song '\(markedSong.title)' in Apple Music")
                    }
                } else if markedSong.isLocal {
                    // Create ItemToPlay from local track data
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
                    localItems.append(item)
                }
            }

            // Combine into items for queue manager
            let appleMusicItems = appleMusicSongs.map { ItemToPlay(song: $0) }
            let allItems = appleMusicItems + localItems

            guard !allItems.isEmpty else {
                return
            }

            // Play with debouncing - first song plays immediately, rest queued after delay
            try await AppleMusicQueueManager.shared.playWithDebounce(allItems)

            // Wait a moment for playback to initialize before seeking
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

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

            // Update last played at for all songs
            for markedSong in recentlyMarkedSongs {
                markedSong.lastPlayedAt = Date()
            }
            try? modelContext.save()
        } catch {
            playbackErrorLogger.error("Failed to play songs: \(error.localizedDescription)")
        }
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
}

struct RecentlyMarkedRow: View {
    let song: MarkedSong
    @State private var localArtwork: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            Group {
                if let artworkURLString = song.artworkURL,
                   let artworkURL = URL(string: artworkURLString) {
                    // Apple Music track - use URL
                    LazyImage(url: artworkURL) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            placeholderArtwork
                        }
                    }
                } else if song.isLocal, let artwork = localArtwork {
                    // Local track - use UIImage
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if song.isLocal {
                    // Local track but artwork not loaded yet
                    placeholderArtwork
                        .task {
                            await loadLocalArtwork()
                        }
                } else {
                    placeholderArtwork
                }
            }
            .frame(width: 44, height: 44)
            .cornerRadius(6)

            // Song info
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Marker timeline visualization
            SongMarkerPreview(song: song)
        }
        .padding(.vertical, 0)
    }

    private var placeholderArtwork: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
    }

    private func loadLocalArtwork() async {
        // Get the persistent ID
        guard let persistentIDString = song.persistentID.isEmpty ? nil : song.persistentID,
              let persistentID = UInt64(persistentIDString) else {
            return
        }

        // Search for the media item
        let query = MPMediaQuery.songs()
        let predicate = MPMediaPropertyPredicate(
            value: persistentID,
            forProperty: MPMediaItemPropertyPersistentID
        )
        query.addFilterPredicate(predicate)

        // Get artwork from the media item
        if let mediaItem = query.items?.first,
           let artwork = mediaItem.artwork {
            localArtwork = artwork.image(at: CGSize(width: 44, height: 44))
        }
    }
}

struct SongMarkerPreview: View {
    let song: MarkedSong
    private let timelineWidth: CGFloat = 80
    private let capsuleHeight: CGFloat = 18

    var body: some View {
        ZStack(alignment: .leading) {
            // Background capsule representing song length
            Capsule()
                .fill(Color(uiColor: .systemGray5))
                .frame(width: timelineWidth, height: capsuleHeight)
                .padding(.horizontal, 1)
                .padding(.vertical, 1)

            // Markers positioned within the capsule
            ForEach(song.sortedMarkers) { marker in
                let position = (marker.timestamp / song.duration) * timelineWidth

                Text(marker.emoji)
                    .font(.system(size: 10))
                    .offset(x: position - 5) // Center the emoji horizontally
            }
        }
        .frame(width: timelineWidth, height: capsuleHeight)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @Namespace private var namespace

        var body: some View {
            RecentlyMarkedView(namespace: namespace)
        }
    }

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: MarkedSong.self, SongMarker.self, configurations: config)

    // Add some sample data
    let song1 = MarkedSong(
        appleMusicID: "123",
        title: "Test Song 1",
        artist: "Test Artist 1",
        duration: 180
    )
    song1.lastMarkedAt = Date()
    container.mainContext.insert(song1)

    let song2 = MarkedSong(
        appleMusicID: "456",
        title: "Test Song 2",
        artist: "Test Artist 2",
        duration: 200
    )
    song2.lastMarkedAt = Date().addingTimeInterval(-3600)
    container.mainContext.insert(song2)

    return PreviewWrapper()
        .modelContainer(container)
}
