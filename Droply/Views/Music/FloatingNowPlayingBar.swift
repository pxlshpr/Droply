//
//  FloatingNowPlayingBar.swift
//  Droply
//
//  Created by Ahmed Khalaf on 11/2/25.
//

import SwiftUI
import SwiftData
import MusicKit

struct FloatingNowPlayingBar: View {
    @ObservedObject private var musicService = MusicKitService.shared
    @AppStorage("defaultCueTime") private var defaultCueTime: Double = 5.0
    @Query private var markedSongs: [MarkedSong]

    let onTap: () -> Void

    private var currentMarkedSong: MarkedSong? {
        guard let song = musicService.currentSong else { return nil }
        return markedSongs.first { $0.appleMusicID == song.id.rawValue }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Artwork - show pulsating gradient when loading, pending song, or current song
            Group {
                if musicService.isLoadingSong {
                    PulsatingGradientView()
                } else if let song = musicService.currentSong ?? musicService.pendingSong {
                    if let artwork = song.artwork {
                        ArtworkImage(artwork, width: 50, height: 50)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Image(systemName: "music.note")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                    }
                } else {
                    // Nothing playing state
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Image(systemName: "music.note.slash")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                }
            }
            .frame(width: 50, height: 50)
            .cornerRadius(6)

            // Song info with marquee or "Nothing Playing"
            if let song = musicService.currentSong ?? musicService.pendingSong {
                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(
                        text: song.title,
                        font: .subheadline.weight(.semibold)
                    )
                    .frame(height: 18)

                    Text(song.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nothing Playing")
                        .font(.subheadline.weight(.semibold))
                        .frame(height: 18)

                    Text("Tap a song to get started")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Play/Pause button - only show when song is loaded
            if musicService.currentSong != nil {
                Button {
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                    Task {
                        try? await musicService.togglePlayPause()
                    }
                } label: {
                    Image(systemName: musicService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                // Next marker button
                Button {
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                    navigateToNextMarker()
                } label: {
                    Image(systemName: "chevron.forward.2")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .opacity(currentMarkedSong?.sortedMarkers.isEmpty == false ? 1 : 0.3)
                .disabled(currentMarkedSong?.sortedMarkers.isEmpty != false)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            // Only allow tapping to view now playing if song is loaded
            if musicService.currentSong != nil {
                onTap()
            }
        }
    }

    // MARK: - Helper Methods

    private func findNextMarker() -> SongMarker? {
        guard let markers = currentMarkedSong?.sortedMarkers else { return nil }
        let currentTime = musicService.playbackTime

        // Find the first marker whose cue start time is after the current time
        return markers.first { ($0.timestamp - defaultCueTime) > currentTime }
    }

    private func navigateToNextMarker() {
        if let marker = findNextMarker() {
            Task {
                let startTime = max(0, marker.timestamp - defaultCueTime)
                await musicService.seek(to: startTime)
                try? await musicService.play()
            }
        } else {
            // No next marker found in current song - try to skip to next song
            Task {
                do {
                    // Pause first to prevent any playback before we're ready
                    try? await musicService.pause()

                    // Try to skip to the next song in the queue
                    try await musicService.skipToNextItem()

                    // Wait for the song to change and playback to initialize
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                    // Check if the new song has markers
                    if let currentSong = musicService.currentSong,
                       let newMarkedSong = markedSongs.first(where: { $0.appleMusicID == currentSong.id.rawValue }),
                       let firstMarker = newMarkedSong.sortedMarkers.first {
                        // Navigate to the first marker of the new song
                        let startTime = max(0, firstMarker.timestamp - defaultCueTime)
                        await musicService.seek(to: startTime)
                        try? await musicService.play()
                    } else {
                        // If no markers, resume playback from the beginning
                        try? await musicService.play()
                    }
                } catch {
                    // If skipping fails (no next song), trigger error haptic
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Pulsating Gradient View

struct PulsatingGradientView: View {
    @State private var animationPhase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(
                LinearGradient(
                    colors: [
                        Color(white: 0.15).opacity(0.8 + animationPhase * 0.2),
                        Color(white: 0.25).opacity(0.8 + animationPhase * 0.2),
                        Color(white: 0.15).opacity(0.8 + animationPhase * 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animationPhase = 1.0
                }
            }
    }
}

#Preview {
    FloatingNowPlayingBar(onTap: {})
        .padding()
        .modelContainer(for: [MarkedSong.self, SongMarker.self], inMemory: true)
}
