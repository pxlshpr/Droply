//
//  ContentView.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/29/25.
//

import SwiftUI
import SwiftData
import MusicKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var musicService = MusicKitService.shared
    @State private var showingAuthorization = false
    @State private var showingNowPlaying = false
    @State private var currentPlayTask: Task<Void, Never>?

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
    }

    private var mainView: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
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
                                Section(header: Text(group.period)) {
                                    ForEach(group.songs) { song in
                                        RecentlyMarkedRow(song: song)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                // Cancel any existing play task
                                                currentPlayTask?.cancel()

                                                // Create new play task
                                                currentPlayTask = Task {
                                                    await playSong(song)
                                                }
                                            }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
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
                        showingNowPlaying = true
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
                    Button {
                        Task {
                            await playAllSongs()
                        }
                    } label: {
                        Label("Play All", systemImage: "play.fill")
                    }
                    .disabled(recentlyMarkedSongs.isEmpty)
                }
            }
            .sheet(isPresented: $showingNowPlaying) {
                NowPlayingView()
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
            print("Failed to play songs: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Properties

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

            // Fetch all songs from MusicKit
            var songs: [Song] = []

            for markedSong in cyclicalQueue {
                // Check for cancellation during fetching
                try Task.checkCancellation()

                let request = MusicCatalogResourceRequest<Song>(
                    matching: \.id,
                    equalTo: MusicItemID(markedSong.appleMusicID)
                )
                let response = try await request.response()

                if let song = response.items.first {
                    songs.append(song)
                } else {
                    // Log warning but continue with other songs
                    print("Warning: Could not find song '\(markedSong.title)' in Apple Music")
                }
            }

            guard !songs.isEmpty else {
                return
            }

            // Check for cancellation before playing
            try Task.checkCancellation()

            // Play all songs using the queue manager
            try await musicService.playSongsWithQueueManager(songs)

            // Wait a moment for playback to initialize before seeking
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

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
            print("Failed to play song: \(error.localizedDescription)")
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
