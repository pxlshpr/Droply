//
//  RecentlyMarkedView.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/30/25.
//

import SwiftUI
import SwiftData
import MusicKit

struct RecentlyMarkedView: View {
    let namespace: Namespace.ID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var musicService = MusicKitService.shared

    @Query(
        filter: #Predicate<MarkedSong> { song in
            song.lastMarkedAt != nil
        },
        sort: \MarkedSong.lastMarkedAt,
        order: .reverse
    ) private var recentlyMarkedSongs: [MarkedSong]

    @State private var isLoading = false
    @State private var errorMessage: String?
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
                            Section(header: Text(group.period)) {
                                ForEach(group.songs) { song in
                                    RecentlyMarkedRow(song: song)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            Task {
                                                await playSong(song)
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Recently Marked")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundStyle(.primary)
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
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(recentlyMarkedSongs.isEmpty)
                }
            }
//            .toolbarBackground(.visible, for: .bottomBar)
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.2)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func playSong(_ markedSong: MarkedSong) async {
        isLoading = true
        errorMessage = nil

        do {
            // Find the index of the tapped song
            guard let tappedIndex = recentlyMarkedSongs.firstIndex(where: { $0.id == markedSong.id }) else {
                errorMessage = "Could not find song in recently marked list"
                isLoading = false
                return
            }

            // Create cyclical queue: from tapped song to end, then start to before tapped song
            let songsFromTappedToEnd = Array(recentlyMarkedSongs[tappedIndex...])
            let songsFromStartToBeforeTapped = Array(recentlyMarkedSongs[..<tappedIndex])
            let cyclicalQueue = songsFromTappedToEnd + songsFromStartToBeforeTapped

            // Fetch all songs from MusicKit
            var songs: [Song] = []

            for markedSong in cyclicalQueue {
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
                errorMessage = "Could not find any songs in Apple Music"
                isLoading = false
                return
            }

            // Play all songs using the queue manager
            try await musicService.playSongsWithQueueManager(songs)

            // Wait a moment for playback to initialize before seeking
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

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

            // Dismiss the view after starting playback
            dismiss()
        } catch {
            errorMessage = "Failed to play song: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func playAllSongs() async {
        isLoading = true
        errorMessage = nil

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
                    errorMessage = "Could not find song '\(markedSong.title)' in Apple Music"
                }
            }

            guard !songs.isEmpty else {
                errorMessage = "No songs available to play"
                isLoading = false
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

            // Dismiss the view after starting playback
            dismiss()
        } catch {
            errorMessage = "Failed to play songs: \(error.localizedDescription)"
        }

        isLoading = false
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

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artworkURLString = song.artworkURL,
               let artworkURL = URL(string: artworkURLString) {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 44, height: 44)
                .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .frame(width: 44, height: 44)
                    .cornerRadius(6)
            }

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
}

struct SongMarkerPreview: View {
    let song: MarkedSong
    private let timelineWidth: CGFloat = 80
    private let timelineHeight: CGFloat = 2

    var body: some View {
        ZStack(alignment: .leading) {
            // Background timeline
            Rectangle()
                .fill(.tertiary)
                .frame(width: timelineWidth, height: timelineHeight)
                .cornerRadius(1)

            // Markers
            ForEach(song.sortedMarkers) { marker in
                let position = (marker.timestamp / song.duration) * timelineWidth

                Text(marker.emoji)
                    .font(.system(size: 8))
                    .offset(x: position, y: -6)
            }
        }
        .frame(width: timelineWidth, height: 16)
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
