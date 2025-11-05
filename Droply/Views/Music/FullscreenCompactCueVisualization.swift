//
//  FullscreenCompactCueVisualization.swift
//  Droply
//
//  Created by Claude Code on 11/5/25.
//

import SwiftUI

struct FullscreenCompactCueVisualization: View {
    let marker: SongMarker
    let progress: Double // 0.0 to 1.0
    let remainingTime: TimeInterval
    var meshColors: [Color]? // Optional mesh gradient colors from artwork

    @State private var pulseScale: CGFloat = 1.0
    @State private var outerRingRotation: Double = 0
    @State private var particlePhase: Double = 0

    private var intensityLevel: Double {
        // Intensity increases as we approach the marker
        progress
    }

    var body: some View {
        ZStack {
            // Dynamic gradient background
            if #available(iOS 18.0, *), let meshColors = meshColors {
                // Use animated mesh gradient for background
                AnimatedMeshGradient(
                    colors: meshColors.map { $0.opacity(0.3) },
                    progress: progress * 0.5, // Subtle animation
                    isAnimated: true
                )
                .ignoresSafeArea()
                .overlay {
                    // Add a dark overlay to ensure text readability
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                }
            } else {
                // Fallback radial gradient
                RadialGradient(
                    colors: [
                        backgroundColorForProgress.opacity(0.4),
                        backgroundColorForProgress.opacity(0.1),
                        .black
                    ],
                    center: .center,
                    startRadius: 100,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }

            // Animated particle field
            Canvas { context, size in
                let centerX = size.width / 2
                let centerY = size.height / 2
                let particleCount = Int(30 * intensityLevel) + 10

                for i in 0..<particleCount {
                    let angle = (Double(i) / Double(particleCount)) * 2 * .pi + particlePhase
                    let radius = 150 + (progress * 200) + sin(particlePhase * 2 + Double(i)) * 30
                    let x = centerX + cos(angle) * radius
                    let y = centerY + sin(angle) * radius
                    let size = 3 + intensityLevel * 5
                    let opacity = 0.3 + intensityLevel * 0.5

                    context.opacity = opacity
                    context.fill(
                        Circle().path(in: CGRect(x: x - size/2, y: y - size/2, width: size, height: size)),
                        with: .color(.white)
                    )
                }
            }

            // Subtle central visualization that won't obstruct UI
            VStack {
                Spacer()

                // Central circular progress with pulsating effect
                ZStack {
                    // Outer rotating ring with mesh gradient colors
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: meshColors ?? [
                                    .pink,
                                    .purple,
                                    .blue,
                                    .cyan,
                                    .pink
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .animation(.linear, value: progress)
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(outerRingRotation))
                        .shadow(color: (meshColors?.first ?? .purple).opacity(0.8), radius: 20)

                    // Middle pulsating ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 170, height: 170)
                        .scaleEffect(pulseScale)
                        .opacity(0.5)

                    // Inner circle with marker emoji
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .white.opacity(0.15),
                                        .white.opacity(0.03)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 150, height: 150)
                            .scaleEffect(1 + intensityLevel * 0.08)

                        // Marker emoji
                        Text(marker.emoji)
                            .font(.system(size: 60))
                            .scaleEffect(pulseScale)
                    }
                }
                .scaleEffect(1 + intensityLevel * 0.1)
                .opacity(0.6) // Make it more subtle so UI elements remain prominent

                Spacer()
            }
        }
        .allowsHitTesting(false) // Important: allow touches to pass through to UI elements below
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Pulsating scale animation
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.0 + intensityLevel * 0.15
        }

        // Outer ring rotation
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            outerRingRotation = 360
        }

        // Particle phase animation
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            particlePhase = 2 * .pi
        }
    }

    private var backgroundColorForProgress: Color {
        if progress < 0.33 {
            return .blue
        } else if progress < 0.66 {
            return .purple
        } else {
            return .pink
        }
    }
}

#Preview("Start") {
    FullscreenCompactCueVisualization(
        marker: SongMarker(timestamp: 45, emoji: "🔥", name: "Drop"),
        progress: 0.1,
        remainingTime: 4.5
    )
}

#Preview("Mid Progress") {
    FullscreenCompactCueVisualization(
        marker: SongMarker(timestamp: 90, emoji: "🎸", name: "Guitar Solo"),
        progress: 0.5,
        remainingTime: 2.5
    )
}

#Preview("Near End") {
    FullscreenCompactCueVisualization(
        marker: SongMarker(timestamp: 150, emoji: "💪", name: "Final Push"),
        progress: 0.9,
        remainingTime: 0.5
    )
}
