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
        // Use rigid haptic for now - more reliable and satisfying
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
    }
}
