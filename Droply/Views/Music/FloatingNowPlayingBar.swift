//
//  FloatingNowPlayingBar.swift
//  Droply
//
//  Created by Ahmed Khalaf on 11/2/25.
//

import SwiftUI
import SwiftData
import MusicKit
import MediaPlayer
import NukeUI
import OSLog

struct FloatingNowPlayingBar: View {
    private let musicService = MusicKitService.shared
    @AppStorage("defaultCueTime") private var defaultCueTime: Double = 5.0
    @Query private var markedSongs: [MarkedSong]

    private let logger = Logger(subsystem: "com.droply.app", category: "FloatingNowPlayingBar")

    let onTap: () -> Void

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }

    private var currentMarkedSong: MarkedSong? {
        guard let track = musicService.currentTrack else { return nil }
        if let appleStoreID = track.appleStoreID {
            return markedSongs.first { $0.appleMusicID == appleStoreID }
        } else if let persistentID = track.persistentID {
            return markedSongs.first { $0.persistentID == persistentID }
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            // Artwork - show pulsating gradient when loading, pending track, or current track
            Group {
                if musicService.isLoadingSong {
                    PulsatingGradientView()
                } else if let track = musicService.currentTrack ?? musicService.pendingTrack {
                    switch track.artwork {
                    case .musicKit(let artwork):
                        if let artworkURL = artwork?.url(width: 50, height: 50) {
                            LazyImage(url: artworkURL) { state in
                                if let image = state.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    placeholderArtwork
                                }
                            }
                        } else {
                            placeholderArtwork
                        }
                    case .mediaPlayer(let artwork):
                        if let uiImage = artwork?.image(at: CGSize(width: 50, height: 50)) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            placeholderArtwork
                        }
                    case .cachedURL(let urlString):
                        if let urlString = urlString, let artworkURL = URL(string: urlString) {
                            LazyImage(url: artworkURL) { state in
                                if let image = state.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    placeholderArtwork
                                }
                            }
                        } else {
                            placeholderArtwork
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
            if let track = musicService.currentTrack ?? musicService.pendingTrack {
                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(
                        text: track.title,
                        font: .subheadline.weight(.semibold)
                    )
                    .frame(height: 18)
                    .onAppear {
                        let time = timestamp()
                        if musicService.currentTrack != nil {
                            logger.info("[\(time)] 📺 Displaying CURRENT track: \(track.title) by \(track.artistName)")
                        } else {
                            logger.info("[\(time)] 📺 Displaying PENDING track: \(track.title) by \(track.artistName)")
                        }
                    }
                    .onChange(of: track.id) { oldValue, newValue in
                        let time = timestamp()
                        logger.info("[\(time)] 📺 ✨ UI CHANGE DETECTED - track.id changed from \(oldValue) to \(newValue)")
                        if musicService.currentTrack != nil {
                            logger.info("[\(time)] 📺 Now showing CURRENT track: \(track.title) by \(track.artistName)")
                        } else {
                            logger.info("[\(time)] 📺 Now showing PENDING track: \(track.title) by \(track.artistName)")
                        }
                    }
                    .onChange(of: musicService.pendingTrack?.id) { oldValue, newValue in
                        let time = timestamp()
                        logger.info("[\(time)] 📺 🔔 pendingTrack.id changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
                    }
                    .onChange(of: musicService.currentTrack?.id) { oldValue, newValue in
                        let time = timestamp()
                        logger.info("[\(time)] 📺 🔔 currentTrack.id changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
                    }

                    Text(track.artistName)
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
                        .onAppear {
                            let time = timestamp()
                            logger.debug("[\(time)] 📺 Displaying 'Nothing Playing' - currentTrack: \(musicService.currentTrack == nil ? "nil" : "exists"), pendingTrack: \(musicService.pendingTrack == nil ? "nil" : "exists")")
                        }

                    Text("Tap a song to get started")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Play/Pause button - show when track is loaded or pending
            if musicService.currentTrack != nil || musicService.pendingTrack != nil {
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
            let tapTime = timestamp()
            logger.info("[\(tapTime)] 👆 FloatingNowPlayingBar tapped")

            // Allow tapping when either current track OR pending track exists
            if musicService.currentTrack != nil || musicService.pendingTrack != nil {
                logger.info("[\(tapTime)] ✅ Track exists (current or pending), calling onTap()")
                onTap()
                let afterTapTime = timestamp()
                logger.info("[\(afterTapTime)] 📲 onTap() completed")
            } else {
                logger.debug("[\(tapTime)] ⚠️ No track (current or pending), tap ignored")
            }
        }
    }

    // MARK: - Helper Methods

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.ultraThinMaterial)
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
    }

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
                    if let currentTrack = musicService.currentTrack,
                       let id = currentTrack.appleStoreID ?? currentTrack.persistentID,
                       let newMarkedSong = markedSongs.first(where: { $0.appleMusicID == id || $0.persistentID == id }),
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
