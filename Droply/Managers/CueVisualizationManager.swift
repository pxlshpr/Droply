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

        func progress(at currentTime: TimeInterval) -> Double {
            guard duration > 0 else { return 0 }
            let elapsed = currentTime - startTime
            return min(max(elapsed / duration, 0), 1)
        }

        var isActive: Bool {
            true
        }
    }

    private init() {}

    func setup(musicService: MusicKitService) {
        self.musicService = musicService

        // Observe playback time changes
        musicService.$playbackTime
            .sink { [weak self] _ in
                self?.updateCueState()
            }
            .store(in: &cancellables)
    }

    func startCue(for marker: SongMarker, defaultCueTime: Double, currentTime: TimeInterval) {
        let startTime = max(0, marker.timestamp - defaultCueTime)
        let endTime = marker.timestamp
        let duration = defaultCueTime

        currentCue = CueState(
            marker: marker,
            startTime: startTime,
            endTime: endTime,
            duration: duration
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

            // Clear the cue after passing the marker
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
