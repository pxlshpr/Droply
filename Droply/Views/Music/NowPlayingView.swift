//
//  NowPlayingView.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/29/25.
//

import SwiftUI
import SwiftData
import MusicKit

struct NowPlayingView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var musicService = MusicKitService.shared
    @State private var markedSong: MarkedSong?
    @State private var showingAddMarker = false
    @State private var selectedMarker: SongMarker?

    @Query private var markedSongs: [MarkedSong]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    if let song = musicService.currentSong {
                        // Album artwork
                        albumArtwork(for: song)

                        // Song info
                        VStack(spacing: 8) {
                            Text(song.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)

                            Text(song.artistName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        // Marker timeline
                        MarkerTimelineView(
                            currentTime: musicService.playbackTime,
                            duration: musicService.playbackDuration,
                            markers: markedSong?.sortedMarkers ?? [],
                            onSeek: { time in
                                Task {
                                    await musicService.seek(to: time)
                                }
                            },
                            onMarkerTap: { marker in
                                selectedMarker = marker
                                Task {
                                    await musicService.seekToMarker(marker)
                                    try? await musicService.play()
                                }
                            }
                        )
                        .frame(height: 120)
                        .padding(.horizontal)

                        // Time labels
                        HStack {
                            Text(formatTime(musicService.playbackTime))
                                .font(.caption)
                                .monospacedDigit()
                            Spacer()
                            Text(formatTime(musicService.playbackDuration))
                                .font(.caption)
                                .monospacedDigit()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 30)

                        // Playback controls
                        HStack(spacing: 40) {
                            Button {
                                Task {
                                    try? await musicService.togglePlayPause()
                                }
                            } label: {
                                Image(systemName: musicService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(.primary)
                            }

                            Button {
                                showingAddMarker = true
                            } label: {
                                Image(systemName: "bookmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.orange)
                            }
                            .disabled(musicService.currentSong == nil)
                        }
                        .padding(.top, 20)

                        // Markers list
                        if let markers = markedSong?.sortedMarkers, !markers.isEmpty {
                            MarkerListView(
                                markers: markers,
                                onTap: { marker in
                                    Task {
                                        await musicService.seekToMarker(marker)
                                        try? await musicService.play()
                                    }
                                },
                                onDelete: { marker in
                                    deleteMarker(marker)
                                }
                            )
                        }

                        Spacer()
                    } else {
                        // No song playing
                        ContentUnavailableView(
                            "No Song Playing",
                            systemImage: "music.note",
                            description: Text("Play a song from Apple Music to get started")
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        musicService.logCurrentState()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddMarker) {
                if let song = musicService.currentSong {
                    AddMarkerView(
                        currentTime: musicService.playbackTime,
                        markedSong: getOrCreateMarkedSong(from: song)
                    )
                }
            }
            .onChange(of: musicService.currentSong) { _, newSong in
                updateMarkedSong(for: newSong)
            }
            .onAppear {
                updateMarkedSong(for: musicService.currentSong)
            }
        }
    }

    // MARK: - Views

    @ViewBuilder
    private func albumArtwork(for song: Song) -> some View {
        if let artwork = song.artwork {
            ArtworkImage(artwork, width: 280, height: 280)
                .cornerRadius(12)
                .shadow(radius: 10)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .frame(width: 280, height: 280)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundStyle(.secondary)
                }
        }
    }

    // MARK: - Helper Methods

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func updateMarkedSong(for song: Song?) {
        guard let song = song else {
            markedSong = nil
            return
        }

        markedSong = markedSongs.first { $0.appleMusicID == song.id.rawValue }
    }

    private func getOrCreateMarkedSong(from song: Song) -> MarkedSong {
        if let existing = markedSongs.first(where: { $0.appleMusicID == song.id.rawValue }) {
            return existing
        }

        let newMarkedSong = MarkedSong(from: song)
        modelContext.insert(newMarkedSong)
        try? modelContext.save()
        return newMarkedSong
    }

    private func deleteMarker(_ marker: SongMarker) {
        modelContext.delete(marker)
        try? modelContext.save()
    }
}

#Preview {
    NowPlayingView()
        .modelContainer(for: [MarkedSong.self, SongMarker.self], inMemory: true)
}
