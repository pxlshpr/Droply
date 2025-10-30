//
//  FullscreenCueVisualization.swift
//  Droply
//
//  Created by Claude Code on 10/30/25.
//

import SwiftUI

struct FullscreenCueVisualization: View {
    let marker: SongMarker
    let progress: Double // 0.0 to 1.0
    let remainingTime: TimeInterval
    let onDismiss: () -> Void

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

            // Main visualization
            VStack(spacing: 0) {
                Spacer()

                // Central circular progress with pulsating effect
                ZStack {
                    // Outer rotating ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    .pink,
                                    .purple,
                                    .blue,
                                    .cyan,
                                    .pink
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 280, height: 280)
                        .rotationEffect(.degrees(outerRingRotation))
                        .shadow(color: .purple.opacity(0.8), radius: 20)

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
                        .frame(width: 240, height: 240)
                        .scaleEffect(pulseScale)
                        .opacity(0.6)

                    // Inner circle with marker emoji
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .white.opacity(0.2),
                                        .white.opacity(0.05)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                            .scaleEffect(1 + intensityLevel * 0.1)

                        // Marker emoji
                        Text(marker.emoji)
                            .font(.system(size: 80))
                            .scaleEffect(pulseScale)
                    }

                    // Progress percentage
                    VStack(spacing: 4) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .offset(y: 130)
                    }
                }
                .scaleEffect(1 + intensityLevel * 0.15)

                Spacer().frame(height: 60)

                // Countdown timer
                VStack(spacing: 8) {
                    Text("Drop in")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .textCase(.uppercase)
                        .tracking(2)

                    Text(formatRemainingTime(remainingTime))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .shadow(color: backgroundColorForProgress.opacity(0.5), radius: 10)

                    if let name = marker.name, !name.isEmpty {
                        Text(name)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.top, 8)
                    }
                }

                Spacer()
            }

            // Close button
            VStack {
                HStack {
                    Spacer()

                    Button(action: onDismiss) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)

                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding()
                }

                Spacer()
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Pulsating scale animation
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.0 + intensityLevel * 0.2
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

    private func formatRemainingTime(_ time: TimeInterval) -> String {
        let seconds = Int(ceil(time))
        if seconds >= 60 {
            let minutes = seconds / 60
            let secs = seconds % 60
            return String(format: "%d:%02d", minutes, secs)
        } else {
            return "\(seconds)s"
        }
    }
}

#Preview("Start") {
    FullscreenCueVisualization(
        marker: SongMarker(timestamp: 45, emoji: "🔥", name: "Drop"),
        progress: 0.1,
        remainingTime: 4.5,
        onDismiss: {}
    )
}

#Preview("Mid Progress") {
    FullscreenCueVisualization(
        marker: SongMarker(timestamp: 90, emoji: "🎸", name: "Guitar Solo"),
        progress: 0.5,
        remainingTime: 2.5,
        onDismiss: {}
    )
}

#Preview("Near End") {
    FullscreenCueVisualization(
        marker: SongMarker(timestamp: 150, emoji: "💪", name: "Final Push"),
        progress: 0.9,
        remainingTime: 0.5,
        onDismiss: {}
    )
}
