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
    @AppStorage("defaultBufferTime") private var defaultBufferTime: Double = 5.0

    @Query private var markedSongs: [MarkedSong]

    private let bufferOptions: [Double] = [0, 5, 10, 15, 30, 45, 60, 90, 120]

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
                    if musicService.isCheckingPlayback {
                        // Checking for playback
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(1.2)

                            Text("Checking for playback...")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    } else if let song = musicService.currentSong {
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
                                    let startTime = max(0, marker.timestamp - defaultBufferTime)
                                    await musicService.seek(to: startTime)
                                    try? await musicService.play()
                                }
                            }
                        )
                        .frame(height: 100)
                        .padding(.horizontal)
                        .padding(.bottom, 4)

                        // Time labels
                        VStack(spacing: 8) {
                            Text(formatTime(musicService.playbackTime))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())

                            Text(formatTime(musicService.playbackDuration))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.bottom, 8)

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
                            .buttonStyle(.plain)

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
                            .buttonStyle(.plain)

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
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 12)

                        // Markers strip (always visible)
                        HorizontalMarkerStrip(
                            markers: markedSong?.sortedMarkers ?? [],
                            onTap: { marker in
                                Task {
                                    let startTime = max(0, marker.timestamp - defaultBufferTime)
                                    await musicService.seek(to: startTime)
                                    try? await musicService.play()
                                }
                            },
                            onAddMarker: {
                                showingAddMarker = true
                            }
                        )
                        .padding(.bottom, 8)

                        // Buffer selector
                        VStack(spacing: 8) {
                            Text("Buffer Time")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))

                            bufferSelector
                        }
                        .padding(.bottom, 12)

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
            ArtworkImage(artwork, width: 320, height: 320)
                .cornerRadius(12)
                .shadow(radius: 10)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .frame(width: 320, height: 320)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 90))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var bufferSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(bufferOptions, id: \.self) { buffer in
                    Button {
                        defaultBufferTime = buffer
                    } label: {
                        Text(formatBufferTime(buffer))
                            .font(.subheadline)
                            .fontWeight(defaultBufferTime == buffer ? .bold : .medium)
                            .foregroundStyle(defaultBufferTime == buffer ? .black : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(defaultBufferTime == buffer ? .white : .white.opacity(0.2))
                            .cornerRadius(16)
                            .scaleEffect(defaultBufferTime == buffer ? 1.05 : 1.0)
                            .shadow(color: defaultBufferTime == buffer ? .white.opacity(0.3) : .clear, radius: 8)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: defaultBufferTime)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Helper Methods

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatBufferTime(_ seconds: Double) -> String {
        if seconds == 0 {
            return "0s"
        } else if seconds < 60 {
            return "\(Int(seconds))s"
        } else {
            let minutes = Int(seconds / 60)
            return "\(minutes)m"
        }
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
