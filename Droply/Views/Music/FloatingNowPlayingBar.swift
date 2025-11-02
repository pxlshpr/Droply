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
        if let song = musicService.currentSong {
            HStack(spacing: 12) {
                // Artwork
                Group {
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
                }
                .frame(width: 50, height: 50)
                .cornerRadius(6)

                // Song info with marquee
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

                // Play/Pause button
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .contentShape(Rectangle())
            .onTapGesture {
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
                    // Try to skip to the next song in the queue
                    try await musicService.skipToNextItem()

                    // Pause immediately to prevent playing from the start
                    try? await musicService.pause()

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

#Preview {
    FloatingNowPlayingBar(onTap: {})
        .padding()
        .modelContainer(for: [MarkedSong.self, SongMarker.self], inMemory: true)
}
