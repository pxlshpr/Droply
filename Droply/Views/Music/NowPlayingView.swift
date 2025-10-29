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
    @State private var backgroundColor1: Color = .purple.opacity(0.3)
    @State private var backgroundColor2: Color = .blue.opacity(0.3)

    @Query private var markedSongs: [MarkedSong]

    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic background gradient from artwork colors
                LinearGradient(
                    colors: [backgroundColor1, backgroundColor2],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: backgroundColor1)
                .animation(.easeInOut(duration: 0.8), value: backgroundColor2)

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
                                .foregroundStyle(.white)

                            Text(song.artistName)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.horizontal)

                        // Marker timeline
                        MarkerTimelineView(
                            currentTime: musicService.playbackTime,
                            duration: musicService.playbackDuration,
                            markers: markedSong?.sortedMarkers ?? [],
                            musicService: musicService,
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
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 30)

                        // Playback controls
                        HStack(spacing: 40) {
                            // Previous button
                            Button {
                                Task {
                                    try? await musicService.skipToPreviousItem()
                                }
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white)
                            }

                            // Play/Pause button
                            Button {
                                Task {
                                    try? await musicService.togglePlayPause()
                                }
                            } label: {
                                Image(systemName: musicService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(.white)
                            }

                            // Next button
                            Button {
                                Task {
                                    try? await musicService.skipToNextItem()
                                }
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.top, 20)

                        // Add marker button
                        Button {
                            showingAddMarker = true
                        } label: {
                            HStack {
                                Image(systemName: "bookmark.fill")
                                Text("Add Marker")
                            }
                            .font(.callout)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.2))
                            .cornerRadius(20)
                        }
                        .disabled(musicService.currentSong == nil)

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
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(backgroundColor1.opacity(0.7), for: .navigationBar)
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
                extractColorsFromArtwork(for: newSong)
            }
            .onAppear {
                updateMarkedSong(for: musicService.currentSong)
                extractColorsFromArtwork(for: musicService.currentSong)
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

    private func extractColorsFromArtwork(for song: Song?) {
        guard let song = song,
              let artwork = song.artwork,
              let url = artwork.url(width: 300, height: 300) else {
            // Reset to default colors if no artwork
            withAnimation(.easeInOut(duration: 0.8)) {
                backgroundColor1 = .purple.opacity(0.3)
                backgroundColor2 = .blue.opacity(0.3)
            }
            return
        }

        Task {
            do {
                // Download the artwork image
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return }

                // Extract colors
                if let colors = await ColorExtractor.extractColors(from: image) {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            backgroundColor1 = Color(uiColor: colors.color1)
                            backgroundColor2 = Color(uiColor: colors.color2)
                        }
                    }
                }
            } catch {
                // If extraction fails, keep current colors
                print("Failed to extract colors from artwork: \(error)")
            }
        }
    }
}

#Preview {
    NowPlayingView()
        .modelContainer(for: [MarkedSong.self, SongMarker.self], inMemory: true)
}
