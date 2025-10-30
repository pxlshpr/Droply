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
                    VStack(spacing: 0) {
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

                        // Segmented control for play mode
                        VStack(spacing: 8) {
                            Picker("Play Mode", selection: $playMode) {
                                Text("Start").tag(PlayMode.startOfSong)
                                Text("Cue at First Marker").tag(PlayMode.cueAtFirstMarker)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .navigationTitle("Recently Marked")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            await playAllSongs()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.caption)
                            Text("Play All")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.primary)
                    }
                    .disabled(recentlyMarkedSongs.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
            }
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
            // Fetch the song from MusicKit using the Apple Music ID
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(markedSong.appleMusicID)
            )
            let response = try await request.response()

            guard let song = response.items.first else {
                errorMessage = "Could not find song in Apple Music"
                isLoading = false
                return
            }

            // Prepend the song to the system queue and start playing
            try await musicService.prependSongToSystemQueue(song)

            // Handle play mode - seek after starting playback
            switch playMode {
            case .startOfSong:
                // Already playing from beginning
                break
            case .cueAtFirstMarker:
                // Seek to first marker if available
                if let firstMarker = markedSong.sortedMarkers.first {
                    let startTime = max(0, firstMarker.timestamp - (firstMarker.cueTime))
                    await musicService.seek(to: startTime)
                }
            }

            // Update last played at
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

            // Prepend all songs to the system queue and start playing
            try await musicService.prependSongsToSystemQueue(songs)

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
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            }

            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(nil)

                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
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

    return RecentlyMarkedView()
        .modelContainer(container)
}
