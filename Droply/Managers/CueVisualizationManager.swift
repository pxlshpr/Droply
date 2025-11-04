//
//  CueVisualizationManager.swift
//  Droply
//
//  Created by Claude Code on 10/30/25.
//

import SwiftUI
import Combine

enum CueVisualizationMode: String, CaseIterable, Identifiable {
    case button = "Button"
    case marker = "Marker"
    case fullscreen = "Fullscreen"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .button: return "rectangle.fill"
        case .marker: return "location.fill"
        case .fullscreen: return "arrow.up.left.and.arrow.down.right"
        }
    }

    var description: String {
        switch self {
        case .button: return "Fill the cue time button at the bottom"
        case .marker: return "Fill the marker button on timeline"
        case .fullscreen: return "Full-screen immersive visualization"
        }
    }
}

@MainActor
class CueVisualizationManager: ObservableObject {
    static let shared = CueVisualizationManager()

    @Published var currentCue: CueState?
    @Published var cueProgress: Double = 0 // 0.0 to 1.0
    @Published var showFullscreenVisualization = false

    private var musicService: MusicKitService?
    private var cancellables = Set<AnyCancellable>()
    private var lastTriggeredMarker: SongMarker?

    struct CueState {
        let marker: SongMarker
        let startTime: TimeInterval
        let endTime: TimeInterval
        let duration: TimeInterval
        let loopEnabled: Bool
        let loopDuration: TimeInterval

        func progress(at currentTime: TimeInterval) -> Double {
            guard duration > 0 else { return 0 }
            let elapsed = currentTime - startTime
            return min(max(elapsed / duration, 0), 1)
        }

        var loopEndTime: TimeInterval {
            endTime + loopDuration
        }

        var isActive: Bool {
            true
        }
    }

    private init() {}

    func setup(musicService: MusicKitService) {
        self.musicService = musicService

        // Start observing playback time changes with @Observable
        Task { @MainActor in
            observePlaybackTime()
        }
    }

    @MainActor
    private func observePlaybackTime() {
        guard let musicService = musicService else { return }

        _ = withObservationTracking {
            // Access the property to register observation
            _ = musicService.playbackTime
        } onChange: {
            Task { @MainActor [weak self] in
                self?.updateCueState()
                // Recursively continue observing
                self?.observePlaybackTime()
            }
        }
    }

    func startCue(for marker: SongMarker, defaultCueTime: Double, currentTime: TimeInterval, loopEnabled: Bool = false, loopDuration: TimeInterval = 0) {
        let startTime = max(0, marker.timestamp - defaultCueTime)
        let endTime = marker.timestamp
        let duration = defaultCueTime

        currentCue = CueState(
            marker: marker,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            loopEnabled: loopEnabled,
            loopDuration: loopDuration
        )
        lastTriggeredMarker = nil

        updateCueState()
    }

    func clearCue() {
        currentCue = nil
        cueProgress = 0
        lastTriggeredMarker = nil
    }

    private func updateCueState() {
        guard let cue = currentCue,
              let currentTime = musicService?.playbackTime else {
            if currentCue != nil {
                clearCue()
            }
            return
        }

        // Check if we've passed the marker
        if currentTime >= cue.endTime {
            // Trigger haptic if we haven't already
            if lastTriggeredMarker?.id != cue.marker.id {
                triggerMarkerHaptic()
                lastTriggeredMarker = cue.marker
            }

            // If loop mode is enabled, check if we should loop back
            if cue.loopEnabled {
                // Check if we've reached the loop end time
                if currentTime >= cue.loopEndTime {
                    // Loop back to the start time
                    Task {
                        await musicService?.seek(to: cue.startTime)
                    }
                    return
                }
                // Still in the loop duration, continue playing
                return
            }

            // Clear the cue after passing the marker (non-loop mode)
            clearCue()
            return
        }

        // Check if we're before the cue
        if currentTime < cue.startTime {
            clearCue()
            return
        }

        // Update progress
        cueProgress = cue.progress(at: currentTime)
    }

    private func triggerMarkerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
    }
}
