//
//  HapticManager.swift
//  Droply
//
//  Created by Ahmed Khalaf on 11/02/25.
//

import CoreHaptics
import UIKit

class HapticManager {
    static let shared = HapticManager()

    private var engine: CHHapticEngine?

    private init() {
        prepareHaptics()
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return
        }

        do {
            engine = try CHHapticEngine()
            try engine?.start()

            // Handle engine stopping
            engine?.stoppedHandler = { reason in
                print("Haptic engine stopped: \(reason)")
            }

            // Handle engine reset
            engine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                do {
                    try self?.engine?.start()
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }

    /// Plays a delightful "musical ping" haptic pattern
    /// Creates a bouncy, musical feel like plucking a string
    func playMusicalPing() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            // Fallback to basic haptic on unsupported devices
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            return
        }

        do {
            // First tap - sharp and strong (like striking a note)
            let strongTap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0
            )

            // Echo tap - softer and rounder (like the note resonating)
            let echoTap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0.05 // 50ms after the first tap
            )

            let pattern = try CHHapticPattern(events: [strongTap, echoTap], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play haptic pattern: \(error)")
            // Fallback to basic haptic
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
}
