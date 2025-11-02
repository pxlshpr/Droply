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
    @StateObject private var cueManager = CueVisualizationManager.shared
    @State private var markedSong: MarkedSong?
    @State private var showingAddMarker = false
    @State private var showingEditMarker = false
    @State private var showingRecentlyMarked = false
    @State private var showingSettings = false
    @State private var showingCueTimeSelector = false
    @State private var settingsDetent: PresentationDetent = .medium
    @State private var markerToEdit: SongMarker?
    @State private var selectedMarker: SongMarker?
    @AppStorage("defaultCueTime") private var defaultCueTime: Double = 5.0
    @AppStorage("loopModeEnabled") private var loopModeEnabled: Bool = false
    @AppStorage("loopDuration") private var loopDuration: Double = 10.0
    @Namespace private var recentlyMarkedNamespace
    @AppStorage("cueVisualizationMode") private var visualizationMode: String = CueVisualizationMode.button.rawValue

    // Preview state
    @State private var previewCurrentTime: TimeInterval = 75.0
    @State private var previewIsPlaying: Bool = true

    @Query private var markedSongs: [MarkedSong]

    private let cueTimeOptions: [Double] = [0, 5, 10, 15, 30, 45, 60, 90, 120]

    private var currentVisualizationMode: CueVisualizationMode {
        CueVisualizationMode(rawValue: visualizationMode) ?? .button
    }

    // Detect if running in simulator or preview
    private var isPreview: Bool {
        #if targetEnvironment(simulator)
        return musicService.currentSong == nil && !markedSongs.isEmpty
        #else
        return false
        #endif
    }

    // Preview dummy data
    private var previewSongTitle: String { "Bohemian Rhapsody" }
    private var previewArtist: String { "Queen" }
    private var previewDuration: TimeInterval { 354.0 }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Dynamic background gradient from artwork colors
                    LinearGradient(
                        colors: isPreview ? [Color(white: 0.1), Color(white: 0.15)] : [musicService.backgroundColor1, musicService.backgroundColor2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.8), value: musicService.backgroundColor1)
                    .animation(.easeInOut(duration: 0.8), value: musicService.backgroundColor2)

                VStack(spacing: 0) {
                if musicService.isCheckingPlayback && !isPreview {
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
                } else if let song = musicService.currentSong ?? musicService.pendingSong, !isPreview {
                    // Calculate available space accounting for safe areas
                    let bottomSafeArea = max(geometry.safeAreaInsets.bottom, 20) // Minimum 20pt padding
                    let availableHeight = geometry.size.height - bottomSafeArea
                    let availableWidth = geometry.size.width

                    // Calculate sizes - maximize artwork while fitting width
                    let maxArtworkFromWidth = availableWidth - 32 // Account for horizontal padding
                    let maxArtworkFromHeight = availableHeight * 0.45 // Use 45% of height
                    let artworkSize = min(maxArtworkFromWidth, maxArtworkFromHeight)

                    let timelineHeight: CGFloat = 40
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

                                    // Start cue visualization
                                    cueManager.startCue(
                                        for: marker,
                                        defaultCueTime: defaultCueTime,
                                        currentTime: startTime,
                                        loopEnabled: loopModeEnabled,
                                        loopDuration: loopDuration
                                    )

                                    // Show fullscreen if that mode is selected
                                    if currentVisualizationMode == .fullscreen {
                                        cueManager.showFullscreenVisualization = true
                                    }
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
                            // Current time - tap to add marker
                            Button {
                                showingAddMarker = true
                            } label: {
                                Text(formatTime(musicService.playbackTime))
                                    .font(.system(size: timeFontSize, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .glassEffect(.regular.tint(musicService.backgroundColor1).interactive())
                            }

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
                        HStack(spacing: 0) {
                            // Previous marker button
                            Button {
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                                navigateToPreviousMarker()
                            } label: {
                                Image(systemName: "chevron.backward.2")
                                    .font(.system(size: controlButtonSize * 0.45))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .frame(width: controlButtonSize)

                            Spacer()

                            // Previous track button
                            Button {
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                                Task {
                                    try? await musicService.skipToPreviousItem()
                                }
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: controlButtonSize * 0.67))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .frame(width: controlButtonSize)

                            Spacer()

                            // Play/Pause button
                            Button {
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                                Task {
                                    try? await musicService.togglePlayPause()
                                }
                            } label: {
                                Image(systemName: musicService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: playButtonSize))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .frame(width: playButtonSize)

                            Spacer()

                            // Next track button
                            Button {
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                                Task {
                                    try? await musicService.skipToNextItem()
                                }
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: controlButtonSize * 0.67))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .frame(width: controlButtonSize)

                            Spacer()

                            // Next marker button
                            Button {
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                                navigateToNextMarker()
                            } label: {
                                Image(systemName: "chevron.forward.2")
                                    .font(.system(size: controlButtonSize * 0.45))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .frame(width: controlButtonSize)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                        Spacer()

                        // Markers strip
                        if currentVisualizationMode == .marker {
                            HorizontalMarkerStripWithAutoScroll(
                                markers: markedSong?.sortedMarkers ?? [],
                                activeMarker: cueManager.currentCue?.marker,
                                progress: cueManager.cueProgress,
                                onTap: { marker in
                                    Task {
                                        let startTime = max(0, marker.timestamp - defaultCueTime)
                                        await musicService.seek(to: startTime)
                                        try? await musicService.play()

                                        // Start cue visualization
                                        cueManager.startCue(
                                            for: marker,
                                            defaultCueTime: defaultCueTime,
                                            currentTime: startTime,
                                            loopEnabled: loopModeEnabled,
                                            loopDuration: loopDuration
                                        )
                                    }
                                },
                                onMarkerEdit: { marker in
                                    markerToEdit = marker
                                    showingEditMarker = true
                                },
                                onMarkerDelete: { marker in
                                    deleteMarker(marker)
                                },
                                meshColors: musicService.meshColors
                            )
                            .frame(maxWidth: availableWidth)
                        } else {
                            HorizontalMarkerStrip(
                                markers: markedSong?.sortedMarkers ?? [],
                                onTap: { marker in
                                    Task {
                                        let startTime = max(0, marker.timestamp - defaultCueTime)
                                        await musicService.seek(to: startTime)
                                        try? await musicService.play()

                                        // Start cue visualization
                                        cueManager.startCue(
                                            for: marker,
                                            defaultCueTime: defaultCueTime,
                                            currentTime: startTime,
                                            loopEnabled: loopModeEnabled,
                                            loopDuration: loopDuration
                                        )

                                        // Show fullscreen if that mode is selected
                                        if currentVisualizationMode == .fullscreen {
                                            cueManager.showFullscreenVisualization = true
                                        }
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
                            .frame(maxWidth: availableWidth)
                        }

                        // Cue Button Visualization (when in button mode)
                        if currentVisualizationMode == .button {
                            CueButtonVisualization(
                                progress: cueManager.cueProgress,
                                cueTime: defaultCueTime,
                                isActive: cueManager.currentCue != nil,
                                onTap: {
                                    showingCueTimeSelector = true
                                },
                                meshColors: musicService.meshColors,
                                loopEnabled: loopModeEnabled,
                                loopDuration: loopDuration
                            )
                            .padding(.horizontal, 17)
                            .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: availableWidth, alignment: .center)
                    .padding(.bottom, bottomSafeArea + 8)
                } else if isPreview {
                    // Preview mode with dummy data
                    let bottomSafeArea = max(geometry.safeAreaInsets.bottom, 20)
                    let availableHeight = geometry.size.height - bottomSafeArea
                    let availableWidth = geometry.size.width

                    let maxArtworkFromWidth = availableWidth - 32
                    let maxArtworkFromHeight = availableHeight * 0.45
                    let artworkSize = min(maxArtworkFromWidth, maxArtworkFromHeight)

                    let timelineHeight: CGFloat = 40
                    let timeFontSize: CGFloat = 40

                    let horizontalPadding: CGFloat = 48
                    let spacing: CGFloat = 20
                    let totalSpacing = spacing * 4
                    let availableForButtons = availableWidth - horizontalPadding - totalSpacing
                    let markerButtonUnit = availableForButtons / (2 * 0.45 + 2 * 0.67 + 1.0)

                    let controlButtonSize: CGFloat = min(48, markerButtonUnit * 0.67)
                    let playButtonSize: CGFloat = min(60, markerButtonUnit * 1.0)

                    VStack(spacing: 0) {
                        // Album artwork (black square for preview)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                            .frame(width: artworkSize, height: artworkSize)
                            .shadow(radius: 10)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)

                        // Song info
                        VStack(spacing: 2) {
                            Text(previewSongTitle)
                                .font(.title3)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(previewArtist)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)

                        // Marker timeline
                        if let previewMarkedSong = markedSongs.first {
                            MarkerTimelineView(
                                currentTime: previewCurrentTime,
                                duration: previewDuration,
                                markers: previewMarkedSong.sortedMarkers,
                                musicService: musicService,
                                onMarkerTap: { _ in },
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
                        }

                        // Time labels
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Button {
                                showingAddMarker = true
                            } label: {
                                Text(formatTime(previewCurrentTime))
                                    .font(.system(size: timeFontSize, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .glassEffect(.regular.tint(musicService.backgroundColor1).interactive())
                            }

                            Text("/")
                                .font(.system(size: timeFontSize * 0.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))

                            Text(formatTime(previewDuration))
                                .font(.system(size: timeFontSize * 0.5, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                        // Playback controls
                        HStack(spacing: 0) {
                            Button { } label: {
                                Image(systemName: "chevron.backward.2")
                                    .font(.system(size: controlButtonSize * 0.45))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .frame(width: controlButtonSize)

                            Spacer()

                            Button { } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: controlButtonSize * 0.67))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .frame(width: controlButtonSize)

                            Spacer()

                            Button { previewIsPlaying.toggle() } label: {
                                Image(systemName: previewIsPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: playButtonSize))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .frame(width: playButtonSize)

                            Spacer()

                            Button { } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: controlButtonSize * 0.67))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .frame(width: controlButtonSize)

                            Spacer()

                            Button { } label: {
                                Image(systemName: "chevron.forward.2")
                                    .font(.system(size: controlButtonSize * 0.45))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .frame(width: controlButtonSize)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                        Spacer()

                        // Markers strip
                        if let previewMarkedSong = markedSongs.first {
                            if currentVisualizationMode == .marker {
                                HorizontalMarkerStripWithAutoScroll(
                                    markers: previewMarkedSong.sortedMarkers,
                                    activeMarker: nil,
                                    progress: 0,
                                    onTap: { _ in },
                                    onMarkerEdit: { marker in
                                        markerToEdit = marker
                                        showingEditMarker = true
                                    },
                                    onMarkerDelete: { marker in
                                        deleteMarker(marker)
                                    }
                                )
                                .frame(maxWidth: availableWidth)
                            } else {
                                HorizontalMarkerStrip(
                                    markers: previewMarkedSong.sortedMarkers,
                                    onTap: { _ in },
                                    onMarkerEdit: { marker in
                                        markerToEdit = marker
                                        showingEditMarker = true
                                    },
                                    onMarkerDelete: { marker in
                                        deleteMarker(marker)
                                    }
                                )
                                .frame(maxWidth: availableWidth)
                            }
                        }

                        // Cue Button Visualization (when in button mode)
                        if currentVisualizationMode == .button {
                            CueButtonVisualization(
                                progress: cueManager.cueProgress,
                                cueTime: defaultCueTime,
                                isActive: cueManager.currentCue != nil,
                                onTap: {
                                    showingCueTimeSelector = true
                                },
                                meshColors: musicService.meshColors,
                                loopEnabled: loopModeEnabled,
                                loopDuration: loopDuration
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
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
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingRecentlyMarked = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
                .matchedTransitionSource(id: "recentlyMarked", in: recentlyMarkedNamespace)

//                ToolbarItem(placement: .bottomBar) {
//                    Button {
//                        showingCueTimeSelector = true
//                    } label: {
//                        HStack(spacing: 4) {
//                            Image(systemName: "timer")
//                            Text(formatCueTime(defaultCueTime))
//                                .font(.subheadline)
//                                .fontWeight(.medium)
//                        }
//                    }
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .opacity(currentVisualizationMode == .button ? 0 : 1)
//                }
            }
            .toolbarBackground(.visible, for: .bottomBar)
            .sheet(isPresented: $showingAddMarker, onDismiss: {
                // Refresh markedSong after adding a marker
                updateMarkedSong(for: musicService.currentSong)
            }) {
                if let song = musicService.currentSong {
                    AddMarkerView(
                        currentTime: musicService.playbackTime,
                        markedSong: getOrCreateMarkedSong(from: song)
                    )
                }
            }
            .sheet(isPresented: $showingEditMarker, onDismiss: {
                // Refresh markedSong after editing a marker
                updateMarkedSong(for: musicService.currentSong)
            }) {
                if let marker = markerToEdit {
                    EditMarkerView(marker: marker)
                }
            }
            .sheet(isPresented: $showingRecentlyMarked) {
                RecentlyMarkedView(namespace: recentlyMarkedNamespace)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .presentationBackground(.ultraThinMaterial)
                    .navigationTransition(.zoom(sourceID: "recentlyMarked", in: recentlyMarkedNamespace))
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .presentationDetents([.medium, .large], selection: $settingsDetent)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showingCueTimeSelector) {
                NavigationStack {
                    Form {
                        Section {
                            cueTimeSelector
                        } header: {
                            Text("Buffer Time")
                        } footer: {
                            Text("Start playing this many seconds before the marker")
                        }

                        Section {
                            Toggle(isOn: $loopModeEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Loop Mode")
                                    Text("Repeat the section after playing")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .onChange(of: loopModeEnabled) { _, _ in
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                            }

                            if loopModeEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Loop Duration")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    loopDurationSelector
                                }
                            }
                        } footer: {
                            if loopModeEnabled {
                                Text("Play for this duration after the marker, then loop back to start")
                            }
                        }
                    }
                    .navigationTitle("Drop-in Settings")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.height(loopModeEnabled ? 420 : 320)])
                .presentationBackground(.ultraThinMaterial)
                .animation(.spring(response: 0.3), value: loopModeEnabled)
            }
            .onChange(of: musicService.currentSong) { _, newSong in
                updateMarkedSong(for: newSong)
            }
            .onAppear {
                migrateLegacySongs()
                updateMarkedSong(for: musicService.currentSong)
                cueManager.setup(musicService: musicService)
            }
            .fullScreenCover(isPresented: $cueManager.showFullscreenVisualization) {
                if let cue = cueManager.currentCue {
                    FullscreenCueVisualization(
                        marker: cue.marker,
                        progress: cueManager.cueProgress,
                        remainingTime: cue.endTime - musicService.playbackTime,
                        onDismiss: {
                            cueManager.showFullscreenVisualization = false
                        },
                        meshColors: musicService.meshColors
                    )
                }
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
        Picker("Buffer Time", selection: $defaultCueTime) {
            ForEach(cueTimeOptions, id: \.self) { cueTime in
                Text(formatCueTime(cueTime)).tag(cueTime)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: defaultCueTime) { _, _ in
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }

    private var loopDurationSelector: some View {
        Picker("Loop Duration", selection: $loopDuration) {
            ForEach(cueTimeOptions.filter { $0 > 0 }, id: \.self) { duration in
                Text(formatCueTime(duration)).tag(duration)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: loopDuration) { _, _ in
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }

    // MARK: - Helper Methods

    private func findPreviousMarker() -> SongMarker? {
        guard let markers = markedSong?.sortedMarkers else { return nil }
        let currentTime = musicService.playbackTime

        // Find the last marker whose cue start time is before the current time
        return markers.last { ($0.timestamp - defaultCueTime) < currentTime }
    }

    private func findNextMarker() -> SongMarker? {
        guard let markers = markedSong?.sortedMarkers else { return nil }
        let currentTime = musicService.playbackTime

        // Find the first marker whose cue start time is after the current time
        return markers.first { ($0.timestamp - defaultCueTime) > currentTime }
    }

    private func navigateToPreviousMarker() {
        if let marker = findPreviousMarker() {
            Task {
                let startTime = max(0, marker.timestamp - defaultCueTime)
                await musicService.seek(to: startTime)
                try? await musicService.play()
            }
        } else {
            // No previous marker found in current song - try to skip to previous song
            Task {
                do {
                    // Pause first to prevent any playback before we're ready
                    try? await musicService.pause()

                    // Try to skip to the previous song in the queue
                    try await musicService.skipToPreviousItem()

                    // Wait for the song to change and playback to initialize
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                    // Check if the new song has markers
                    if let currentSong = musicService.currentSong,
                       let newMarkedSong = markedSongs.first(where: { $0.appleMusicID == currentSong.id.rawValue }),
                       let lastMarker = newMarkedSong.sortedMarkers.last {
                        // Navigate to the last marker of the new song
                        let startTime = max(0, lastMarker.timestamp - defaultCueTime)
                        await musicService.seek(to: startTime)
                        try? await musicService.play()
                    } else {
                        // If no markers, play from the beginning
                        try? await musicService.play()
                    }
                } catch {
                    // If skipping fails (no previous song), trigger error haptic
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
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

        // Check if this is the last marker BEFORE deletion
        let markerCount = song?.markers?.count ?? 0
        let isLastMarker = markerCount <= 1

        modelContext.delete(marker)

        // If this was the last marker, delete the entire song
        if let song = song, isLastMarker {
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

#Preview("Now Playing") {
    let container = createPreviewContainer()
    return NowPlayingView()
        .modelContainer(container)
}
