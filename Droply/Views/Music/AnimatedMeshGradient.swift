//
//  AnimatedMeshGradient.swift
//  Droply
//
//  Created by Claude Code on 10/30/25.
//

import SwiftUI

/// An animated mesh gradient that uses colors extracted from artwork
/// Animates based on progress (0.0 to 1.0) for cue visualizations
@available(iOS 18.0, *)
struct AnimatedMeshGradient: View {
    let colors: [Color]
    let progress: Double // 0.0 to 1.0
    let isAnimated: Bool

    init(colors: [Color], progress: Double = 0, isAnimated: Bool = true) {
        // Ensure we have exactly 9 colors for 3x3 mesh
        if colors.count >= 9 {
            self.colors = Array(colors.prefix(9))
        } else {
            // Pad with repeated colors if needed
            var paddedColors = colors
            while paddedColors.count < 9 {
                paddedColors.append(colors[paddedColors.count % colors.count])
            }
            self.colors = paddedColors
        }
        self.progress = progress
        self.isAnimated = isAnimated
    }

    var body: some View {
        if isAnimated {
            TimelineView(.animation) { context in
                meshGradientView(time: context.date.timeIntervalSince1970)
            }
        } else {
            meshGradientView(time: 0)
        }
    }

    private func meshGradientView(time: TimeInterval) -> some View {
        // 3x3 mesh grid (9 points, 9 colors)
        // Layout:
        // [0,0] [0.5,0] [1,0]
        // [0,0.5] [0.5,0.5] [1,0.5]
        // [0,1] [0.5,1] [1,1]

        // Calculate animation offsets
        let progressFactor = Float(progress)
        let timeFactor = Float(time)

        // Animate interior points based on progress and time
        // Keep edges fixed, animate center and edge midpoints
        let centerOffset = sin(timeFactor * 2.0) * 0.15 * progressFactor
        let edgeOffset = sin(timeFactor * 1.5 + 1.0) * 0.08 * progressFactor

        // Points for 3x3 grid
        let points: [SIMD2<Float>] = [
            // Top row (keep corners fixed, animate middle)
            [0.0, 0.0],
            [0.5 + edgeOffset, 0.0],
            [1.0, 0.0],

            // Middle row (animate all)
            [0.0, 0.5 + edgeOffset * 0.7],
            [0.5 + centerOffset, 0.5 + sin(timeFactor * 2.0 + 0.5) * 0.12 * progressFactor],
            [1.0, 0.5 + edgeOffset * 0.7],

            // Bottom row (keep corners fixed, animate middle)
            [0.0, 1.0],
            [0.5 + edgeOffset * 0.5, 1.0],
            [1.0, 1.0]
        ]

        return MeshGradient(
            width: 3,
            height: 3,
            points: points,
            colors: colors
        )
    }
}

/// A static mesh gradient for backgrounds
@available(iOS 18.0, *)
struct StaticMeshGradient: View {
    let colors: [Color]

    init(colors: [Color]) {
        // Ensure we have exactly 9 colors for 3x3 mesh
        if colors.count >= 9 {
            self.colors = Array(colors.prefix(9))
        } else {
            // Pad with repeated colors if needed
            var paddedColors = colors
            while paddedColors.count < 9 {
                paddedColors.append(colors[paddedColors.count % colors.count])
            }
            self.colors = paddedColors
        }
    }

    var body: some View {
        // 3x3 mesh with fixed points
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: colors
        )
    }
}

// Preview with sample colors
@available(iOS 18.0, *)
#Preview("Animated - Low Progress") {
    AnimatedMeshGradient(
        colors: [
            .pink, .purple, .blue,
            .orange, .red, .cyan,
            .yellow, .mint, .indigo
        ],
        progress: 0.2,
        isAnimated: true
    )
    .frame(width: 300, height: 200)
}

@available(iOS 18.0, *)
#Preview("Animated - High Progress") {
    AnimatedMeshGradient(
        colors: [
            .pink, .purple, .blue,
            .orange, .red, .cyan,
            .yellow, .mint, .indigo
        ],
        progress: 0.9,
        isAnimated: true
    )
    .frame(width: 300, height: 200)
}

@available(iOS 18.0, *)
#Preview("Static Background") {
    StaticMeshGradient(
        colors: [
            .purple.opacity(0.3), .blue.opacity(0.3), .indigo.opacity(0.3),
            .purple.opacity(0.2), .blue.opacity(0.2), .indigo.opacity(0.2),
            .purple.opacity(0.1), .blue.opacity(0.1), .indigo.opacity(0.1)
        ]
    )
    .ignoresSafeArea()
}
