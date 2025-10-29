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

            VStack(spacing: 0) {
                    if let song = musicService.currentSong {
                        Spacer()

                        // Album artwork
                        albumArtwork(for: song)
                            .padding(.bottom, 16)

                        // Song info
                        VStack(spacing: 4) {
                            Text(song.title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(song.artistName)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)

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
                        .frame(height: 100)
                        .padding(.horizontal)
                        .padding(.bottom, 8)

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
                        .padding(.bottom, 16)

                        // Playback controls
                        HStack(spacing: 40) {
                            // Previous button
                            Button {
                                Task {
                                    try? await musicService.skipToPreviousItem()
                                }
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white)
                            }

                            // Play/Pause button
                            Button {
                                Task {
                                    try? await musicService.togglePlayPause()
                                }
                            } label: {
                                Image(systemName: musicService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 56))
                                    .foregroundStyle(.white)
                            }

                            // Next button
                            Button {
                                Task {
                                    try? await musicService.skipToNextItem()
                                }
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.bottom, 12)

                        // Markers strip
                        if let markers = markedSong?.sortedMarkers, !markers.isEmpty {
                            HorizontalMarkerStrip(
                                markers: markers,
                                onTap: { marker in
                                    Task {
                                        await musicService.seekToMarker(marker)
                                        try? await musicService.play()
                                    }
                                }
                            )
                            .padding(.bottom, 8)
                        }

                        // Add marker button
                        Button {
                            showingAddMarker = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "bookmark.fill")
                                Text("Add Marker")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.2))
                            .cornerRadius(20)
                        }
                        .disabled(musicService.currentSong == nil)

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

    // MARK: - Views

    @ViewBuilder
    private func albumArtwork(for song: Song) -> some View {
        if let artwork = song.artwork {
            ArtworkImage(artwork, width: 240, height: 240)
                .cornerRadius(12)
                .shadow(radius: 10)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .frame(width: 240, height: 240)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 70))
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
