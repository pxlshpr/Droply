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
                        ForEach(recentlyMarkedSongs) { song in
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
            .navigationTitle("Recently Marked")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
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

            // Play the song
            try await musicService.playSong(song)

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
                    .lineLimit(1)

                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let lastMarkedAt = song.lastMarkedAt {
                    Text(formatRelativeDate(lastMarkedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Marker count badge
            if let markerCount = song.markers?.count, markerCount > 0 {
                Text("\(markerCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(12)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
