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
    @State private var showingEditMarker = false
    @State private var showingRecentlyMarked = false
    @State private var recentlyMarkedDetent: PresentationDetent = .medium
    @State private var markerToEdit: SongMarker?
    @State private var selectedMarker: SongMarker?
    @State private var backgroundColor1: Color = .purple.opacity(0.3)
    @State private var backgroundColor2: Color = .blue.opacity(0.3)
    @AppStorage("defaultCueTime") private var defaultCueTime: Double = 5.0

    @Query private var markedSongs: [MarkedSong]

    private let cueTimeOptions: [Double] = [0, 5, 10, 15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
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
                    .padding(.horizontal)
                } else if let song = musicService.currentSong {
                    // Calculate available space accounting for safe areas
                    let bottomSafeArea = max(geometry.safeAreaInsets.bottom, 20) // Minimum 20pt padding
                    let availableHeight = geometry.size.height - bottomSafeArea
                    let availableWidth = geometry.size.width

                    // Calculate sizes - maximize artwork while fitting width
                    let maxArtworkFromWidth = availableWidth - 32 // Account for horizontal padding
                    let maxArtworkFromHeight = availableHeight * 0.45 // Use 45% of height
                    let artworkSize = min(maxArtworkFromWidth, maxArtworkFromHeight)

                    let timelineHeight: CGFloat = 80
                    let timeFontSize: CGFloat = 40

                    // Calculate control button sizes based on available width
                    // 5 buttons + 4 spacers + 48pt horizontal padding (24pt each side)
                    let horizontalPadding: CGFloat = 48
                    let spacing: CGFloat = 20
                    let totalSpacing = spacing * 4 // 4 spacers between 5 buttons
                    let availableForButtons = availableWidth - horizontalPadding - totalSpacing

                    // Allocate button space: marker buttons get smaller portion, main buttons larger
                    // Total "units": 2 marker (0.45 each) + 2 track (0.67 each) + 1 play (1.0) = 3.24 units
                    let markerButtonUnit = availableForButtons / (2 * 0.45 + 2 * 0.67 + 1.0)

                    let controlButtonSize: CGFloat = min(48, markerButtonUnit * 0.67)
                    let playButtonSize: CGFloat = min(60, markerButtonUnit * 1.0)

                    VStack(spacing: 0) {
                        // Album artwork
                        albumArtwork(for: song)
                            .frame(width: artworkSize, height: artworkSize)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)

                        // Song info
                        VStack(spacing: 2) {
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
                                    let startTime = max(0, marker.timestamp - defaultCueTime)
                                    await musicService.seek(to: startTime)
                                    try? await musicService.play()
                                }
                            },
                            onMarkerEdit: { marker in
                                markerToEdit = marker
                                showingEditMarker = true
                            },
                            onMarkerDelete: { marker in
                                deleteMarker(marker)
                            }
                        )
                        .frame(height: timelineHeight)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)

                        // Time labels
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text(formatTime(musicService.playbackTime))
                                .font(.system(size: timeFontSize, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())

                            Text("/")
                                .font(.system(size: timeFontSize * 0.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))

                            Text(formatTime(musicService.playbackDuration))
                                .font(.system(size: timeFontSize * 0.5, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                        // Playback controls
                        HStack(spacing: 20) {
                            // Previous marker button
                            Button {
                                navigateToPreviousMarker()
                            } label: {
                                Image(systemName: "chevron.backward.2")
                                    .font(.system(size: controlButtonSize * 0.45))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            // Previous track button
                            Button {
                                Task {
                                    try? await musicService.skipToPreviousItem()
                                }
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: controlButtonSize * 0.67))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            // Play/Pause button
                            Button {
                                Task {
                                    try? await musicService.togglePlayPause()
                                }
                            } label: {
                                Image(systemName: musicService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: playButtonSize))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            // Next track button
                            Button {
                                Task {
                                    try? await musicService.skipToNextItem()
                                }
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: controlButtonSize * 0.67))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            // Next marker button
                            Button {
                                navigateToNextMarker()
                            } label: {
                                Image(systemName: "chevron.forward.2")
                                    .font(.system(size: controlButtonSize * 0.45))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                        // Markers strip
                        HorizontalMarkerStrip(
                            markers: markedSong?.sortedMarkers ?? [],
                            onTap: { marker in
                                Task {
                                    let startTime = max(0, marker.timestamp - defaultCueTime)
                                    await musicService.seek(to: startTime)
                                    try? await musicService.play()
                                }
                            },
                            onAddMarker: {
                                showingAddMarker = true
                            },
                            onMarkerEdit: { marker in
                                markerToEdit = marker
                                showingEditMarker = true
                            },
                            onMarkerDelete: { marker in
                                deleteMarker(marker)
                            }
                        )
                        .padding(.bottom, 12)
                        .frame(maxWidth: availableWidth)

                        // Cue time selector
                        VStack(spacing: 6) {
                            Text("Cue Time")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal)

                            cueTimeSelector
                                .frame(maxWidth: availableWidth)
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(maxWidth: availableWidth, alignment: .center)
                    .padding(.bottom, bottomSafeArea + 8)
                } else {
                    // No song playing
                    ContentUnavailableView(
                        "No Song Playing",
                        systemImage: "music.note",
                        description: Text("Play a song from Apple Music to get started")
                    )
                    .padding(.horizontal)
                }
                }
            }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            showingRecentlyMarked = true
                        } label: {
                            Label("Recently Marked", systemImage: "clock.arrow.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.white)
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
            .sheet(isPresented: $showingEditMarker) {
                if let marker = markerToEdit {
                    EditMarkerView(marker: marker)
                }
            }
            .sheet(isPresented: $showingRecentlyMarked) {
                RecentlyMarkedView()
                    .presentationDetents([.medium, .large], selection: $recentlyMarkedDetent)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .presentationBackground(.ultraThinMaterial)
            }
            .onChange(of: musicService.currentSong) { _, newSong in
                updateMarkedSong(for: newSong)
                extractColorsFromArtwork(for: newSong)
            }
            .onAppear {
                migrateLegacySongs()
                updateMarkedSong(for: musicService.currentSong)
                extractColorsFromArtwork(for: musicService.currentSong)
            }
        }
    }

    // MARK: - Views

    @ViewBuilder
    private func albumArtwork(for song: Song) -> some View {
        GeometryReader { geo in
            if let artwork = song.artwork {
                ArtworkImage(artwork, width: geo.size.width, height: geo.size.height)
                    .cornerRadius(12)
                    .shadow(radius: 10)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: geo.size.width * 0.28))
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private var cueTimeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(cueTimeOptions, id: \.self) { cueTime in
                    Button {
                        defaultCueTime = cueTime
                    } label: {
                        Text(formatCueTime(cueTime))
                            .font(.subheadline)
                            .fontWeight(defaultCueTime == cueTime ? .bold : .medium)
                            .foregroundStyle(defaultCueTime == cueTime ? .black : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(defaultCueTime == cueTime ? .white : .white.opacity(0.2))
                            .cornerRadius(16)
                            .scaleEffect(defaultCueTime == cueTime ? 1.05 : 1.0)
                            .shadow(color: defaultCueTime == cueTime ? .white.opacity(0.3) : .clear, radius: 8)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: defaultCueTime)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Helper Methods

    private func findPreviousMarker() -> SongMarker? {
        guard let markers = markedSong?.sortedMarkers else { return nil }
        let currentTime = musicService.playbackTime

        // Find the last marker that is before the current time
        return markers.last { $0.timestamp < currentTime }
    }

    private func findNextMarker() -> SongMarker? {
        guard let markers = markedSong?.sortedMarkers else { return nil }
        let currentTime = musicService.playbackTime

        // Find the first marker that is after the current time
        return markers.first { $0.timestamp > currentTime }
    }

    private func navigateToPreviousMarker() {
        if let marker = findPreviousMarker() {
            Task {
                let startTime = max(0, marker.timestamp - defaultCueTime)
                await musicService.seek(to: startTime)
                try? await musicService.play()
            }
        } else {
            // No previous marker found - error haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }

    private func navigateToNextMarker() {
        if let marker = findNextMarker() {
            Task {
                let startTime = max(0, marker.timestamp - defaultCueTime)
                await musicService.seek(to: startTime)
                try? await musicService.play()
            }
        } else {
            // No next marker found - error haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatCueTime(_ seconds: Double) -> String {
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
        // Keep reference to song before deleting the marker
        let song = marker.song

        modelContext.delete(marker)

        // If the song has no more markers, delete it
        if let song = song,
           (song.markers?.isEmpty ?? true) || song.sortedMarkers.isEmpty {
            modelContext.delete(song)
        }

        try? modelContext.save()
    }

    private func migrateLegacySongs() {
        // Find all songs that have markers but no lastMarkedAt timestamp
        let legacySongs = markedSongs.filter { song in
            guard let markers = song.markers, !markers.isEmpty else {
                return false
            }
            return song.lastMarkedAt == nil
        }

        // Update lastMarkedAt for legacy songs
        guard !legacySongs.isEmpty else { return }

        let now = Date()
        for song in legacySongs {
            song.lastMarkedAt = now
        }

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

// MARK: - Preview Helpers

@MainActor
private func createPreviewContainer() -> ModelContainer {
    let schema = Schema([MarkedSong.self, SongMarker.self])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

    do {
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let context = container.mainContext

        // Create a mock marked song
        let markedSong = MarkedSong(
            appleMusicID: "preview-song-id",
            title: "Bohemian Rhapsody",
            artist: "Queen",
            albumTitle: "A Night at the Opera",
            duration: 354.0 // 5:54
        )
        context.insert(markedSong)

        // Create some dummy markers
        let marker1 = SongMarker(
            timestamp: 45.0,
            emoji: "🎸",
            name: "Guitar Solo",
            cueTime: 5.0
        )
        marker1.song = markedSong
        context.insert(marker1)

        let marker2 = SongMarker(
            timestamp: 120.0,
            emoji: "🎤",
            name: "Opera Section",
            cueTime: 10.0
        )
        marker2.song = markedSong
        context.insert(marker2)

        let marker3 = SongMarker(
            timestamp: 210.0,
            emoji: "🔥",
            name: "Hard Rock",
            cueTime: 5.0
        )
        marker3.song = markedSong
        context.insert(marker3)

        let marker4 = SongMarker(
            timestamp: 280.0,
            emoji: "🎹",
            name: "Ballad Ending",
            cueTime: 15.0
        )
        marker4.song = markedSong
        context.insert(marker4)

        try context.save()
        return container
    } catch {
        fatalError("Failed to create preview container: \(error)")
    }
}

struct NowPlayingViewPreview: View {
    let container: ModelContainer
    @State private var currentTime: TimeInterval = 75.0
    @State private var duration: TimeInterval = 354.0
    @State private var isPlaying: Bool = true
    @State private var backgroundColor1: Color = .purple.opacity(0.3)
    @State private var backgroundColor2: Color = .blue.opacity(0.3)
    @AppStorage("defaultCueTime") private var defaultCueTime: Double = 5.0

    @Query private var markedSongs: [MarkedSong]

    private let cueTimeOptions: [Double] = [0, 5, 10, 15, 30, 45, 60, 90, 120]

    var markedSong: MarkedSong? {
        markedSongs.first
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    LinearGradient(
                        colors: [backgroundColor1, backgroundColor2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 0) {
                        let bottomSafeArea = max(geometry.safeAreaInsets.bottom, 20)
                        let availableHeight = geometry.size.height - bottomSafeArea
                        let availableWidth = geometry.size.width

                        let maxArtworkFromWidth = availableWidth - 32
                        let maxArtworkFromHeight = availableHeight * 0.45
                        let artworkSize = min(maxArtworkFromWidth, maxArtworkFromHeight)

                        let timelineHeight: CGFloat = 80
                        let timeFontSize: CGFloat = 40

                        let horizontalPadding: CGFloat = 48
                        let spacing: CGFloat = 20
                        let totalSpacing = spacing * 4
                        let availableForButtons = availableWidth - horizontalPadding - totalSpacing
                        let markerButtonUnit = availableForButtons / (2 * 0.45 + 2 * 0.67 + 1.0)
                        let controlButtonSize: CGFloat = min(48, markerButtonUnit * 0.67)
                        let playButtonSize: CGFloat = min(60, markerButtonUnit * 1.0)

                        VStack(spacing: 0) {
                            // Album artwork (black square)
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black)
                                .frame(width: artworkSize, height: artworkSize)
                                .shadow(radius: 10)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)

                            // Song info
                            VStack(spacing: 2) {
                                Text("Bohemian Rhapsody")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                Text("Queen")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)

                            // Marker timeline
                            if let markedSong {
                                MarkerTimelineView(
                                    currentTime: currentTime,
                                    duration: duration,
                                    markers: markedSong.sortedMarkers,
                                    musicService: MusicKitService.shared,
                                    onMarkerTap: { _ in },
                                    onMarkerEdit: { _ in },
                                    onMarkerDelete: { _ in }
                                )
                                .frame(height: timelineHeight)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 8)
                            }

                            // Time labels
                            HStack(alignment: .lastTextBaseline, spacing: 6) {
                                Text(formatTime(currentTime))
                                    .font(.system(size: timeFontSize, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)

                                Text("/")
                                    .font(.system(size: timeFontSize * 0.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))

                                Text(formatTime(duration))
                                    .font(.system(size: timeFontSize * 0.5, weight: .medium, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)

                            // Playback controls
                            HStack(spacing: 20) {
                                Button { } label: {
                                    Image(systemName: "chevron.backward.2")
                                        .font(.system(size: controlButtonSize * 0.45))
                                        .foregroundStyle(.white.opacity(0.8))
                                }

                                Spacer()

                                Button { } label: {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: controlButtonSize * 0.67))
                                        .foregroundStyle(.white)
                                }

                                Spacer()

                                Button { isPlaying.toggle() } label: {
                                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: playButtonSize))
                                        .foregroundStyle(.white)
                                }

                                Spacer()

                                Button { } label: {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: controlButtonSize * 0.67))
                                        .foregroundStyle(.white)
                                }

                                Spacer()

                                Button { } label: {
                                    Image(systemName: "chevron.forward.2")
                                        .font(.system(size: controlButtonSize * 0.45))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)

                            // Markers strip
                            if let markedSong {
                                HorizontalMarkerStrip(
                                    markers: markedSong.sortedMarkers,
                                    onTap: { _ in },
                                    onAddMarker: { },
                                    onMarkerEdit: { _ in },
                                    onMarkerDelete: { _ in }
                                )
                                .padding(.bottom, 12)
                                .frame(maxWidth: availableWidth)
                            }

                            // Cue time selector
                            VStack(spacing: 6) {
                                Text("Cue Time")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(cueTimeOptions, id: \.self) { cueTime in
                                            Button {
                                                defaultCueTime = cueTime
                                            } label: {
                                                Text(formatCueTime(cueTime))
                                                    .font(.subheadline)
                                                    .fontWeight(defaultCueTime == cueTime ? .bold : .medium)
                                                    .foregroundStyle(defaultCueTime == cueTime ? .black : .white)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 8)
                                                    .background(defaultCueTime == cueTime ? .white : .white.opacity(0.2))
                                                    .cornerRadius(16)
                                                    .scaleEffect(defaultCueTime == cueTime ? 1.05 : 1.0)
                                                    .shadow(color: defaultCueTime == cueTime ? .white.opacity(0.3) : .clear, radius: 8)
                                            }
                                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: defaultCueTime)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                                .frame(maxWidth: availableWidth)
                            }
                            .padding(.bottom, 8)
                        }
                        .frame(maxWidth: availableWidth, alignment: .center)
                        .padding(.bottom, bottomSafeArea + 8)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button { } label: {
                            Label("Recently Marked", systemImage: "clock.arrow.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatCueTime(_ seconds: Double) -> String {
        if seconds == 0 {
            return "0s"
        } else if seconds < 60 {
            return "\(Int(seconds))s"
        } else {
            let minutes = Int(seconds / 60)
            return "\(minutes)m"
        }
    }
}

#Preview("With Markers") {
    let container = createPreviewContainer()
    return NowPlayingViewPreview(container: container)
        .modelContainer(container)
}

#Preview("iPhone SE") {
    let container = createPreviewContainer()
    return NowPlayingViewPreview(container: container)
        .modelContainer(container)
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("iPhone 15 Pro Max") {
    let container = createPreviewContainer()
    return NowPlayingViewPreview(container: container)
        .modelContainer(container)
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
}

#Preview("Landscape") {
    let container = createPreviewContainer()
    return NowPlayingViewPreview(container: container)
        .modelContainer(container)
        .previewInterfaceOrientation(.landscapeRight)
}
